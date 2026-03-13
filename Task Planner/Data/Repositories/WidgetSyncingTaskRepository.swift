//
//  WidgetSyncingTaskRepository.swift
//  Task Planner
//
//  Created by Руслан Меланин on 13.03.2026.
//

import Foundation
import SwiftData

@MainActor
final class WidgetSyncingTaskRepository: TaskRepository {
    private let base: TaskRepository
    private let widgetSnapshotSync: WidgetSnapshotSyncService

    init(
        base: TaskRepository,
        widgetSnapshotSync: WidgetSnapshotSyncService
    ) {
        self.base = base
        self.widgetSnapshotSync = widgetSnapshotSync
    }

    func fetchAll() throws -> [TaskEntity] {
        try base.fetchAll()
    }

    func fetch(by id: PersistentIdentifier) throws -> TaskEntity? {
        try base.fetch(by: id)
    }

    func add(_ task: TaskEntity) throws {
        try base.add(task)
        widgetSnapshotSync.refreshSnapshot()
    }

    func delete(_ task: TaskEntity) throws {
        try base.delete(task)
        widgetSnapshotSync.refreshSnapshot()
    }

    func deleteAll() throws {
        try base.deleteAll()
        widgetSnapshotSync.refreshSnapshot()
    }

    func save() throws {
        try base.save()
        widgetSnapshotSync.refreshSnapshot()
    }
}
