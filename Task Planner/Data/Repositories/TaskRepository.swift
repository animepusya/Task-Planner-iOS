//
//  TaskRepository.swift
//  Task Planner
//
//  Created by Руслан Меланин on 09.02.2026.
//

import Combine
import Foundation
import SwiftData

struct TaskRepositoryChange: Equatable, Sendable {
    let revision: Int
}

@MainActor
protocol TaskRepository {
    var changePublisher: AnyPublisher<TaskRepositoryChange, Never> { get }
    func fetchAll() throws -> [TaskEntity]
    func fetchScheduled() throws -> [TaskEntity]
    func fetchUnscheduled() throws -> [TaskEntity]
    func fetchRecurring() throws -> [TaskEntity]
    func fetch(by id: PersistentIdentifier) throws -> TaskEntity?
    func add(_ task: TaskEntity) throws
    func delete(_ task: TaskEntity) throws
    func deleteAll() throws
    func save() throws
    func save(_ task: TaskEntity) throws
    func save(_ tasks: [TaskEntity]) throws
}

private enum TaskRepositoryDefaults {
    static let emptyChangePublisher = Empty<TaskRepositoryChange, Never>(
        completeImmediately: false
    )
    .eraseToAnyPublisher()
}

extension TaskRepository {
    var changePublisher: AnyPublisher<TaskRepositoryChange, Never> {
        TaskRepositoryDefaults.emptyChangePublisher
    }

    func fetchRecurring() throws -> [TaskEntity] {
        try fetchScheduled().filter { $0.repeatRule != .none }
    }

    func fetchScheduled() throws -> [TaskEntity] {
        try fetchAll().filter(\.isScheduled)
    }

    func fetchUnscheduled() throws -> [TaskEntity] {
        try fetchAll()
            .filter { $0.schedule == nil }
            .sorted {
                $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }
    }

    func save(_ task: TaskEntity) throws {
        try save([task])
    }

    func save(_ tasks: [TaskEntity]) throws {
        try save()
    }
}
