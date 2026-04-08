//
//  PlannerScreenSnapshotBuilder.swift
//  Task Planner
//
//  Created by Руслан Меланин on 16.03.2026.
//

import Foundation

nonisolated struct PlannerDayContent: Sendable {
    let taskRows: [PlannerTaskRowData]
    let mergedItems: [PlannerSelectedDayItemViewData]
    let indicatorColors: [TaskColor]

    static let empty = PlannerDayContent(
        taskRows: [],
        mergedItems: [],
        indicatorColors: []
    )
}

nonisolated struct PlannerMonthBuildOutput: Sendable {
    let monthSnapshot: PlannerMonthSnapshot
    let dayContentByDay: [Date: PlannerDayContent]
}

nonisolated struct PlannerScreenSnapshotBuilder {
    func buildMonth(
        tasks: [PlannerTaskSource],
        monthAnchor: Date,
        weekStartsOnMonday: Bool,
        externalEventsByDay: [Date: [PlannerExternalEventSource]],
        isOverlayEnabled: Bool,
        sortDoneOverride: [String: Bool]
    ) -> PlannerMonthBuildOutput {
        let calendar = TaskOccurrence.calendar(weekStartsOnMonday: weekStartsOnMonday)
        guard let visibleRange = PlannerVisibleRangeBuilder.build(
            monthAnchor: monthAnchor,
            weekStartsOnMonday: weekStartsOnMonday,
            calendar: calendar
        ) else {
            return PlannerMonthBuildOutput(monthSnapshot: .empty, dayContentByDay: [:])
        }

        let occurrencesByDay = TaskDaySegment.plannerOccurrencesByDay(
            for: visibleRange.visibleDays,
            from: tasks,
            weekStartsOnMonday: weekStartsOnMonday
        )

        var dayContentByDay: [Date: PlannerDayContent] = [:]
        dayContentByDay.reserveCapacity(visibleRange.visibleDays.count)

        for day in visibleRange.visibleDays {
            let dayKey = calendar.startOfDay(for: day)
            dayContentByDay[dayKey] = buildDayContent(
                day: dayKey,
                taskOccurrences: occurrencesByDay[dayKey] ?? [],
                externalEventsByDay: externalEventsByDay,
                isOverlayEnabled: isOverlayEnabled,
                sortDoneOverride: sortDoneOverride
            )
        }

        let monthSnapshot = PlannerMonthSnapshot(
            monthAnchor: calendar.startOfMonth(for: monthAnchor),
            weekdaySymbols: CalendarGridBuilder.weekdaySymbols(
                weekStartsOnMonday: weekStartsOnMonday,
                calendar: calendar
            ),
            days: visibleRange.gridItems.map { item in
                PlannerMonthDaySnapshot(
                    id: item.id,
                    date: item.date,
                    dayNumber: item.dayNumber,
                    isInDisplayedMonth: item.isInDisplayedMonth,
                    indicatorColors: dayContentByDay[calendar.startOfDay(for: item.date)]?.indicatorColors ?? []
                )
            }
        )

        return PlannerMonthBuildOutput(
            monthSnapshot: monthSnapshot,
            dayContentByDay: dayContentByDay
        )
    }

    func buildSelectedDaySnapshot(
        selectedDay: Date,
        monthBuild: PlannerMonthBuildOutput?,
        tasks: [PlannerTaskSource],
        weekStartsOnMonday: Bool,
        externalEventsByDay: [Date: [PlannerExternalEventSource]],
        isOverlayEnabled: Bool,
        sortDoneOverride: [String: Bool]
    ) -> PlannerSelectedDaySnapshot {
        let calendar = TaskOccurrence.calendar(weekStartsOnMonday: weekStartsOnMonday)
        let normalizedSelectedDay = calendar.startOfDay(for: selectedDay)

        let dayContent = monthBuild?.dayContentByDay[normalizedSelectedDay] ?? buildSingleDayContent(
            day: normalizedSelectedDay,
            tasks: tasks,
            weekStartsOnMonday: weekStartsOnMonday,
            externalEventsByDay: externalEventsByDay,
            isOverlayEnabled: isOverlayEnabled,
            sortDoneOverride: sortDoneOverride
        )

        return PlannerSelectedDaySnapshot(
            title: normalizedSelectedDay.dayTitle(using: calendar),
            taskCount: dayContent.taskRows.count,
            items: dayContent.mergedItems
        )
    }

    private func buildSingleDayContent(
        day: Date,
        tasks: [PlannerTaskSource],
        weekStartsOnMonday: Bool,
        externalEventsByDay: [Date: [PlannerExternalEventSource]],
        isOverlayEnabled: Bool,
        sortDoneOverride: [String: Bool]
    ) -> PlannerDayContent {
        let taskOccurrences = TaskDaySegment.plannerOccurrencesByDay(
            for: [day],
            from: tasks,
            weekStartsOnMonday: weekStartsOnMonday
        )[day] ?? []

        return buildDayContent(
            day: day,
            taskOccurrences: taskOccurrences,
            externalEventsByDay: externalEventsByDay,
            isOverlayEnabled: isOverlayEnabled,
            sortDoneOverride: sortDoneOverride
        )
    }

    private func buildDayContent(
        day: Date,
        taskOccurrences: [PlannerTaskOccurrence],
        externalEventsByDay: [Date: [PlannerExternalEventSource]],
        isOverlayEnabled: Bool,
        sortDoneOverride: [String: Bool]
    ) -> PlannerDayContent {
        let sortedTaskRows: [PlannerTaskRowData] = taskOccurrences
            .sorted { lhs, rhs in
                let lhsCompletedForSort = sortDoneOverride[lhs.taskKey] ?? lhs.modelCompleted
                let rhsCompletedForSort = sortDoneOverride[rhs.taskKey] ?? rhs.modelCompleted

                if lhsCompletedForSort != rhsCompletedForSort { return !lhsCompletedForSort }
                if lhs.displayStart != rhs.displayStart { return lhs.displayStart < rhs.displayStart }
                if lhs.color.sortIndex != rhs.color.sortIndex { return lhs.color.sortIndex < rhs.color.sortIndex }

                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            .map { occurrence in
                PlannerTaskRowData(
                    occurrence: occurrence,
                    modelCompleted: occurrence.modelCompleted
                )
            }

        let importedRows: [PlannerImportedEventRowData] = {
            guard isOverlayEnabled else { return [] }
            return (externalEventsByDay[day] ?? []).map(PlannerImportedEventRowData.init(source:))
        }()

        let mergedItems = mergeItems(
            taskRows: sortedTaskRows,
            importedRows: importedRows,
            sortDoneOverride: sortDoneOverride
        )

        let indicatorColors = mergedItems.compactMap { item -> TaskColor? in
            switch item {
            case .task(let row):
                let completedForSort = sortDoneOverride[row.occurrence.taskKey] ?? row.modelCompleted
                return completedForSort ? nil : row.occurrence.color

            case .imported(let row):
                return row.mappedColor
            }
        }

        return PlannerDayContent(
            taskRows: sortedTaskRows,
            mergedItems: mergedItems,
            indicatorColors: Array(indicatorColors.prefix(3))
        )
    }

    private func mergeItems(
        taskRows: [PlannerTaskRowData],
        importedRows: [PlannerImportedEventRowData],
        sortDoneOverride: [String: Bool]
    ) -> [PlannerSelectedDayItemViewData] {
        var items: [PlannerSelectedDayItemViewData] =
            taskRows.map { .task($0) } +
            importedRows.map { .imported($0) }

        items.sort { lhs, rhs in
            let lhsCompleted: Bool
            let rhsCompleted: Bool

            let lhsStart: Date
            let rhsStart: Date

            let lhsTitle: String
            let rhsTitle: String

            let lhsColorIndex: Int
            let rhsColorIndex: Int

            switch lhs {
            case .task(let row):
                lhsCompleted = sortDoneOverride[row.occurrence.taskKey] ?? row.modelCompleted
                lhsStart = row.occurrence.displayStart
                lhsTitle = row.occurrence.title
                lhsColorIndex = row.occurrence.color.sortIndex

            case .imported(let row):
                lhsCompleted = false
                lhsStart = row.startDate
                lhsTitle = row.title
                lhsColorIndex = row.mappedColor.sortIndex
            }

            switch rhs {
            case .task(let row):
                rhsCompleted = sortDoneOverride[row.occurrence.taskKey] ?? row.modelCompleted
                rhsStart = row.occurrence.displayStart
                rhsTitle = row.occurrence.title
                rhsColorIndex = row.occurrence.color.sortIndex

            case .imported(let row):
                rhsCompleted = false
                rhsStart = row.startDate
                rhsTitle = row.title
                rhsColorIndex = row.mappedColor.sortIndex
            }

            if lhsCompleted != rhsCompleted { return !lhsCompleted }
            if lhsStart != rhsStart { return lhsStart < rhsStart }
            if lhsColorIndex != rhsColorIndex { return lhsColorIndex < rhsColorIndex }

            return lhsTitle.localizedCaseInsensitiveCompare(rhsTitle) == .orderedAscending
        }

        return items
    }
}
