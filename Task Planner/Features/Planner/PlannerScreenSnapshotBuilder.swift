//
//  PlannerScreenSnapshotBuilder.swift
//  Task Planner
//
//  Created by Руслан Меланин on 16.03.2026.
//

import Foundation
import SwiftData
import SwiftUI

struct PlannerDayContent {
    let taskRows: [PlannerTaskRowData]
    let mergedItems: [PlannerSelectedDayItemViewData]
    let indicatorColors: [TaskColor]

    static let empty = PlannerDayContent(
        taskRows: [],
        mergedItems: [],
        indicatorColors: []
    )
}

struct PlannerMonthBuildOutput {
    let monthSnapshot: PlannerMonthSnapshot
    let dayContentByDay: [Date: PlannerDayContent]
}

struct PlannerScreenSnapshotBuilder {
    func buildMonth(
        tasks: [TaskEntity],
        monthAnchor: Date,
        weekStartsOnMonday: Bool,
        externalEventsByDay: [Date: [ExternalCalendarEvent]],
        isOverlayEnabled: Bool,
        sortDoneOverride: [PersistentIdentifier: Bool]
    ) -> PlannerMonthBuildOutput {
        let calendar = TaskOccurrence.calendar(weekStartsOnMonday: weekStartsOnMonday)
        guard let visibleRange = PlannerVisibleRangeBuilder.build(
            monthAnchor: monthAnchor,
            weekStartsOnMonday: weekStartsOnMonday,
            calendar: calendar
        ) else {
            return PlannerMonthBuildOutput(monthSnapshot: .empty, dayContentByDay: [:])
        }

        let occurrencesByDay = TaskDaySegment.occurrencesByDay(
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
        tasks: [TaskEntity],
        weekStartsOnMonday: Bool,
        externalEventsByDay: [Date: [ExternalCalendarEvent]],
        isOverlayEnabled: Bool,
        sortDoneOverride: [PersistentIdentifier: Bool]
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
        tasks: [TaskEntity],
        weekStartsOnMonday: Bool,
        externalEventsByDay: [Date: [ExternalCalendarEvent]],
        isOverlayEnabled: Bool,
        sortDoneOverride: [PersistentIdentifier: Bool]
    ) -> PlannerDayContent {
        let taskOccurrences = TaskDaySegment.occurrencesByDay(
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
        taskOccurrences: [DayOccurrence],
        externalEventsByDay: [Date: [ExternalCalendarEvent]],
        isOverlayEnabled: Bool,
        sortDoneOverride: [PersistentIdentifier: Bool]
    ) -> PlannerDayContent {
        let sortedTaskRows: [PlannerTaskRowData] = taskOccurrences
            .sorted { lhs, rhs in
                let lhsId = lhs.task.persistentModelID
                let rhsId = rhs.task.persistentModelID

                let lhsCompletedForSort = sortDoneOverride[lhsId] ?? lhs.task.isCompleted(on: day)
                let rhsCompletedForSort = sortDoneOverride[rhsId] ?? rhs.task.isCompleted(on: day)

                if lhsCompletedForSort != rhsCompletedForSort { return !lhsCompletedForSort }
                if lhs.displayStart != rhs.displayStart { return lhs.displayStart < rhs.displayStart }

                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            .map { occurrence in
                PlannerTaskRowData(
                    occurrence: occurrence,
                    modelCompleted: occurrence.task.isCompleted(on: day)
                )
            }

        let importedRows: [PlannerImportedEventRowData] = {
            guard isOverlayEnabled else { return [] }
            let events = externalEventsByDay[day] ?? []
            return events.map {
                PlannerImportedEventRowData(
                    event: $0,
                    mappedColor: TaskColor.closest(to: $0.calendarColor)
                )
            }
        }()

        let mergedItems = mergeItems(
            taskRows: sortedTaskRows,
            importedRows: importedRows,
            dayKey: day,
            sortDoneOverride: sortDoneOverride
        )

        let indicatorColors = mergedItems.compactMap { item -> TaskColor? in
            switch item {
            case .task(let row):
                let taskId = row.occurrence.task.persistentModelID
                let completedForSort = sortDoneOverride[taskId] ?? row.occurrence.task.isCompleted(on: day)
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
        dayKey: Date,
        sortDoneOverride: [PersistentIdentifier: Bool]
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
                let id = row.occurrence.task.persistentModelID
                lhsCompleted = sortDoneOverride[id] ?? row.occurrence.task.isCompleted(on: dayKey)
                lhsStart = row.occurrence.displayStart
                lhsTitle = row.occurrence.title
                lhsColorIndex = row.occurrence.color.sortIndex

            case .imported(let row):
                lhsCompleted = false
                lhsStart = row.event.startDate
                lhsTitle = row.event.title
                lhsColorIndex = row.mappedColor.sortIndex
            }

            switch rhs {
            case .task(let row):
                let id = row.occurrence.task.persistentModelID
                rhsCompleted = sortDoneOverride[id] ?? row.occurrence.task.isCompleted(on: dayKey)
                rhsStart = row.occurrence.displayStart
                rhsTitle = row.occurrence.title
                rhsColorIndex = row.occurrence.color.sortIndex

            case .imported(let row):
                rhsCompleted = false
                rhsStart = row.event.startDate
                rhsTitle = row.event.title
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
