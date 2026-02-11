//
//  SwiftDataCategoryRepository.swift
//  Task Planner
//
//  Created by Руслан Меланин on 11.02.2026.
//

import Foundation
import SwiftData

@MainActor
final class SwiftDataCategoryRepository: CategoryRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchAll() throws -> [CategoryEntity] {
        let descriptor = FetchDescriptor<CategoryEntity>(
            sortBy: [SortDescriptor(\.title, order: .forward)]
        )
        return try context.fetch(descriptor)
    }

    func ensureSystemCategories() throws {
        let existing = try fetchAll()
        let ids = Set(existing.map { $0.id })

        func upsert(id: String, title: String) {
            if ids.contains(id) { return }
            context.insert(CategoryEntity(id: id, title: title))
        }

        upsert(id: CategorySystem.uncategorizedId, title: CategorySystem.uncategorizedTitle)
        upsert(id: CategorySystem.workId, title: CategorySystem.workTitle)
        upsert(id: CategorySystem.studyId, title: CategorySystem.studyTitle)
        upsert(id: CategorySystem.hobbyId, title: CategorySystem.hobbyTitle)

        try save()
    }

    func add(title: String) throws {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // уникальность по title (case-insensitive)
        let all = try fetchAll()
        if all.contains(where: { $0.title.lowercased() == trimmed.lowercased() }) { return }

        context.insert(CategoryEntity(id: UUID().uuidString, title: trimmed))
        try save()
    }

    func delete(_ category: CategoryEntity) throws {
        context.delete(category)
        try save()
    }

    func save() throws {
        if context.hasChanges {
            try context.save()
        }
    }
}
