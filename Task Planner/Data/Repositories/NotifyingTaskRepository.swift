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

    private enum NotificationSyncRequest {
        case all
        case tasks(Set<PersistentIdentifier>)
    }

    // guard against re-entrant save loops while preserving the latest queued save
    private var isSyncing = false
    private var pendingFullReschedule = false
    private var pendingTaskIDs: Set<PersistentIdentifier> = []

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
        let taskID = task.persistentModelID
        Task { [weak self] in
            await self?.replaceRemindersIfAllowed(for: [taskID])
        }
    }

    func delete(_ task: TaskEntity) throws {
        let taskID = task.persistentModelID
        Task { [notificationSync] in
            await notificationSync.cancelForTask(taskId: taskID)
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
        let taskIDs = tasks.map(\.persistentModelID)
        Task { [weak self] in
            await self?.replaceRemindersIfAllowed(for: taskIDs)
        }
    }

    private func rescheduleAllIfAllowed() async {
        await enqueueNotificationSync(.all)
    }

    private func replaceRemindersIfAllowed(for taskIDs: [PersistentIdentifier]) async {
        let uniqueTaskIDs = Set(taskIDs)
        guard !uniqueTaskIDs.isEmpty else { return }
        await enqueueNotificationSync(.tasks(uniqueTaskIDs))
    }

    private func enqueueNotificationSync(_ request: NotificationSyncRequest) async {
        if isSyncing {
            mergePendingSyncRequest(request)
            return
        }

        isSyncing = true
        defer { isSyncing = false }

        var request = request

        while true {
            pendingFullReschedule = false
            pendingTaskIDs.removeAll()

            await performNotificationSync(request)

            if pendingFullReschedule {
                request = .all
                continue
            }

            guard pendingTaskIDs.isEmpty == false else { break }
            request = .tasks(pendingTaskIDs)
        }
    }

    private func mergePendingSyncRequest(_ request: NotificationSyncRequest) {
        switch request {
        case .all:
            pendingFullReschedule = true
            pendingTaskIDs.removeAll()
        case .tasks(let taskIDs):
            guard pendingFullReschedule == false else { return }
            pendingTaskIDs.formUnion(taskIDs)
        }
    }

    private func performNotificationSync(_ request: NotificationSyncRequest) async {
        switch request {
        case .all:
            await performFullRescheduleIfAllowed()
        case .tasks(let taskIDs):
            await performReplaceRemindersIfAllowed(for: taskIDs)
        }
    }

    private func performFullRescheduleIfAllowed() async {
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

    private func performReplaceRemindersIfAllowed(for taskIDs: Set<PersistentIdentifier>) async {
        guard !taskIDs.isEmpty else { return }

        let prefs: AppPreferencesEntity
        do {
            prefs = try preferencesRepository.getOrCreate()
        } catch {
            return
        }

        if prefs.notificationsEnabled == false {
            for taskID in taskIDs {
                await notificationSync.cancelForTask(taskId: taskID)
            }
            return
        }

        let tasks = fetchExistingTasks(for: taskIDs)
        guard !tasks.isEmpty else { return }

        await notificationSync.replacePendingReminders(for: tasks)
    }

    private func fetchExistingTasks(for taskIDs: Set<PersistentIdentifier>) -> [TaskEntity] {
        taskIDs.compactMap { taskID in
            do {
                return try base.fetch(by: taskID)
            } catch {
                return nil
            }
        }
    }
}
