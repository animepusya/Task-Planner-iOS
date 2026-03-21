//
//  PlannerScreenSnapshot.swift
//  Task Planner
//
//  Created by Руслан Меланин on 16.03.2026.
//

import Foundation
import SwiftUI

struct PlannerMonthDaySnapshot: Identifiable, Hashable {
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

struct PlannerMonthSnapshot: Hashable {
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

struct PlannerScreenSnapshot: Hashable {
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
