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

    // Rolling window for repeating tasks to avoid infinite scheduling.
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

        // If user disabled app-level notifications -> cancel immediately.
        if prefs.notificationsEnabled == false {
            await notificationService.cancelAll()
            return
        }

        // If system denied -> do not schedule (keep UI guidance).
        guard auth == .authorized else {
            return
        }

        // We do a simple strategy: cancel all and schedule fresh for the rolling window.
        // MVP, robust, and avoids complex diff logic.
        await notificationService.cancelAll()

        let reminders = buildRemindersForRollingWindow(tasks: tasks, prefs: prefs)
        await notificationService.scheduleReminders(reminders)
    }

    func cancelAllImmediately() async {
        await notificationService.cancelAll()
    }

    func cancelForTask(task: TaskEntity) async {
        let ids = buildAllPossibleIdsForTaskRollingWindow(task: task)
        await notificationService.cancel(ids: ids)
    }

    // MARK: - Diagnostics / UI list (next 7 days)

    func upcomingRemindersNext7Days(tasks: [TaskEntity]) -> [PendingReminder] {
        let prefs: AppPreferencesEntity
        do {
            prefs = try preferencesRepository.getOrCreate()
        } catch {
            return []
        }

        let start = Calendar.current.startOfDay(for: .now)
        let end = Calendar.current.date(byAdding: .day, value: 7, to: start) ?? start.addingTimeInterval(7 * 86400)

        return buildReminders(
            tasks: tasks,
            prefs: prefs,
            rangeStart: start,
            rangeEnd: end
        ).sorted { $0.fireDate < $1.fireDate }
    }

    // MARK: - Core building

    private func buildRemindersForRollingWindow(tasks: [TaskEntity], prefs: AppPreferencesEntity) -> [PendingReminder] {
        let start = Calendar.current.startOfDay(for: .now)
        let end = Calendar.current.date(byAdding: .day, value: rollingDays, to: start) ?? start.addingTimeInterval(Double(rollingDays) * 86400)

        return buildReminders(tasks: tasks, prefs: prefs, rangeStart: start, rangeEnd: end)
    }

    private func buildReminders(
        tasks: [TaskEntity],
        prefs: AppPreferencesEntity,
        rangeStart: Date,
        rangeEnd: Date
    ) -> [PendingReminder] {
        let cal = Calendar.current

        // Only tasks with reminder enabled.
        let enabledTasks = tasks.filter { $0.reminderEnabled }

        var out: [PendingReminder] = []
        out.reserveCapacity(enabledTasks.count * 2)

        for task in enabledTasks {
            let occurrenceDays = occurrenceStartDays(for: task, rangeStart: rangeStart, rangeEnd: rangeEnd)

            for day in occurrenceDays {
                // MVP: multi-day tasks — schedule only at start (or first day for all-day).
                let fire = computeFireDate(task: task, occurrenceDay: day, prefs: prefs, calendar: cal)
                if fire == nil { continue }

                let fireDate = fire!
                let id = notificationId(task: task, occurrenceDay: day, calendar: cal)

                out.append(
                    PendingReminder(
                        id: id,
                        taskId: String(describing: task.persistentModelID),
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
            // Non-all-day: schedule relative to start time.
            // Use occurrence day + task.startTime's time component.
            let start = TaskOccurrence.combine(day: occurrenceDay, time: task.startTime, calendar: cal)
            return cal.date(byAdding: .minute, value: -offset, to: start)
        }
    }

    private func notificationId(task: TaskEntity, occurrenceDay: Date, calendar: Calendar) -> String {
        let taskKey = String(describing: task.persistentModelID)
        let dayKey = TaskEntity.dayKey(for: occurrenceDay, calendar: calendar)
        return "task-\(taskKey)-\(dayKey)"
    }

    private func buildAllPossibleIdsForTaskRollingWindow(task: TaskEntity) -> [String] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: .now)
        let end = cal.date(byAdding: .day, value: rollingDays, to: start) ?? start.addingTimeInterval(Double(rollingDays) * 86400)

        let days = occurrenceStartDays(for: task, rangeStart: start, rangeEnd: end)
        return days.map { notificationId(task: task, occurrenceDay: $0, calendar: cal) }
    }
}
