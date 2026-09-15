//
//  SwiftDataTaskRepository.swift
//  Task Planner
//
//  Created by Руслан Меланин on 09.02.2026.
//

import Foundation
import SwiftData

@MainActor
final class SwiftDataTaskRepository: TaskRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchAll() throws -> [TaskEntity] {
        let descriptor = FetchDescriptor<TaskEntity>(
            sortBy: [SortDescriptor(\.dayDate, order: .forward)]
        )
        return try context.fetch(descriptor)
    }

    func fetchScheduled() throws -> [TaskEntity] {
        let descriptor = FetchDescriptor<TaskEntity>(
            predicate: #Predicate<TaskEntity> { task in
                task.dayDate != nil
                    && task.startTime != nil
                    && task.endTime != nil
            },
            sortBy: [SortDescriptor(\.dayDate, order: .forward)]
        )
        return try context.fetch(descriptor)
    }

    func fetchUnscheduled() throws -> [TaskEntity] {
        let descriptor = FetchDescriptor<TaskEntity>(
            predicate: #Predicate<TaskEntity> { task in
                task.dayDate == nil
            },
            sortBy: [SortDescriptor(\.title, order: .forward)]
        )

        return try context.fetch(descriptor)
            .filter { $0.dayDate == nil && $0.startTime == nil && $0.endTime == nil }
            .sorted {
                $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }
    }

    func fetchRecurring() throws -> [TaskEntity] {
        let noneRuleRaw = RepeatRule.none.rawValue
        let descriptor = FetchDescriptor<TaskEntity>(
            predicate: #Predicate<TaskEntity> { task in
                task.repeatRuleRaw != noneRuleRaw
                    && task.dayDate != nil
                    && task.startTime != nil
                    && task.endTime != nil
            },
            sortBy: [
                SortDescriptor(\.title, order: .forward),
                SortDescriptor(\.dayDate, order: .forward)
            ]
        )
        return try context.fetch(descriptor)
    }

    func fetch(by id: PersistentIdentifier) throws -> TaskEntity? {
        context.model(for: id) as? TaskEntity
    }

    func add(_ task: TaskEntity) throws {
        context.insert(task)
        try save()
    }

    func delete(_ task: TaskEntity) throws {
        let allTasks = try fetchAll()
        TaskStatisticsIdentity.unlink(task, among: allTasks)
        context.delete(task)
        try save()
    }

    func deleteAll() throws {
        let all = try fetchAll()
        all.forEach { context.delete($0) }
        try save()
    }

    func save() throws {
        if context.hasChanges {
            try context.save()
        }
    }

    func save(_ tasks: [TaskEntity]) throws {
        try save()
    }
}
