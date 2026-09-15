//
//  RecurringTaskSource.swift
//  Task Planner
//
//  Created by Codex on 21.04.2026.
//

import Foundation
import SwiftData

nonisolated struct RecurringTaskSource: Identifiable, Equatable, Sendable {
    let id: PersistentIdentifier
    let dayDate: Date
    let title: String
    let categoryTitle: String?
    let repeatRule: RepeatRule
    let color: TaskColor
    let photoThumbData: Data?
    let plannerSource: PlannerTaskSource

    @MainActor
    init?(task: TaskEntity, calendar: Calendar = .current) {
        guard let schedule = task.schedule,
              let source = task.plannerSource(calendar: calendar)
        else {
            return nil
        }

        self.id = task.persistentModelID
        self.dayDate = calendar.startOfDay(for: schedule.dayDate)
        self.title = source.baseTemplate.title
        self.categoryTitle = source.baseTemplate.categoryTitle
        self.repeatRule = source.ownerRepeatRule
        self.color = TaskColor(rawValue: source.baseTemplate.colorRaw) ?? .purple
        self.photoThumbData = source.baseTemplate.photoThumbData
        self.plannerSource = source
    }
}
