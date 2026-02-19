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

        ZStack {
            AppBackgroundView(gradient: DS.GradientToken.splash)

            TabView(selection: $selectedTab) {
                PlannerView(
                    viewModel: PlannerViewModel(
                        taskRepository: taskRepo,
                        preferencesRepository: prefsRepo,
                        onOpenTaskEditor: { taskId, day in
                            sheet = .taskEditor(taskId: taskId, preselectedDay: day)
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
                            taskRepository: taskRepo,
                            preferencesRepository: prefsRepo,
                            taskId: taskId,
                            preselectedDay: day
                        )
                    )

                case .settings:
                    SettingsView(
                        viewModel: SettingsViewModel(
                            preferencesRepository: prefsRepo,
                            taskRepository: taskRepo,
                            categoryRepository: categoryRepo
                        )
                    )
                }
            }
        }
        .task {
            guard !didBootstrap else { return }
            didBootstrap = true
            container.ensureSystemCategories(using: modelContext)
        }
    }
}
