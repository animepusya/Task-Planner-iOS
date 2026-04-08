//
//  PlannerScreenSnapshot.swift
//  Task Planner
//
//  Created by Руслан Меланин on 16.03.2026.
//

import Foundation
import SwiftUI

nonisolated struct PlannerMonthDaySnapshot: Identifiable, Hashable, Sendable {
    let id: String
    let date: Date
    let dayNumber: Int
    let isInDisplayedMonth: Bool
    let indicatorColors: [TaskColor]

    func viewData(isSelected: Bool) -> PlannerMonthDayViewData {
        PlannerMonthDayViewData(
            id: id,
            date: date,
            dayNumber: dayNumber,
            isInDisplayedMonth: isInDisplayedMonth,
            isSelected: isSelected,
            indicatorColors: indicatorColors
        )
    }
}

nonisolated struct PlannerMonthDayViewData: Identifiable, Hashable, Sendable {
    let id: String
    let date: Date
    let dayNumber: Int
    let isInDisplayedMonth: Bool
    let isSelected: Bool
    let indicatorColors: [TaskColor]
}

nonisolated struct PlannerTaskRowData: Identifiable, Hashable, Sendable {
    let occurrence: PlannerTaskOccurrence
    let modelCompleted: Bool

    var id: String { occurrence.id }
}

nonisolated struct PlannerImportedEventRowData: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let calendarTitle: String
    let location: String?
    let mappedColor: TaskColor

    init(source: PlannerExternalEventSource) {
        self.id = source.id
        self.title = source.title
        self.startDate = source.startDate
        self.endDate = source.endDate
        self.isAllDay = source.isAllDay
        self.calendarTitle = source.calendarTitle
        self.location = source.location
        self.mappedColor = source.mappedColor
    }
}

nonisolated enum PlannerSelectedDayItemViewData: Identifiable, Hashable, Sendable {
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

nonisolated struct PlannerSelectedDaySectionData: Hashable, Sendable {
    let title: String
    let taskCount: Int
    let items: [PlannerSelectedDayItemViewData]

    var isEmpty: Bool { items.isEmpty }
}

nonisolated struct PlannerMonthSnapshot: Hashable, Sendable {
    let monthAnchor: Date
    let weekdaySymbols: [String]
    let days: [PlannerMonthDaySnapshot]

    func viewDays(
        selectedDay: Date,
        calendar: Calendar = .current
    ) -> [PlannerMonthDayViewData] {
        let normalizedSelectedDay = calendar.startOfDay(for: selectedDay)

        return days.map { day in
            day.viewData(isSelected: calendar.isDate(day.date, inSameDayAs: normalizedSelectedDay))
        }
    }

    static let empty = PlannerMonthSnapshot(
        monthAnchor: Calendar.current.startOfMonth(for: .now),
        weekdaySymbols: [],
        days: []
    )
}

typealias PlannerSelectedDaySnapshot = PlannerSelectedDaySectionData

nonisolated struct PlannerScreenSnapshot: Hashable, Sendable {
    let month: PlannerMonthSnapshot
    let selectedDay: PlannerSelectedDaySnapshot

    static let empty = PlannerScreenSnapshot(
        month: .empty,
        selectedDay: .init(
            title: "",
            taskCount: 0,
            items: []
        )
    )
}
