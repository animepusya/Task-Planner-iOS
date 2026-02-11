//
//  DependencyContainer.swift
//  Task Planner
//
//  Created by Руслан Меланин on 09.02.2026.
//

import SwiftData

@MainActor
final class DependencyContainer {
    let taskRepository: TaskRepository
    let preferencesRepository: PreferencesRepository
    let categoryRepository: CategoryRepository

    init(container: ModelContainer) {
        let context = ModelContext(container)

        self.taskRepository = SwiftDataTaskRepository(context: context)
        self.preferencesRepository = SwiftDataPreferencesRepository(context: context)
        self.categoryRepository = SwiftDataCategoryRepository(context: context)

        try? self.categoryRepository.ensureSystemCategories()
    }
}
