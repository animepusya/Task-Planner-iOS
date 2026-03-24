//
//  PlannerVisibleRangeBuilder.swift
//  Task Planner
//
//  Created by Codex on 21.03.2026.
//

import Foundation

struct PlannerVisibleRange {
    let gridItems: [DayItem]
    let visibleDays: [Date]
}

enum PlannerVisibleRangeBuilder {
    static func build(
        monthAnchor: Date,
        weekStartsOnMonday: Bool,
        calendar: Calendar = .current
    ) -> PlannerVisibleRange? {
        let gridItems = CalendarGridBuilder.makeMonthGrid(
            monthAnchor: monthAnchor,
            weekStartsOnMonday: weekStartsOnMonday,
            calendar: calendar
        )

        guard !gridItems.isEmpty else { return nil }

        return PlannerVisibleRange(
            gridItems: gridItems,
            visibleDays: gridItems.map(\.date)
        )
    }
}
