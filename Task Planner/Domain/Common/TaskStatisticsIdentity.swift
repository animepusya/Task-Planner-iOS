//
//  TaskStatisticsIdentity.swift
//  Task Planner
//
//  Created by Codex on 20.08.2026.
//

import Foundation

nonisolated struct TaskStatisticsIdentity: Equatable, Sendable {
    let id: String
    let title: String
    let colorRaw: String

    init?(
        id: String?,
        title: String?,
        colorRaw: String?,
        fallbackTitle: String,
        fallbackColorRaw: String
    ) {
        guard let normalizedID = Self.normalizedNonempty(id) else {
            return nil
        }

        self.id = normalizedID
        self.title = Self.normalizedNonempty(title) ?? fallbackTitle

        if let normalizedColorRaw = Self.normalizedNonempty(colorRaw),
           TaskColor(rawValue: normalizedColorRaw) != nil {
            self.colorRaw = normalizedColorRaw
        } else {
            self.colorRaw = fallbackColorRaw
        }
    }

    @MainActor
    init?(task: TaskEntity) {
        self.init(
            id: task.statisticsIdentityID,
            title: task.statisticsIdentityTitle,
            colorRaw: task.statisticsIdentityColorRaw,
            fallbackTitle: task.title,
            fallbackColorRaw: task.colorRaw
        )
    }

    private static func normalizedNonempty(_ value: String?) -> String? {
        guard let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              normalized.isEmpty == false else {
            return nil
        }

        return normalized
    }
}
