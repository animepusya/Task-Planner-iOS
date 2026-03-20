//
//  PlannerScreenSnapshot.swift
//  Task Planner
//
//  Created by Руслан Меланин on 16.03.2026.
//

import Foundation
import SwiftUI

struct PlannerMonthDayViewData: Identifiable, Hashable {
    let id: String
    let date: Date
    let dayNumber: Int
    let isInDisplayedMonth: Bool
    let isSelected: Bool
    let indicatorColors: [TaskColor]
}

struct PlannerTaskRowData: Identifiable, Hashable {
    let occurrence: DayOccurrence
    let modelCompleted: Bool

    var id: String { occurrence.id }
}

struct PlannerImportedEventRowData: Identifiable, Hashable {
    let event: ExternalCalendarEvent
    let mappedColor: TaskColor

    var id: String { event.id }
}

enum PlannerSelectedDayItemViewData: Identifiable, Hashable {
    case task(PlannerTaskRowData)
    case imported(PlannerImportedEventRowData)

    var id: String {
        switch self {
        case .task(let row):
            return "task-\(row.id)"
        case .imported(let row):
            return "imported-\(row.id)"
        }
    }
}

struct PlannerSelectedDaySectionData: Hashable {
    let title: String
    let taskCount: Int
    let items: [PlannerSelectedDayItemViewData]

    var isEmpty: Bool { items.isEmpty }
}

struct PlannerScreenSnapshot: Hashable {
    let weekdaySymbols: [String]
    let monthDays: [PlannerMonthDayViewData]
    let selectedDaySection: PlannerSelectedDaySectionData

    static let empty = PlannerScreenSnapshot(
        weekdaySymbols: [],
        monthDays: [],
        selectedDaySection: .init(
            title: "",
            taskCount: 0,
            items: []
        )
    )
}
