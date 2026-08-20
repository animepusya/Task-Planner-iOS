//
//  TaskCreationSource.swift
//  Task Planner
//
//  Created by Codex on 20.08.2026.
//

import Foundation
import SwiftData

struct TaskCreationSourceSnapshot: Equatable {
    let sourceID: PersistentIdentifier
    let title: String
    let notes: String?
    let isAllDay: Bool
    let startMinutes: Int
    let endMinutes: Int
    let endDayOffset: Int
    let repeatRule: RepeatRule
    let repeatIntervalDays: Int?
    let colorRaw: String
    let categoryTitle: String?
    let photoThumbData: Data?
    let reminderEnabled: Bool
    let reminderOffsetMinutes: Int
    let reminderAllDayTimeMinutes: Int?
}

struct TaskCreationSourceCandidate: Identifiable, Equatable {
    let snapshot: TaskCreationSourceSnapshot
    let sourceDay: Date
    let referenceDay: Date
    let isEnded: Bool

    var id: PersistentIdentifier { snapshot.sourceID }
    var title: String { snapshot.title }
    var color: TaskColor { TaskColor(rawValue: snapshot.colorRaw) ?? .purple }
    var repeatRule: RepeatRule { snapshot.repeatRule }

    var displayTitle: String {
        LocalizedDisplayText.taskTitle(snapshot.title)
    }

    var displayCategoryTitle: String {
        CategorySystem.localizedDisplayTitle(for: snapshot.categoryTitle)
    }

    var repeatSummary: String {
        if snapshot.repeatRule == .everyNDays {
            return String.localizedStringWithFormat(
                String(localized: "Every %lld days"),
                Int64(max(1, snapshot.repeatIntervalDays ?? 1))
            )
        }

        return snapshot.repeatRule.displayName
    }

    var timeSummary: String {
        guard snapshot.isAllDay == false else {
            return String(localized: "All day")
        }

        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: referenceDay)
        let endDay = calendar.date(
            byAdding: .day,
            value: max(0, snapshot.endDayOffset),
            to: startDay
        ) ?? startDay
        let start = TimeMinutes.date(on: startDay, minutes: snapshot.startMinutes, calendar: calendar)
        let end = TimeMinutes.date(on: endDay, minutes: snapshot.endMinutes, calendar: calendar)

        let startText = start.formatted(date: .omitted, time: .shortened)
        let endText = snapshot.endDayOffset > 0
            ? end.formatted(date: .abbreviated, time: .shortened)
            : end.formatted(date: .omitted, time: .shortened)

        return "\(startText) – \(endText)"
    }
}
