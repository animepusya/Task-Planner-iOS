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

    var body: some View {
        AppRootContentView(container: container, modelContext: modelContext)
    }
}

private struct AppRootContentView: View {
    @StateObject private var dependencies: AppRootDependencies
    @Environment(\.scenePhase) private var scenePhase

    @State private var selectedTab: AppTab = .planner
    @State private var statisticsNavigationPath: [AppRoute] = []
    @State private var sheet: SheetRoute?
    @State private var didBootstrap = false

    init(container: DependencyContainer, modelContext: ModelContext) {
        _dependencies = StateObject(
            wrappedValue: container.makeAppRootDependencies(context: modelContext)
        )
    }

    var body: some View {
        AppRootTabShellView(
            dependencies: dependencies,
            selectedTab: $selectedTab,
            statisticsNavigationPath: $statisticsNavigationPath,
            sheet: $sheet
        )
        .environmentObject(dependencies.subscriptionStore)
        .task {
            guard !didBootstrap else { return }
            didBootstrap = true
            dependencies.bootstrap()
        }
        .onChange(of: scenePhase) { _, newValue in
            guard didBootstrap, newValue == .active else { return }

            Task {
                await dependencies.subscriptionStore.refreshOnAppForeground()
            }
        }
        .onOpenURL(perform: handleOpenURL)
    }

    private func handleOpenURL(_ url: URL) {
        guard let route = WidgetRoute(url: url) else { return }
        statisticsNavigationPath.removeAll()

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

private struct AppRootTabShellView: View {
    let dependencies: AppRootDependencies
    @Binding var selectedTab: AppTab
    @Binding var statisticsNavigationPath: [AppRoute]
    @Binding var sheet: SheetRoute?

    @State private var statisticsComparisonViewModel: StatisticsViewModel?
    @State private var loadedTabs: Set<AppTab> = [.planner]

    private var showsTabBar: Bool {
        guard selectedTab == .statistics else { return true }
        return statisticsNavigationPath.last?.hidesStatisticsTabBar != true
    }

    var body: some View {
        DSAdaptiveLayoutScope { metrics in
            ZStack {
                if loadedTabs.contains(.planner) {
                    AppRootTabLayer(isVisible: selectedTab == .planner) {
                        plannerRootView
                    }
                }

                if loadedTabs.contains(.statistics) {
                    AppRootTabLayer(isVisible: selectedTab == .statistics) {
                        statisticsRootView
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .overlay(alignment: .bottom) {
                if showsTabBar {
                    CustomTabBar(
                        selected: selectedTab,
                        plannerTitle: Date.now.monthName(),
                        onSelectPlanner: { select(.planner) },
                        onSelectStatistics: { select(.statistics) }
                    )
                    .padding(.bottom, metrics.tabBarBottomSpacing)
                    .ignoresSafeArea(.keyboard, edges: .bottom)
                    .zIndex(10)
                }
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .sheet(item: $sheet, content: sheetView)
            .onAppear {
                ensureLoaded(selectedTab)
            }
            .onChange(of: selectedTab) { _, newValue in
                ensureLoaded(newValue)
            }
        }
    }

    private var plannerRootView: some View {
        PlannerView(
            taskRepository: dependencies.taskRepository,
            preferencesRepository: dependencies.preferencesRepository,
            calendarSync: dependencies.calendarSyncService,
            seriesService: dependencies.seriesService,
            isActive: selectedTab == .planner,
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
    }

    private var statisticsRootView: some View {
        NavigationStack(path: $statisticsNavigationPath) {
            StatisticsView(
                taskRepository: dependencies.taskRepository,
                preferencesRepository: dependencies.preferencesRepository,
                isActive: selectedTab == .statistics,
                onOpenSettings: openSettings,
                onOpenComparison: openStatisticsComparison,
                onOpenPaywall: openPaywall
            )
            .navigationDestination(for: AppRoute.self, destination: destinationView)
        }
    }

    private func openSettings() {
        guard statisticsNavigationPath.last != .settings else { return }
        statisticsNavigationPath.append(.settings)
    }

    private func openStatisticsComparison(using viewModel: StatisticsViewModel) {
        statisticsComparisonViewModel = viewModel
        guard statisticsNavigationPath.last != .statisticsComparison else { return }
        statisticsNavigationPath.append(.statisticsComparison)
    }

    private func openPaywall(_ entryPoint: PaywallEntryPoint) {
        guard statisticsNavigationPath.last != .paywall(entryPoint) else { return }
        statisticsNavigationPath.append(.paywall(entryPoint))
    }

    private func select(_ tab: AppTab) {
        ensureLoaded(tab)
        selectedTab = tab
    }

    private func ensureLoaded(_ tab: AppTab) {
        loadedTabs.insert(tab)
    }

    @ViewBuilder
    private func destinationView(route: AppRoute) -> some View {
        switch route {
        case .settings:
            SettingsView(
                preferencesRepository: dependencies.preferencesRepository,
                taskRepository: dependencies.taskRepository,
                categoryRepository: dependencies.categoryRepository,
                calendarSync: dependencies.calendarSyncService,
                onOpenPaywall: openPaywall,
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
            .environmentObject(dependencies.subscriptionStore)

        case .statisticsComparison:
            if let statisticsComparisonViewModel {
                StatisticsComparisonView(viewModel: statisticsComparisonViewModel)
            }

        case .paywall(let entryPoint):
            PaywallView(entryPoint: entryPoint)
                .environmentObject(dependencies.subscriptionStore)
        }
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
            .environmentObject(dependencies.subscriptionStore)

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
}

private struct AppRootTabLayer<Content: View>: View {
    let isVisible: Bool
    private let content: Content

    init(
        isVisible: Bool,
        @ViewBuilder content: () -> Content
    ) {
        self.isVisible = isVisible
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .opacity(isVisible ? 1 : 0)
            .allowsHitTesting(isVisible)
            .accessibilityHidden(!isVisible)
            .zIndex(isVisible ? 1 : 0)
    }
}
