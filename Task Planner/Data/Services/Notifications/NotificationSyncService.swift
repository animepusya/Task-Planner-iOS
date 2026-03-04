//
//  NotificationSyncService.swift
//  Task Planner
//
//  Created by Руслан Меланин on 03.03.2026.
//

import Foundation
import SwiftData

@MainActor
final class NotificationSyncService {

    private let notificationService: NotificationService
    private let preferencesRepository: PreferencesRepository

    private let rollingDays: Int = 30

    init(
        notificationService: NotificationService,
        preferencesRepository: PreferencesRepository
    ) {
        self.notificationService = notificationService
        self.preferencesRepository = preferencesRepository
    }

    // MARK: - App toggle

    func applyAppToggleIfNeeded(notificationsEnabled: Bool) async {
        guard notificationsEnabled == false else { return }
        await notificationService.cancelAll()
    }

    // MARK: - Reschedule entry points

    func rescheduleAll(tasks: [TaskEntity]) async {
        let prefs: AppPreferencesEntity
        do {
            prefs = try preferencesRepository.getOrCreate()
        } catch {
            return
        }

        let auth = await notificationService.getAuthorizationStatus()

        if prefs.notificationsEnabled == false {
            await notificationService.cancelAll()
            return
        }

        guard auth == .authorized else {
            return
        }

        await notificationService.cancelAll()

        let reminders = buildPendingRemindersForRollingWindow(tasks: tasks, prefs: prefs)
        await notificationService.scheduleReminders(reminders)
    }

    func cancelAllImmediately() async {
        await notificationService.cancelAll()
    }

    func cancelForTask(task: TaskEntity) async {
        let ids = buildAllPossibleIdsForTaskRollingWindow(task: task)
        await notificationService.cancel(ids: ids)
    }

    func cancelSingle(taskId: PersistentIdentifier, occurrenceKey: String) async {
        let taskKey = String(describing: taskId)
        let id = notificationId(taskKey: taskKey, occurrenceKey: occurrenceKey)
        await notificationService.cancel(ids: [id])
    }

    func scheduleSingleOccurrence(task: TaskEntity, occurrenceDay: Date) async {
        let prefs: AppPreferencesEntity
        do {
            prefs = try preferencesRepository.getOrCreate()
        } catch { return }

        guard prefs.notificationsEnabled else { return }
        let auth = await notificationService.getAuthorizationStatus()
        guard auth == .authorized else { return }
        guard task.reminderEnabled else { return }

        let cal = Calendar.current
        let start = cal.startOfDay(for: .now)
        let end = cal.date(byAdding: .day, value: rollingDays, to: start) ?? start.addingTimeInterval(Double(rollingDays) * 86400)

        let occ = cal.startOfDay(for: occurrenceDay)
        guard occ >= start && occ < end else { return }

        let occurrenceKey = TaskEntity.dayKey(for: occ, calendar: cal)
        guard task.isReminderSuppressed(for: occurrenceKey) == false else { return }

        guard let fireDate = computeFireDate(task: task, occurrenceDay: occ, prefs: prefs, calendar: cal) else { return }

        let taskKey = String(describing: task.persistentModelID)
        let id = notificationId(taskKey: taskKey, occurrenceKey: occurrenceKey)

        let reminder = PendingReminder(
            id: id,
            taskId: taskKey,
            occurrenceKey: occurrenceKey,
            taskTitle: task.title,
            taskColor: task.color,
            fireDate: fireDate,
            dayKey: cal.startOfDay(for: occ),
            isAllDay: task.isAllDay
        )

        await notificationService.scheduleReminders([reminder])
    }

    // MARK: - Diagnostics / UI list (next 7 days) — includes suppressed rows

    func upcomingReminderRowsNext7Days(tasks: [TaskEntity]) -> [ScheduledReminderItem] {
        let prefs: AppPreferencesEntity
        do {
            prefs = try preferencesRepository.getOrCreate()
        } catch {
            return []
        }

        let start = Calendar.current.startOfDay(for: .now)
        let end = Calendar.current.date(byAdding: .day, value: 7, to: start) ?? start.addingTimeInterval(7 * 86400)

        return buildReminderItemsForUI(
            tasks: tasks,
            prefs: prefs,
            rangeStart: start,
            rangeEnd: end
        )
        .sorted { $0.fireDate < $1.fireDate }
    }

    // MARK: - Core building

    private func buildPendingRemindersForRollingWindow(tasks: [TaskEntity], prefs: AppPreferencesEntity) -> [PendingReminder] {
        let start = Calendar.current.startOfDay(for: .now)
        let end = Calendar.current.date(byAdding: .day, value: rollingDays, to: start) ?? start.addingTimeInterval(Double(rollingDays) * 86400)

        return buildPendingRemindersForScheduling(tasks: tasks, prefs: prefs, rangeStart: start, rangeEnd: end)
    }

