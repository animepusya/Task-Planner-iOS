//
//  PublishingTaskRepository.swift
//  Task Planner
//
//  Created by Codex on 20.04.2026.
//

import Combine
import Foundation
import SwiftData

@MainActor
final class PublishingTaskRepository: TaskRepository {
    private let base: TaskRepository
    private let changeSubject = PassthroughSubject<TaskRepositoryChange, Never>()
    private var revision = 0

    init(base: TaskRepository) {
        self.base = base
    }

    var changePublisher: AnyPublisher<TaskRepositoryChange, Never> {
        changeSubject.eraseToAnyPublisher()
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
        publishChange()
    }

    func delete(_ task: TaskEntity) throws {
        try base.delete(task)
        publishChange()
    }

    func deleteAll() throws {
        try base.deleteAll()
        publishChange()
    }

    func save() throws {
        try base.save()
        publishChange()
    }

    func save(_ tasks: [TaskEntity]) throws {
        try base.save(tasks)
        publishChange()
    }

    private func publishChange() {
        revision &+= 1
        changeSubject.send(TaskRepositoryChange(revision: revision))
    }
}
