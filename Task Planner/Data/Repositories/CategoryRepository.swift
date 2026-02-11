//
//  CategoryRepository.swift
//  Task Planner
//
//  Created by Руслан Меланин on 11.02.2026.
//

import Foundation
import SwiftData

@MainActor
protocol CategoryRepository {
    func fetchAll() throws -> [CategoryEntity]
    func add(title: String) throws
    func delete(_ category: CategoryEntity) throws
    func ensureSystemCategories() throws
    func save() throws
}
