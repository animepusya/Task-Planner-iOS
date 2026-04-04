//
//  WidgetSnapshotSyncService.swift
//  Task Planner
//
//  Created by Руслан Меланин on 13.03.2026.
//

import Foundation
import WidgetKit

@MainActor
final class WidgetSnapshotSyncService {
    private let taskRepository: TaskRepository
    private let preferencesRepository: PreferencesRepository

    init(
        taskRepository: TaskRepository,
        preferencesRepository: PreferencesRepository
    ) {
        self.taskRepository = taskRepository
        self.preferencesRepository = preferencesRepository
    }

    func refreshSnapshot(referenceDate: Date = .now) {
        do {
            let tasks = try taskRepository.fetchAll()
            let preferences = try preferencesRepository.getOrCreate()

            let snapshot = WidgetSnapshotBuilder.build(
                tasks: tasks,
                weekStartsOnMonday: preferences.weekStartsOnMonday,
                referenceDate: referenceDate
            )

            WidgetStore.setAppTheme(preferences.theme)
            try WidgetStore.saveSnapshot(snapshot)
            WidgetCenter.shared.reloadTimelines(ofKind: WidgetShared.WidgetKind.plannerHome)
        } catch {
            assertionFailure("WidgetSnapshotSyncService.refreshSnapshot failed: \(error)")
        }
    }
}
