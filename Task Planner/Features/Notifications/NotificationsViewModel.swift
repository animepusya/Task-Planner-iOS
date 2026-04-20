//
//  NotificationsViewModel.swift
//  Task Planner
//
//  Created by Руслан Меланин on 03.03.2026.
//

import Foundation
import SwiftData
import SwiftUI
import Combine

@MainActor
final class NotificationsViewModel: ObservableObject {

    private let taskRepository: TaskRepository
    private let preferencesRepository: PreferencesRepository
    private let notificationService: NotificationService
    private let notificationSync: NotificationSyncService
    private let onOpenTaskEditor: (_ taskId: PersistentIdentifier?, _ day: Date) -> Void

    @Published private(set) var systemStatus: NotificationAuthorizationStatus = .notDetermined
    @Published private(set) var isLoading: Bool = false

    @Published var notificationsEnabled: Bool = true
    @Published var defaultReminderOffsetMinutes: Int = ReminderPreset.default.minutes
    @Published var defaultAllDayTimeMinutes: Int = 9 * 60

    init(
        taskRepository: TaskRepository,
        preferencesRepository: PreferencesRepository,
        notificationService: NotificationService,
        notificationSync: NotificationSyncService,
        onOpenTaskEditor: @escaping (_ taskId: PersistentIdentifier?, _ day: Date) -> Void
    ) {
        self.taskRepository = taskRepository
        self.preferencesRepository = preferencesRepository
        self.notificationService = notificationService
        self.notificationSync = notificationSync
        self.onOpenTaskEditor = onOpenTaskEditor
    }

    func onAppear() {
        Task { [weak self] in
            guard let self else { return }
            await self.refresh()
        }
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let prefs = try preferencesRepository.getOrCreate()
            notificationsEnabled = prefs.notificationsEnabled
            defaultReminderOffsetMinutes = ReminderPreset.normalizeOffsetMinutes(prefs.defaultReminderOffsetMinutes)
            defaultAllDayTimeMinutes = prefs.defaultAllDayTimeMinutes

            if prefs.defaultReminderOffsetMinutes != defaultReminderOffsetMinutes {
                prefs.defaultReminderOffsetMinutes = defaultReminderOffsetMinutes
                try preferencesRepository.save()
            }
        } catch { }

        systemStatus = await notificationService.getAuthorizationStatus()
    }

    // MARK: - Actions

    func primaryActionTapped() {
        switch systemStatus {
        case .notDetermined:
            Task { [weak self] in
                guard let self else { return }
                self.isLoading = true
                defer { self.isLoading = false }

                let ok = await self.notificationService.requestAuthorization()
                self.systemStatus = await self.notificationService.getAuthorizationStatus()

                if ok {
                    await self.rescheduleAllIfNeeded()
                }
            }

        case .denied:
            notificationService.openSystemSettings()

        case .authorized:
            break
        }
    }

    func setNotificationsEnabled(_ enabled: Bool) {
        notificationsEnabled = enabled

        do {
            let prefs = try preferencesRepository.getOrCreate()
            prefs.notificationsEnabled = enabled
            try preferencesRepository.save()
        } catch { }

        Task { [weak self] in
            guard let self else { return }
            if enabled == false {
                await self.notificationSync.cancelAllImmediately()
            } else {
                await self.rescheduleAllIfNeeded()
            }
        }
    }

    func setDefaultOffsetMinutes(_ minutes: Int) {
        let normalized = ReminderPreset.normalizeOffsetMinutes(minutes)
        defaultReminderOffsetMinutes = normalized

        do {
            let prefs = try preferencesRepository.getOrCreate()
            prefs.defaultReminderOffsetMinutes = normalized
            try preferencesRepository.save()
        } catch { }

        Task { [weak self] in
            await self?.rescheduleAllIfNeeded()
        }
    }

    func setDefaultAllDayTimeMinutes(_ minutes: Int) {
        defaultAllDayTimeMinutes = TimeOfDayMinutes.clamp(minutes)
        do {
            let prefs = try preferencesRepository.getOrCreate()
            prefs.defaultAllDayTimeMinutes = TimeOfDayMinutes.clamp(minutes)
            try preferencesRepository.save()
        } catch { }

        Task { [weak self] in
            await self?.rescheduleAllIfNeeded()
        }
    }

    func openTask(taskId: PersistentIdentifier, day: Date) {
        onOpenTaskEditor(taskId, day)
    }

    // MARK: - Per-occurrence disable / enable

    func disableReminderForThisDay(taskId: PersistentIdentifier, occurrenceKey: String) {
        Task { [weak self] in
            guard let self else { return }
            await self.disableInternal(taskId: taskId, occurrenceKey: occurrenceKey)
        }
    }

    func enableReminderForThisDay(taskId: PersistentIdentifier, occurrenceKey: String, occurrenceDay: Date) {
        Task { [weak self] in
            guard let self else { return }
            await self.enableInternal(taskId: taskId, occurrenceKey: occurrenceKey, occurrenceDay: occurrenceDay)
        }
    }

    private func disableInternal(taskId: PersistentIdentifier, occurrenceKey: String) async {
        do {
            guard let task = try taskRepository.fetch(by: taskId) else { return }
            task.suppressReminder(for: occurrenceKey)
            try taskRepository.save(task)
        } catch {
        }
    }

    private func enableInternal(taskId: PersistentIdentifier, occurrenceKey: String, occurrenceDay: Date) async {
        do {
            guard let task = try taskRepository.fetch(by: taskId) else { return }
            task.unsuppressReminder(for: occurrenceKey)
            try taskRepository.save(task)
        } catch {
        }
    }

    // MARK: - Scheduled list

    func scheduledNext7Days(tasks: [TaskEntity]) -> [ScheduledReminderItem] {
        guard notificationsEnabled else { return [] }
        guard systemStatus == .authorized else { return [] }

        return notificationSync.upcomingReminderRowsNext7Days(tasks: tasks)
    }

    // MARK: - Private

    private func rescheduleAllIfNeeded() async {
        guard notificationsEnabled else { return }
        guard systemStatus == .authorized else { return }

        do {
            let tasks = try taskRepository.fetchAll()
            await notificationSync.rescheduleAll(tasks: tasks)
        } catch { }
    }
}