    private func buildPendingRemindersForScheduling(
        tasks: [TaskEntity],
        prefs: AppPreferencesEntity,
        rangeStart: Date,
        rangeEnd: Date
    ) -> [PendingReminder] {
        let cal = Calendar.current

        let enabledTasks = tasks.filter { $0.reminderEnabled }

        var out: [PendingReminder] = []
        out.reserveCapacity(enabledTasks.count * 2)

        for task in enabledTasks {
            let occurrenceDays = occurrenceStartDays(for: task, rangeStart: rangeStart, rangeEnd: rangeEnd)

            for day in occurrenceDays {
                let occurrenceKey = TaskEntity.dayKey(for: day, calendar: cal)

                if task.isReminderSuppressed(for: occurrenceKey) {
                    continue
                }

                guard let fireDate = computeFireDate(task: task, occurrenceDay: day, prefs: prefs, calendar: cal) else { continue }

                let taskKey = String(describing: task.persistentModelID)
                let id = notificationId(taskKey: taskKey, occurrenceKey: occurrenceKey)

                out.append(
                    PendingReminder(
                        id: id,
                        taskId: taskKey,
                        occurrenceKey: occurrenceKey,
                        taskTitle: task.title,
                        taskColor: task.color,
                        fireDate: fireDate,
                        dayKey: cal.startOfDay(for: day),
                        isAllDay: task.isAllDay
                    )
                )
            }
        }

        return out
    }

    private func buildReminderItemsForUI(
        tasks: [TaskEntity],
        prefs: AppPreferencesEntity,
        rangeStart: Date,
        rangeEnd: Date
    ) -> [ScheduledReminderItem] {
        let cal = Calendar.current
        let enabledTasks = tasks.filter { $0.reminderEnabled }

        var out: [ScheduledReminderItem] = []
        out.reserveCapacity(enabledTasks.count * 2)

        for task in enabledTasks {
            let occurrenceDays = occurrenceStartDays(for: task, rangeStart: rangeStart, rangeEnd: rangeEnd)

            for day in occurrenceDays {
                guard let fireDate = computeFireDate(task: task, occurrenceDay: day, prefs: prefs, calendar: cal) else { continue }

                let occurrenceKey = TaskEntity.dayKey(for: day, calendar: cal)
                let isSuppressed = task.isReminderSuppressed(for: occurrenceKey)

                let taskKey = String(describing: task.persistentModelID)
                let id = notificationId(taskKey: taskKey, occurrenceKey: occurrenceKey)

                out.append(
                    ScheduledReminderItem(
                        id: id,
                        taskId: taskKey,
                        occurrenceKey: occurrenceKey,
                        taskTitle: task.title,
                        taskColor: task.color,
                        fireDate: fireDate,
                        dayKey: cal.startOfDay(for: day),
                        isAllDay: task.isAllDay,
                        isSuppressed: isSuppressed
                    )
                )
            }
        }

        return out
    }

    private func occurrenceStartDays(for task: TaskEntity, rangeStart: Date, rangeEnd: Date) -> [Date] {
        let cal = Calendar.current

        var days: [Date] = []
        var cursor = cal.startOfDay(for: rangeStart)
        let endDay = cal.startOfDay(for: rangeEnd)

        while cursor < endDay {
            if TaskOccurrence.occursStartOn(task, on: cursor, weekStartsOnMonday: true /* reminders don't depend on week start */) {
                days.append(cursor)
            }
            cursor = cal.date(byAdding: .day, value: 1, to: cursor) ?? cursor.addingTimeInterval(86400)
        }

        return days
    }

    private func computeFireDate(
        task: TaskEntity,
        occurrenceDay: Date,
        prefs: AppPreferencesEntity,
        calendar cal: Calendar
    ) -> Date? {
        let offset = max(0, task.reminderOffsetMinutes)

        if task.isAllDay {
            let timeMinutes = task.reminderAllDayTimeMinutes ?? prefs.defaultAllDayTimeMinutes
            let base = TimeOfDayMinutes.date(on: occurrenceDay, minutes: timeMinutes, calendar: cal)
            return cal.date(byAdding: .minute, value: -offset, to: base)
        } else {
            let start = TaskOccurrence.combine(day: occurrenceDay, time: task.startTime, calendar: cal)
            return cal.date(byAdding: .minute, value: -offset, to: start)
        }
    }

    private func notificationId(taskKey: String, occurrenceKey: String) -> String {
        "\(taskKey)_\(occurrenceKey)"
    }

    private func buildAllPossibleIdsForTaskRollingWindow(task: TaskEntity) -> [String] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: .now)
        let end = cal.date(byAdding: .day, value: rollingDays, to: start) ?? start.addingTimeInterval(Double(rollingDays) * 86400)

        let days = occurrenceStartDays(for: task, rangeStart: start, rangeEnd: end)
        let taskKey = String(describing: task.persistentModelID)
        return days.map { day in
            let occurrenceKey = TaskEntity.dayKey(for: day, calendar: cal)
            return notificationId(taskKey: taskKey, occurrenceKey: occurrenceKey)
        }
    }
}

// MARK: - UI Model (Scheduled list)
struct ScheduledReminderItem: Identifiable, Hashable {
    let id: String
    let taskId: String
    let occurrenceKey: String
    let taskTitle: String
    let taskColor: TaskColor
    let fireDate: Date
    let dayKey: Date
    let isAllDay: Bool
    let isSuppressed: Bool
}
