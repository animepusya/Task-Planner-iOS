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

        // Notifications
        let notificationService = UNUserNotificationService()
        let notificationSync = NotificationSyncService(
            notificationService: notificationService,
            preferencesRepository: prefsRepo
        )

        let synced = SyncedTaskRepository(
            base: base,
            calendarSync: calendarSync,
            preferencesRepository: prefsRepo
        )

        return NotifyingTaskRepository(
            base: synced,
            notificationSync: notificationSync,
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

    func makeNotificationService() -> NotificationService {
        UNUserNotificationService()
    }

    func makeNotificationSyncService(context: ModelContext) -> NotificationSyncService {
        let prefs = SwiftDataPreferencesRepository(context: context)
        return NotificationSyncService(
            notificationService: UNUserNotificationService(),
            preferencesRepository: prefs
        )
    }

    func ensureSystemCategories(using context: ModelContext) {
        let repo = SwiftDataCategoryRepository(context: context)
        try? repo.ensureSystemCategories()
    }
}
