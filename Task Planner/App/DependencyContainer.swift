//
//  DependencyContainer.swift
//  Task Planner
//
//  Created by Руслан Меланин on 09.02.2026.
//

import SwiftData

@MainActor
final class DependencyContainer {
    let modelContainer: ModelContainer

    init(container: ModelContainer) {
        self.modelContainer = container
    }

    func makeTaskRepository(context: ModelContext) -> TaskRepository {
        SwiftDataTaskRepository(context: context)
    }

    func makePreferencesRepository(context: ModelContext) -> PreferencesRepository {
        SwiftDataPreferencesRepository(context: context)
    }

    func makeCategoryRepository(context: ModelContext) -> CategoryRepository {
        SwiftDataCategoryRepository(context: context)
    }

    func ensureSystemCategories(using context: ModelContext) {
        let repo = SwiftDataCategoryRepository(context: context)
        try? repo.ensureSystemCategories()
    }
}
