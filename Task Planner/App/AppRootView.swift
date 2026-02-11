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

    var body: some View {
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
            .tabItem {
                Label("February", systemImage: "calendar")
            }
            .tag(AppTab.planner)

            StatisticsView(
                viewModel: StatisticsViewModel(
                    taskRepository: container.taskRepository,
                    preferencesRepository: container.preferencesRepository,
                    onOpenSettings: { sheet = .settings }
                )
            )
            .tabItem {
                Label("Statistics", systemImage: "chart.bar")
            }
            .tag(AppTab.statistics)
        }
        .sheet(item: $sheet) { route in
            switch route {
            case .taskEditor(let taskId, let day):
                TaskEditorView(
                    viewModel: TaskEditorViewModel(
                        taskRepository: container.taskRepository,
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


