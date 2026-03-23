//
//  AppRootView.swift
//  Task Planner
//
//  Created by Руслан Меланин on 09.02.2026.
//

import SwiftUI
import SwiftData

struct AppRootView: View {
    let container: DependencyContainer

    @Environment(\.modelContext) private var modelContext

    init(container: DependencyContainer) {
        self.container = container
        UITabBar.appearance().isHidden = true
    }

    var body: some View {
        AppRootContentView(container: container, modelContext: modelContext)
    }
}

private struct AppRootContentView: View {
    @StateObject private var dependencies: AppRootDependencies

    @State private var selectedTab: AppTab = .planner
    @State private var sheet: SheetRoute?
    @State private var didBootstrap = false

    init(container: DependencyContainer, modelContext: ModelContext) {
        _dependencies = StateObject(
            wrappedValue: container.makeAppRootDependencies(context: modelContext)
        )
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            PlannerView(
                taskRepository: dependencies.taskRepository,
                preferencesRepository: dependencies.preferencesRepository,
                calendarSync: dependencies.calendarSyncService,
                seriesService: dependencies.seriesService,
                onOpenTaskEditor: { taskId, day in
                    sheet = .taskEditor(taskId: taskId, preselectedDay: day, mode: .standard)
                },
                onOpenNotifications: {
                    sheet = .notifications
                },
                onOpenRecurringBaseTasks: {
                    sheet = .recurringBaseTasks
                }
            )
            .tag(AppTab.planner)

            StatisticsView(
                taskRepository: dependencies.taskRepository,
                preferencesRepository: dependencies.preferencesRepository,
                onOpenSettings: { sheet = .settings }
            )
            .tag(AppTab.statistics)
        }
        .toolbar(.hidden, for: .tabBar)
        .overlay(alignment: .bottom) {
            CustomTabBar(
                selected: selectedTab,
                plannerTitle: Date.now.monthName(),
                onSelectPlanner: { selectedTab = .planner },
                onSelectStatistics: { selectedTab = .statistics }
            )
            .padding(.bottom, DS.Layout.tabBarBottomSpacing)
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .zIndex(10)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .sheet(item: $sheet, content: sheetView)
        .task {
            guard !didBootstrap else { return }
            didBootstrap = true
            dependencies.bootstrap()
        }
        .onOpenURL(perform: handleOpenURL)
    }

    @ViewBuilder
    private func sheetView(route: SheetRoute) -> some View {
        switch route {
        case .taskEditor(let taskId, let day, let mode):
            TaskEditorView(
                taskRepository: dependencies.taskRepository,
                preferencesRepository: dependencies.preferencesRepository,
                notificationService: dependencies.notificationService,
                seriesService: dependencies.seriesService,
                taskId: taskId,
                preselectedDay: day,
                editMode: mode,
                onOpenNotificationsCenter: {
                    sheet = .notifications
                }
            )

        case .settings:
            SettingsView(
                preferencesRepository: dependencies.preferencesRepository,
                taskRepository: dependencies.taskRepository,
                categoryRepository: dependencies.categoryRepository,
                calendarSync: dependencies.calendarSyncService,
                makeNotificationsView: {
                    NotificationsView(
                        taskRepository: dependencies.taskRepository,
                        preferencesRepository: dependencies.preferencesRepository,
                        notificationService: dependencies.notificationService,
                        notificationSync: dependencies.notificationSyncService,
                        onOpenTaskEditor: { taskId, day in
                            sheet = .taskEditor(taskId: taskId, preselectedDay: day, mode: .standard)
                        }
                    )
                }
            )

        case .notifications:
            NotificationsView(
                taskRepository: dependencies.taskRepository,
                preferencesRepository: dependencies.preferencesRepository,
                notificationService: dependencies.notificationService,
                notificationSync: dependencies.notificationSyncService,
                onOpenTaskEditor: { taskId, day in
                    sheet = .taskEditor(taskId: taskId, preselectedDay: day, mode: .standard)
                }
            )

        case .recurringBaseTasks:
            RecurringTasksView(
                taskRepository: dependencies.taskRepository,
                preferencesRepository: dependencies.preferencesRepository,
                onOpenBaseRecurringEditor: { taskId, day in
                    sheet = .taskEditor(taskId: taskId, preselectedDay: day, mode: .baseRecurringIdentity)
                }
            )
        }
    }

    private func handleOpenURL(_ url: URL) {
        guard let route = WidgetRoute(url: url) else { return }

        switch route {
        case .planner(let day):
            sheet = nil
            selectedTab = .planner
            WidgetRouteCenter.postPlannerDay(day)

        case .createTask(let day):
            selectedTab = .planner
            sheet = .taskEditor(taskId: nil, preselectedDay: day, mode: .standard)
        }
    }
}
