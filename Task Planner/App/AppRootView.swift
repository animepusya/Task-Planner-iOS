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

    @State private var selectedTab: AppTab = .planner
    @State private var sheet: SheetRoute?

    init(container: DependencyContainer) {
        self.container = container
        UITabBar.appearance().isHidden = true
    }

    var body: some View {
        ZStack {
            AppBackgroundView(gradient: DS.GradientToken.splash)

            TabView(selection: $selectedTab) {
                PlannerView(
                    viewModel: PlannerViewModel(
                        taskRepository: container.taskRepository,
                        preferencesRepository: container.preferencesRepository,
                        onOpenTaskEditor: { taskId, day in
                            sheet = .taskEditor(taskId: taskId, preselectedDay: day)
                        }
                    )
                )
                .tag(AppTab.planner)

                StatisticsView(
                    viewModel: StatisticsViewModel(
                        taskRepository: container.taskRepository,
                        preferencesRepository: container.preferencesRepository,
                        onOpenSettings: { sheet = .settings }
                    )
                )
                .tag(AppTab.statistics)
            }
            .toolbar(.hidden, for: .tabBar)
            .safeAreaInset(edge: .bottom) {
                CustomTabBar(
                    selected: selectedTab,
                    plannerTitle: Date.now.monthName(),
                    onSelectPlanner: { selectedTab = .planner },
                    onSelectStatistics: { selectedTab = .statistics }
                )
                .padding(.top, 8)
                .background(Color.clear)
            }
            .sheet(item: $sheet) { route in
                switch route {
                case .taskEditor(let taskId, let day):
                    TaskEditorView(
                        viewModel: TaskEditorViewModel(
                            taskRepository: container.taskRepository,
                            preferencesRepository: container.preferencesRepository,
                            taskId: taskId,
                            preselectedDay: day
                        )
                    )

                case .settings:
                    SettingsView(
                        viewModel: SettingsViewModel(
                            preferencesRepository: container.preferencesRepository,
                            taskRepository: container.taskRepository,
                            categoryRepository: container.categoryRepository
                        )
                    )
                }
            }
        }
    }
}
