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

    func makeAppRootDependencies(context: ModelContext) -> AppRootDependencies {
        AppRootDependencies(container: self, context: context)
    }

    func makeTaskRepository(context: ModelContext) -> TaskRepository {
        let base = SwiftDataTaskRepository(context: context)

        let prefsRepo = SwiftDataPreferencesRepository(context: context)

        let calendarSync = CalendarSyncService(
            preferencesRepository: prefsRepo,
            modelContext: context
        )

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

        let notifying = NotifyingTaskRepository(
            base: synced,
            notificationSync: notificationSync,
            preferencesRepository: prefsRepo
        )

        let widgetSync = WidgetSnapshotSyncService(
            taskRepository: notifying,
            preferencesRepository: prefsRepo
        )

        return WidgetSyncingTaskRepository(
            base: notifying,
            widgetSnapshotSync: widgetSync
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

    func makeSubscriptionService() -> SubscriptionService {
        StoreKitSubscriptionService()
    }

    func makeSubscriptionStore() -> SubscriptionStore {
        SubscriptionStore(service: makeSubscriptionService())
    }

    func makeNotificationSyncService(context: ModelContext) -> NotificationSyncService {
        let prefs = SwiftDataPreferencesRepository(context: context)
        return NotificationSyncService(
            notificationService: UNUserNotificationService(),
            preferencesRepository: prefs
        )
    }

    func makeWidgetSnapshotSyncService(context: ModelContext) -> WidgetSnapshotSyncService {
        let taskRepo = makeTaskRepository(context: context)
        let prefsRepo = makePreferencesRepository(context: context)

        return WidgetSnapshotSyncService(
            taskRepository: taskRepo,
            preferencesRepository: prefsRepo
        )
    }

    func ensureSystemCategories(using context: ModelContext) {
        let repo = SwiftDataCategoryRepository(context: context)
        try? repo.ensureSystemCategories()
    }
}
