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
    private let modelContainer: ModelContainer
    private let dependencyContainer: DependencyContainer

    @State private var showSplash = true

    init() {
        let modelContainer = ModelContainerFactory.make()
        self.modelContainer = modelContainer
        self.dependencyContainer = DependencyContainer(container: modelContainer)
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                // 1) Подложка — всегда, чтобы не было белых флешей
                AppBackgroundView(gradient: DS.GradientToken.splash)

                // 2) Контент
                AppRootView(container: dependencyContainer)
                    .opacity(showSplash ? 0 : 1)
                    .animation(.easeOut(duration: 0.25), value: showSplash)

                // 3) Splash поверх
                if showSplash {
                    SplashView {
                        showSplash = false
                    }
                    .transition(.opacity)
                }
            }
        }
        .modelContainer(modelContainer)
    }
}
