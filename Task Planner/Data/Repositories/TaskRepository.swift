//
//  TaskRepository.swift
//  Task Planner
//
//  Created by Руслан Меланин on 09.02.2026.
//

import Foundation
import SwiftData

@MainActor
protocol TaskRepository {
    func fetchAll() throws -> [TaskEntity]
    func fetch(by id: PersistentIdentifier) throws -> TaskEntity?
    func add(_ task: TaskEntity) throws
    func delete(_ task: TaskEntity) throws
    func deleteAll() throws
    func save() throws
}
