//
//  PlannerApp.swift
//  Task Planner
//
//  Created by Руслан Меланин on 09.02.2026.
//

import SwiftUI
import SwiftData

@main
struct PlannerApp: App {
    private let container = ModelContainerFactory.make()

    var body: some Scene {
        WindowGroup {
            AppRootView(container: DependencyContainer(container: container))
        }
        .modelContainer(container)
    }
}
