//
//  TaskStatisticsIdentity.swift
//  Task Planner
//
//  Created by Codex on 20.08.2026.
//

import Foundation
import SwiftData

nonisolated struct TaskStatisticsIdentity: Equatable, Sendable {
    let id: String
    let title: String
    let colorRaw: String

    init(id: String, canonicalTitle: String, canonicalColor: TaskColor) {
        self.id = id
        self.title = canonicalTitle
        self.colorRaw = canonicalColor.rawValue
    }

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

    @MainActor
    func write(to task: TaskEntity) {
        task.statisticsIdentityID = id
        task.statisticsIdentityTitle = title
        task.statisticsIdentityColorRaw = colorRaw
    }

    @MainActor
    static func clear(from task: TaskEntity) {
        task.statisticsIdentityID = nil
        task.statisticsIdentityTitle = nil
        task.statisticsIdentityColorRaw = nil
    }

    @MainActor
    static func unlink(
        _ task: TaskEntity,
        among allTasks: [TaskEntity]
    ) {
        guard let identity = TaskStatisticsIdentity(task: task) else {
            clear(from: task)
            return
        }

        let remainingMembers = allTasks.filter { candidate in
            candidate.persistentModelID != task.persistentModelID
                && TaskStatisticsIdentity(task: candidate)?.id == identity.id
        }

        clear(from: task)

        if remainingMembers.count == 1,
           let lastMember = remainingMembers.first {
            clear(from: lastMember)
        }
    }

    private static func normalizedNonempty(_ value: String?) -> String? {
        guard let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              normalized.isEmpty == false else {
            return nil
        }

        return normalized
    }
}
