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
        let base = SwiftDataTaskRepository(context: context)

        let prefsRepo = SwiftDataPreferencesRepository(context: context)
        let calendarSync = CalendarSyncService(
            preferencesRepository: prefsRepo,
            modelContext: context
        )

        return SyncedTaskRepository(
            base: base,
            calendarSync: calendarSync,
            preferencesRepository: prefsRepo
        )
    }

    func makePreferencesRepository(context: ModelContext) -> PreferencesRepository {
        SwiftDataPreferencesRepository(context: context)
    }

    func makeCategoryRepository(context: ModelContext) -> CategoryRepository {
        SwiftDataCategoryRepository(context: context)
    }

    func makeCalendarSyncService(context: ModelContext) -> CalendarSyncService {
        let prefs = SwiftDataPreferencesRepository(context: context)
        return CalendarSyncService(preferencesRepository: prefs, modelContext: context)
    }

    func ensureSystemCategories(using context: ModelContext) {
        let repo = SwiftDataCategoryRepository(context: context)
        try? repo.ensureSystemCategories()
    }
}
