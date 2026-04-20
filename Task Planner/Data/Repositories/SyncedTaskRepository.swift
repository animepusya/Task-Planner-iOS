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

    func fetchRecurring() throws -> [TaskEntity] {
        try base.fetchRecurring()
    }

    func fetch(by id: PersistentIdentifier) throws -> TaskEntity? {
        try base.fetch(by: id)
    }

    func add(_ task: TaskEntity) throws {
        try base.add(task)
        try exportTasksIfEnabled([task])
    }

    func delete(_ task: TaskEntity) throws {
        // delete exported event best-effort; no full re-export needed for unrelated tasks.
        Task { [calendarSync] in
            try? await calendarSync.deleteExportedEventIfNeeded(for: task)
        }
        try base.delete(task)
    }

    func deleteAll() throws {
        try base.deleteAll()
    }

    func save() throws {
        try base.save()
        try resyncAllIfEnabled()
    }

    func save(_ tasks: [TaskEntity]) throws {
        try base.save(tasks)
        try exportTasksIfEnabled(tasks)
    }

    private func resyncAllIfEnabled() throws {
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

    private func exportTasksIfEnabled(_ tasks: [TaskEntity]) throws {
        guard !tasks.isEmpty else { return }
        guard !isResyncing else { return }

        let prefs = try preferencesRepository.getOrCreate()
        guard prefs.showTasksInAppleCalendar else { return }

        isResyncing = true
        defer { isResyncing = false }

        Task { [calendarSync] in
            try? await calendarSync.exportTasks(tasks)
        }
    }
}
