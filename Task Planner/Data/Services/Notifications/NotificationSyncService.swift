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
        await reconcileAll(tasks: tasks)
    }

    func reconcileAll(tasks: [TaskEntity]) async {
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

        let reminders = buildPendingRemindersForRollingWindow(tasks: tasks, prefs: prefs)

        #if DEBUG
        await notificationService.debugLogPendingRequests(label: "before full reconcile")
        #endif

        await notificationService.reconcile(reminders: reminders)

        #if DEBUG
        await notificationService.debugLogPendingRequests(label: "after full reconcile")
        #endif
    }

    func replacePendingReminders(for tasks: [TaskEntity]) async {
        guard !tasks.isEmpty else { return }

        let uniqueTasks = uniqueTasksPreservingOrder(tasks)

        let prefs: AppPreferencesEntity
        do {
            prefs = try preferencesRepository.getOrCreate()
        } catch {
            return
        }

        let taskIDsToCancel = uniqueTasks.flatMap { taskCancellationKeys(for: $0) }
        guard prefs.notificationsEnabled else {
            await notificationService.cancel(taskIDs: taskIDsToCancel)
            return
        }

        let auth = await notificationService.getAuthorizationStatus()
        guard auth == .authorized else { return }

        let reminders = buildPendingRemindersForRollingWindow(tasks: uniqueTasks, prefs: prefs)

        #if DEBUG
        await notificationService.debugLogPendingRequests(label: "before targeted replace taskIDs=\(taskIDsToCancel)")
        #endif

        await notificationService.cancel(taskIDs: taskIDsToCancel, matching: reminders)

        #if DEBUG
        await notificationService.debugLogPendingRequests(label: "after targeted cancel taskIDs=\(taskIDsToCancel)")
        #endif

        await notificationService.scheduleReminders(reminders)

        #if DEBUG
        await notificationService.debugLogPendingRequests(label: "after targeted schedule taskIDs=\(taskIDsToCancel)")
        #endif
    }

    func cancelAllImmediately() async {
        await notificationService.cancelAll()
    }

    func cancelForTask(task: TaskEntity) async {
        await notificationService.cancel(taskIDs: taskCancellationKeys(for: task))
    }

    func cancelForTask(stableTaskID: String?, legacyTaskID: String) async {
        let ids = [stableTaskID, legacyTaskID]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
        await notificationService.cancel(taskIDs: ids)
    }

    func cancelForTask(taskId: PersistentIdentifier) async {
        let taskID = taskKey(for: taskId)
        await notificationService.cancel(taskIDs: [taskID])
    }

    func cancelSingle(taskId: PersistentIdentifier, occurrenceKey: String) async {
        let taskKey = taskKey(for: taskId)
        await notificationService.cancel(ids: notificationIds(taskKey: taskKey, occurrenceKey: occurrenceKey))
    }

    func scheduleSingleOccurrence(task: TaskEntity, occurrenceDay: Date) async {
        let prefs: AppPreferencesEntity
        do {
            prefs = try preferencesRepository.getOrCreate()
        } catch { return }

        guard prefs.notificationsEnabled else { return }
        let auth = await notificationService.getAuthorizationStatus()
        guard auth == .authorized else { return }

        let cal = Calendar.current
        let start = cal.startOfDay(for: .now)
        let end = cal.date(byAdding: .day, value: rollingDays, to: start) ?? start.addingTimeInterval(Double(rollingDays) * 86400)

        let occ = cal.startOfDay(for: occurrenceDay)
        guard occ >= start && occ < end else { return }

        TaskSeriesEngine.ensureBaseSegmentIfNeeded(for: task, calendar: cal)
        guard let tpl = TaskSeriesEngine.template(for: task, startDay: occ, calendar: cal) else { return }
        guard tpl.reminderEnabled else { return }

        let occurrenceKey = TaskEntity.dayKey(for: occ, calendar: cal)
        guard task.isReminderSuppressed(for: occurrenceKey) == false else { return }

        guard let fireDate = computeFireDate(task: task, occurrenceDay: occ, prefs: prefs, calendar: cal) else { return }

        let taskKey = taskKey(for: task)
        let legacyTaskKey = legacyTaskKey(for: task)
        let id = notificationId(taskKey: taskKey, occurrenceKey: occurrenceKey)

        let reminder = PendingReminder(
            id: id,
            taskId: taskKey,
            legacyTaskId: legacyTaskKey,
            occurrenceKey: occurrenceKey,
            taskTitle: tpl.title,
            taskColor: TaskColor(rawValue: tpl.colorRaw) ?? task.color,
            fireDate: fireDate,
            dayKey: cal.startOfDay(for: occ),
            isAllDay: tpl.isAllDay
        )

        #if DEBUG
        await notificationService.debugLogPendingRequests(label: "before single occurrence replace taskID=\(taskKey) occurrenceKey=\(occurrenceKey)")
        #endif

        await notificationService.cancel(taskIDs: taskCancellationKeys(for: task), matching: [reminder])

        #if DEBUG
        await notificationService.debugLogPendingRequests(label: "after single occurrence cancel taskID=\(taskKey) occurrenceKey=\(occurrenceKey)")
        #endif

        await notificationService.scheduleReminders([reminder])

        #if DEBUG
        await notificationService.debugLogPendingRequests(label: "after single occurrence schedule taskID=\(taskKey) occurrenceKey=\(occurrenceKey)")
        #endif
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

    private func candidateTasksForReminderScan(from tasks: [TaskEntity]) -> [TaskEntity] {
        tasks.filter { task in
            if task.repeatRule != .none { return true }
            return task.reminderEnabled
        }
    }

    private func buildPendingRemindersForScheduling(
        tasks: [TaskEntity],
        prefs: AppPreferencesEntity,
        rangeStart: Date,
        rangeEnd: Date
    ) -> [PendingReminder] {
        let cal = Calendar.current
        let candidateTasks = candidateTasksForReminderScan(from: tasks)

        var out: [PendingReminder] = []
        out.reserveCapacity(candidateTasks.count * 2)

        for task in candidateTasks {
            TaskSeriesEngine.ensureBaseSegmentIfNeeded(for: task, calendar: cal)

            let occurrenceDays = occurrenceStartDays(for: task, rangeStart: rangeStart, rangeEnd: rangeEnd)

            for day in occurrenceDays {
                let occurrenceKey = TaskEntity.dayKey(for: day, calendar: cal)

                if task.isReminderSuppressed(for: occurrenceKey) {
                    continue
                }

                guard let tpl = TaskSeriesEngine.template(for: task, startDay: day, calendar: cal) else { continue }
                guard tpl.reminderEnabled else { continue }
                guard let fireDate = computeFireDate(task: task, occurrenceDay: day, prefs: prefs, calendar: cal) else { continue }

                let taskKey = taskKey(for: task)
                let legacyTaskKey = legacyTaskKey(for: task)
                let id = notificationId(taskKey: taskKey, occurrenceKey: occurrenceKey)

                out.append(
                    PendingReminder(
                        id: id,
                        taskId: taskKey,
                        legacyTaskId: legacyTaskKey,
                        occurrenceKey: occurrenceKey,
                        taskTitle: tpl.title,
                        taskColor: TaskColor(rawValue: tpl.colorRaw) ?? task.color,
                        fireDate: fireDate,
                        dayKey: cal.startOfDay(for: day),
                        isAllDay: tpl.isAllDay
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
        let candidateTasks = candidateTasksForReminderScan(from: tasks)

        var out: [ScheduledReminderItem] = []
        out.reserveCapacity(candidateTasks.count * 2)

        for task in candidateTasks {
            TaskSeriesEngine.ensureBaseSegmentIfNeeded(for: task, calendar: cal)
            let occurrenceDays = occurrenceStartDays(for: task, rangeStart: rangeStart, rangeEnd: rangeEnd)

            for day in occurrenceDays {
                guard let tpl = TaskSeriesEngine.template(for: task, startDay: day, calendar: cal) else { continue }
                guard tpl.reminderEnabled else { continue }
                guard let fireDate = computeFireDate(task: task, occurrenceDay: day, prefs: prefs, calendar: cal) else { continue }

                let occurrenceKey = TaskEntity.dayKey(for: day, calendar: cal)
                let isSuppressed = task.isReminderSuppressed(for: occurrenceKey)

                let taskKey = taskKey(for: task)
                let scheduledTaskID = legacyTaskKey(for: task)
                let id = notificationId(taskKey: taskKey, occurrenceKey: occurrenceKey)

                out.append(
                    ScheduledReminderItem(
                        id: id,
                        taskId: scheduledTaskID,
                        occurrenceKey: occurrenceKey,
                        taskTitle: tpl.title,
                        taskColor: TaskColor(rawValue: tpl.colorRaw) ?? task.color,
                        fireDate: fireDate,
                        dayKey: cal.startOfDay(for: day),
                        isAllDay: tpl.isAllDay,
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
            if TaskOccurrence.occursStartOn(task, on: cursor, weekStartsOnMonday: true) {
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
        TaskSeriesEngine.ensureBaseSegmentIfNeeded(for: task, calendar: cal)
        guard let tpl = TaskSeriesEngine.template(for: task, startDay: occurrenceDay, calendar: cal) else {
            return nil
        }

        let offset = max(0, tpl.reminderOffsetMinutes)

        if tpl.isAllDay {
            let timeMinutes = tpl.reminderAllDayTimeMinutes ?? prefs.defaultAllDayTimeMinutes
            let base = TimeOfDayMinutes.date(on: occurrenceDay, minutes: timeMinutes, calendar: cal)
            return cal.date(byAdding: .minute, value: -offset, to: base)
        } else {
            let start = TimeMinutes.date(on: occurrenceDay, minutes: tpl.startMinutes, calendar: cal)
            return cal.date(byAdding: .minute, value: -offset, to: start)
        }
    }

    private func notificationId(taskKey: String, occurrenceKey: String) -> String {
        "reminder-v2-\(taskKey)-\(occurrenceKey)"
    }

    private func currentLegacyNotificationId(taskKey: String, occurrenceKey: String) -> String {
        "\(taskKey)_\(occurrenceKey)"
    }

    private func oldLegacyNotificationId(taskKey: String, occurrenceKey: String) -> String {
        "task-\(taskKey)-\(occurrenceKey)"
    }

    private func notificationIds(taskKey: String, occurrenceKey: String) -> [String] {
        [
            notificationId(taskKey: taskKey, occurrenceKey: occurrenceKey),
            currentLegacyNotificationId(taskKey: taskKey, occurrenceKey: occurrenceKey),
            oldLegacyNotificationId(taskKey: taskKey, occurrenceKey: occurrenceKey)
        ]
    }

    private func taskKey(for task: TaskEntity) -> String {
        task.reminderTaskKeyForScheduling
    }

    private func legacyTaskKey(for task: TaskEntity) -> String {
        task.reminderLegacyTaskKey
    }

    private func taskKey(for taskId: PersistentIdentifier) -> String {
        String(describing: taskId)
    }

    private func taskCancellationKeys(for task: TaskEntity) -> [String] {
        Array(Set([taskKey(for: task), legacyTaskKey(for: task)].filter { $0.isEmpty == false }))
    }

    private func uniqueTasksPreservingOrder(_ tasks: [TaskEntity]) -> [TaskEntity] {
        var seen: Set<PersistentIdentifier> = []
        var uniqueTasks: [TaskEntity] = []
        uniqueTasks.reserveCapacity(tasks.count)

        for task in tasks {
            if seen.insert(task.persistentModelID).inserted {
                uniqueTasks.append(task)
            }
        }

        return uniqueTasks
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
