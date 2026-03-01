//
//  SyncedTaskRepository.swift
//  Task Planner
//
//  Created by Руслан Меланин on 01.03.2026.
//

import Foundation
import SwiftData

@MainActor
final class SyncedTaskRepository: TaskRepository {

    private let base: TaskRepository
    private let calendarSync: CalendarSyncService
    private let preferencesRepository: PreferencesRepository

    // guard against re-entrant save during identifier updates
    private var isResyncing = false

    init(
        base: TaskRepository,
        calendarSync: CalendarSyncService,
        preferencesRepository: PreferencesRepository
    ) {
        self.base = base
        self.calendarSync = calendarSync
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
        try triggerResyncIfEnabled(reason: "add")
    }

    func delete(_ task: TaskEntity) throws {
        // delete exported event first (best-effort)
        Task { [calendarSync] in
            try? await calendarSync.deleteExportedEventIfNeeded(for: task)
        }
        try base.delete(task)
        try triggerResyncIfEnabled(reason: "delete")
    }

    func deleteAll() throws {
        try base.deleteAll()
        try triggerResyncIfEnabled(reason: "deleteAll")
    }

    func save() throws {
        try base.save()
        try triggerResyncIfEnabled(reason: "save")
    }

    private func triggerResyncIfEnabled(reason: String) throws {
        guard !isResyncing else { return }

        let prefs = try preferencesRepository.getOrCreate()
        guard prefs.showTasksInAppleCalendar else { return }

        isResyncing = true
        defer { isResyncing = false }

        // simplest reliable approach: export all
        let tasks = try base.fetchAll()
        Task { [calendarSync] in
            try? await calendarSync.exportAllTasks(tasks)
        }
    }
}
