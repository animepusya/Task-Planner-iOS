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

    init() {
        let modelContainer = ModelContainerFactory.make()
        self.modelContainer = modelContainer
        self.dependencyContainer = DependencyContainer(container: modelContainer)
    }

    var body: some Scene {
        WindowGroup {
            PlannerSceneView(container: dependencyContainer)
        }
        .modelContainer(modelContainer)
    }
}

private struct PlannerSceneView: View {
    let container: DependencyContainer

    @Environment(\.modelContext) private var modelContext
    @Query private var preferences: [AppPreferencesEntity]

    @State private var showSplash = true

    private var appTheme: AppTheme {
        preferences.first?.theme ?? .system
    }

    var body: some View {
        ZStack {
            AppBackgroundView(gradient: DS.GradientToken.splash)

            AppRootView(container: container)
                .opacity(showSplash ? 0 : 1)
                .animation(.easeOut(duration: 0.25), value: showSplash)

            if showSplash {
                SplashView {
                    showSplash = false
                }
                .transition(.opacity)
            }
        }
        .preferredColorScheme(appTheme.preferredColorScheme)
        .task {
            _ = try? SwiftDataPreferencesRepository(context: modelContext).getOrCreate()
        }
    }
}
