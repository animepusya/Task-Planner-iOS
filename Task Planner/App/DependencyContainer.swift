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

    init(container: ModelContainer) {
        let context = ModelContext(container)
        self.taskRepository = SwiftDataTaskRepository(context: context)
        self.preferencesRepository = SwiftDataPreferencesRepository(context: context)
    }
}
