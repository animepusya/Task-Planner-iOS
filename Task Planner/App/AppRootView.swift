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

    @State private var selectedTab: AppTab = .planner
    @State private var sheet: SheetRoute?
    @State private var didBootstrap = false

    init(container: DependencyContainer) {
        self.container = container
        UITabBar.appearance().isHidden = true
    }

    var body: some View {
        let taskRepo = container.makeTaskRepository(context: modelContext)
        let prefsRepo = container.makePreferencesRepository(context: modelContext)
        let categoryRepo = container.makeCategoryRepository(context: modelContext)
        let calendarSync = container.makeCalendarSyncService(context: modelContext)
        let seriesService = TaskSeriesService(taskRepository: taskRepo)
        let notificationService = container.makeNotificationService()
        let notificationSync = container.makeNotificationSyncService(context: modelContext)
        let widgetSnapshotSync = container.makeWidgetSnapshotSyncService(context: modelContext)

        GeometryReader { _ in
            ZStack {
                AppBackgroundView(gradient: DS.GradientToken.splash)

                TabView(selection: $selectedTab) {
                    PlannerView(
                        viewModel: PlannerViewModel(
                            taskRepository: taskRepo,
                            preferencesRepository: prefsRepo,
                            calendarSync: calendarSync,
                            seriesService: seriesService,
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
                    )
                    .tag(AppTab.planner)

                    StatisticsView(
                        viewModel: StatisticsViewModel(
                            taskRepository: taskRepo,
                            preferencesRepository: prefsRepo,
                            onOpenSettings: { sheet = .settings }
                        )
                    )
                    .tag(AppTab.statistics)
                }
                .toolbar(.hidden, for: .tabBar)
            }
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
            .sheet(item: $sheet) { route in
                switch route {
                case .taskEditor(let taskId, let day, let mode):
                    TaskEditorView(
                        viewModel: TaskEditorViewModel(
                            taskRepository: taskRepo,
                            preferencesRepository: prefsRepo,
                            notificationService: notificationService,
                            seriesService: seriesService,
                            taskId: taskId,
                            preselectedDay: day,
                            editMode: mode
                        ),
                        onOpenNotificationsCenter: {
                            sheet = .notifications
                        }
                    )

                case .settings:
                    SettingsView(
                        viewModel: SettingsViewModel(
                            preferencesRepository: prefsRepo,
                            taskRepository: taskRepo,
                            categoryRepository: categoryRepo,
                            calendarSync: calendarSync
                        )
                    )

                case .notifications:
                    NotificationsView(
                        viewModel: NotificationsViewModel(
                            taskRepository: taskRepo,
                            preferencesRepository: prefsRepo,
                            notificationService: notificationService,
                            notificationSync: notificationSync,
                            onOpenTaskEditor: { taskId, day in
                                sheet = .taskEditor(taskId: taskId, preselectedDay: day, mode: .standard)
                            }
                        )
                    )

                case .recurringBaseTasks:
                    RecurringTasksView(
                        viewModel: RecurringTasksViewModel(
                            taskRepository: taskRepo,
                            preferencesRepository: prefsRepo,
                            onOpenBaseRecurringEditor: { taskId, day in
                                sheet = .taskEditor(taskId: taskId, preselectedDay: day, mode: .baseRecurringIdentity)
                            }
                        )
                    )
                }
            }
        }
        .task {
            guard !didBootstrap else { return }
            didBootstrap = true
            container.ensureSystemCategories(using: modelContext)
            widgetSnapshotSync.refreshSnapshot()
        }
        .onOpenURL { url in
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
}
