//
//  WidgetSnapshotSyncService.swift
//  Task Planner
//
//  Created by Руслан Меланин on 13.03.2026.
//

import Foundation
import WidgetKit

private nonisolated struct WidgetSnapshotRefreshRequest: Sendable {
    let referenceDate: Date
    let taskSources: [PlannerTaskSource]
    let weekStartsOnMonday: Bool
    let theme: AppTheme
}

private nonisolated enum WidgetSnapshotRefreshWorker {
    static func run(_ request: WidgetSnapshotRefreshRequest) async {
        await Task.detached(priority: .utility) { [request] in
            do {
                let snapshot = WidgetSnapshotBuilder.build(
                    tasks: request.taskSources,
                    weekStartsOnMonday: request.weekStartsOnMonday,
                    referenceDate: request.referenceDate
                )

                WidgetStore.setAppTheme(request.theme)
                try WidgetStore.saveSnapshot(snapshot)
                WidgetCenter.shared.reloadTimelines(ofKind: WidgetShared.WidgetKind.plannerHome)
            } catch {
                assertionFailure("WidgetSnapshotSyncService.refreshSnapshot failed: \(error)")
            }
        }
        .value
    }
}

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

        guard let request = makeRefreshRequest() else { return }

        refreshTask = Task { [request] in
            await WidgetSnapshotRefreshWorker.run(request)
            finishRefreshCycle()
        }
    }

    private func makeRefreshRequest() -> WidgetSnapshotRefreshRequest? {
        let referenceDate = pendingReferenceDate ?? .now
        pendingReferenceDate = nil

        do {
            let tasks = try taskRepository.fetchAll()
            let preferences = try preferencesRepository.getOrCreate()
            let calendar = Calendar.current

            return WidgetSnapshotRefreshRequest(
                referenceDate: referenceDate,
                taskSources: tasks.map { $0.plannerSource(calendar: calendar) },
                weekStartsOnMonday: preferences.weekStartsOnMonday,
                theme: preferences.theme
            )
        } catch {
            assertionFailure("WidgetSnapshotSyncService.refreshSnapshot failed: \(error)")
            return nil
        }
    }

    private func finishRefreshCycle() {
        refreshTask = nil

        if pendingReferenceDate != nil {
            startRefreshIfNeeded()
        }
    }
}
