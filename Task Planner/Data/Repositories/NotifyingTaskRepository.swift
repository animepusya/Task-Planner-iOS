//
//  NotifyingTaskRepository.swift
//  Task Planner
//
//  Created by Руслан Меланин on 03.03.2026.
//

import Foundation
import SwiftData

@MainActor
final class NotifyingTaskRepository: TaskRepository {

    private let base: TaskRepository
    private let notificationSync: NotificationSyncService
    private let preferencesRepository: PreferencesRepository

    // guard against re-entrant save loops
    private var isSyncing = false

    init(
        base: TaskRepository,
        notificationSync: NotificationSyncService,
        preferencesRepository: PreferencesRepository
    ) {
        self.base = base
        self.notificationSync = notificationSync
        self.preferencesRepository = preferencesRepository
    }

    func fetchAll() throws -> [TaskEntity] {
        try base.fetchAll()
    }

    func fetchRecurring() throws -> [TaskEntity] {
        try base.fetchRecurring()
    }

    func fetch(by id: PersistentIdentifier) throws -> TaskEntity? {
        try base.fetch(by: id)
    }

    func add(_ task: TaskEntity) throws {
        try base.add(task)
        Task { [weak self, task] in
            await self?.replaceRemindersIfAllowed(for: [task])
        }
    }

    func delete(_ task: TaskEntity) throws {
        // delete only affects this task's pending requests.
        Task { [notificationSync] in
            await notificationSync.cancelForTask(task: task)
        }
        try base.delete(task)
    }

    func deleteAll() throws {
        try base.deleteAll()
        Task { [notificationSync] in
            await notificationSync.cancelAllImmediately()
        }
    }

    func save() throws {
        try base.save()
        Task { [weak self] in
            await self?.rescheduleAllIfAllowed()
        }
    }

    func save(_ tasks: [TaskEntity]) throws {
        try base.save(tasks)
        Task { [weak self] in
            await self?.replaceRemindersIfAllowed(for: tasks)
        }
    }

    private func rescheduleAllIfAllowed() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        // If app-level is OFF -> cancel all now.
        let prefs: AppPreferencesEntity
        do {
            prefs = try preferencesRepository.getOrCreate()
        } catch {
            return
        }

        if prefs.notificationsEnabled == false {
            await notificationSync.cancelAllImmediately()
            return
        }

        do {
            let tasks = try base.fetchAll()
            await notificationSync.rescheduleAll(tasks: tasks)
        } catch {
            // best-effort
        }
    }

    private func replaceRemindersIfAllowed(for tasks: [TaskEntity]) async {
        guard !tasks.isEmpty else { return }
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        let prefs: AppPreferencesEntity
        do {
            prefs = try preferencesRepository.getOrCreate()
        } catch {
            return
        }

        if prefs.notificationsEnabled == false {
            for task in tasks {
                await notificationSync.cancelForTask(task: task)
            }
            return
        }

        await notificationSync.replacePendingReminders(for: tasks)
    }
}
