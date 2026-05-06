//
//  AppRootDependencies.swift
//  Task Planner
//
//  Created by Codex on 20.03.2026.
//

import Foundation
import SwiftData
import Combine

@MainActor
final class AppRootDependencies: ObservableObject {
    let taskRepository: TaskRepository
    let preferencesRepository: PreferencesRepository
    let categoryRepository: CategoryRepository
    let calendarSyncService: CalendarSyncService
    let seriesService: TaskSeriesService
    let notificationService: NotificationService
    let notificationSyncService: NotificationSyncService
    let widgetSnapshotSyncService: WidgetSnapshotSyncService
    let subscriptionStore: SubscriptionStore

    private var isReconcilingNotifications = false

    init(container: DependencyContainer, context: ModelContext) {
        let preferencesRepository = container.makePreferencesRepository(context: context)
        let categoryRepository = container.makeCategoryRepository(context: context)
        let subscriptionStore = container.makeSubscriptionStore()

        let calendarSyncService = CalendarSyncService(
            preferencesRepository: preferencesRepository,
            modelContext: context
        )

        let notificationService = container.makeNotificationService()
        let notificationSyncService = NotificationSyncService(
            notificationService: notificationService,
            preferencesRepository: preferencesRepository
        )

        let baseTaskRepository = SwiftDataTaskRepository(context: context)
        let syncedTaskRepository = SyncedTaskRepository(
            base: baseTaskRepository,
            calendarSync: calendarSyncService,
            preferencesRepository: preferencesRepository
        )
        let notifyingTaskRepository = NotifyingTaskRepository(
            base: syncedTaskRepository,
            notificationSync: notificationSyncService,
            preferencesRepository: preferencesRepository
        )
        let widgetSnapshotSyncService = WidgetSnapshotSyncService(
            taskRepository: notifyingTaskRepository,
            preferencesRepository: preferencesRepository
        )
        let widgetSyncingTaskRepository = WidgetSyncingTaskRepository(
            base: notifyingTaskRepository,
            widgetSnapshotSync: widgetSnapshotSyncService
        )
        let taskRepository = PublishingTaskRepository(base: widgetSyncingTaskRepository)

        self.preferencesRepository = preferencesRepository
        self.categoryRepository = categoryRepository
        self.calendarSyncService = calendarSyncService
        self.notificationService = notificationService
        self.notificationSyncService = notificationSyncService
        self.widgetSnapshotSyncService = widgetSnapshotSyncService
        self.taskRepository = taskRepository
        self.seriesService = TaskSeriesService(taskRepository: taskRepository)
        self.subscriptionStore = subscriptionStore
    }

    func bootstrap() {
        _ = try? preferencesRepository.getOrCreate()
        try? categoryRepository.ensureSystemCategories()
        widgetSnapshotSyncService.refreshSnapshot()
        subscriptionStore.start()

        Task { [weak self] in
            await self?.reconcileNotificationsIfAllowed()
        }
    }

    func reconcileNotificationsIfAllowed() async {
        guard isReconcilingNotifications == false else { return }
        isReconcilingNotifications = true
        defer { isReconcilingNotifications = false }

        do {
            let tasks = try taskRepository.fetchAll()
            await notificationSyncService.reconcileAll(tasks: tasks)
        } catch {
            // Best-effort only. Task CRUD flows still do targeted notification sync.
        }
    }
}
