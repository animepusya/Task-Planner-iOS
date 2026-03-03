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

    func fetch(by id: PersistentIdentifier) throws -> TaskEntity? {
        try base.fetch(by: id)
    }

    func add(_ task: TaskEntity) throws {
        try base.add(task)
        Task { [weak self] in
            await self?.rescheduleAllIfAllowed()
        }
    }

    func delete(_ task: TaskEntity) throws {
        // cancel specific ids best-effort then reschedule
        Task { [notificationSync] in
            await notificationSync.cancelForTask(task: task)
        }
        try base.delete(task)

        Task { [weak self] in
            await self?.rescheduleAllIfAllowed()
        }
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
}
