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
    private var refreshTask: Task<Void, Never>?
    private var pendingReferenceDate: Date?

    init(
        taskRepository: TaskRepository,
        preferencesRepository: PreferencesRepository
    ) {
        self.taskRepository = taskRepository
        self.preferencesRepository = preferencesRepository
    }

    func refreshSnapshot(referenceDate: Date = .now) {
        pendingReferenceDate = referenceDate
        guard refreshTask == nil else { return }
        startRefreshIfNeeded()
    }

    private func startRefreshIfNeeded() {
        guard refreshTask == nil else { return }

        let referenceDate = pendingReferenceDate ?? .now
        pendingReferenceDate = nil

        do {
            let tasks = try taskRepository.fetchAll()
            let preferences = try preferencesRepository.getOrCreate()
            let calendar = Calendar.current
            let taskSources = tasks.map { $0.plannerSource(calendar: calendar) }
            let weekStartsOnMonday = preferences.weekStartsOnMonday
            let theme = preferences.theme

            refreshTask = Task.detached(priority: .utility) { [weak self] in
                do {
                    let snapshot = WidgetSnapshotBuilder.build(
                        tasks: taskSources,
                        weekStartsOnMonday: weekStartsOnMonday,
                        referenceDate: referenceDate
                    )

                    WidgetStore.setAppTheme(theme)
                    try WidgetStore.saveSnapshot(snapshot)
                    WidgetCenter.shared.reloadTimelines(ofKind: WidgetShared.WidgetKind.plannerHome)
                } catch {
                    assertionFailure("WidgetSnapshotSyncService.refreshSnapshot failed: \(error)")
                }

                await MainActor.run {
                    guard let self else { return }

                    self.refreshTask = nil

                    if self.pendingReferenceDate != nil {
                        self.startRefreshIfNeeded()
                    }
                }
            }
        } catch {
            assertionFailure("WidgetSnapshotSyncService.refreshSnapshot failed: \(error)")
        }
    }
}
