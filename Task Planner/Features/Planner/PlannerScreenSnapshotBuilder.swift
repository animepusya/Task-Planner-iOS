//
//  PlannerScreenSnapshotBuilder.swift
//  Task Planner
//
//  Created by Руслан Меланин on 16.03.2026.
//

import Foundation
import SwiftData
import SwiftUI

struct PlannerScreenSnapshotBuilder {

    func build(
        tasks: [TaskEntity],
        selectedDay: Date,
        monthAnchor: Date,
        weekStartsOnMonday: Bool,
        externalEventsByDay: [Date: [ExternalCalendarEvent]],
        isOverlayEnabled: Bool,
        sortDoneOverride: [PersistentIdentifier: Bool]
    ) -> PlannerScreenSnapshot {
        let calendar = TaskOccurrence.calendar(weekStartsOnMonday: weekStartsOnMonday)
        let normalizedSelectedDay = calendar.startOfDay(for: selectedDay)

        let gridItems = CalendarGridBuilder.makeMonthGrid(
            monthAnchor: monthAnchor,
            weekStartsOnMonday: weekStartsOnMonday,
            calendar: calendar
        )

        let visibleDays = Set(gridItems.map(\.date)).union([normalizedSelectedDay])

        var indicatorColorsByDay: [Date: [TaskColor]] = [:]
        indicatorColorsByDay.reserveCapacity(visibleDays.count)

        var selectedDayItems: [PlannerSelectedDayItemViewData] = []
        var selectedDayTaskCount = 0

        for day in visibleDays {
            let dayKey = calendar.startOfDay(for: day)

            let taskOccurrences = TaskDaySegment.occurrences(
                for: dayKey,
                from: tasks,
                weekStartsOnMonday: weekStartsOnMonday
            )

            let sortedTaskRows: [PlannerTaskRowData] = taskOccurrences
                .sorted { lhs, rhs in
                    let lhsId = lhs.task.persistentModelID
                    let rhsId = rhs.task.persistentModelID

                    let lhsCompletedForSort = sortDoneOverride[lhsId] ?? lhs.task.isCompleted(on: dayKey)
                    let rhsCompletedForSort = sortDoneOverride[rhsId] ?? rhs.task.isCompleted(on: dayKey)

                    if lhsCompletedForSort != rhsCompletedForSort { return !lhsCompletedForSort }
                    if lhs.displayStart != rhs.displayStart { return lhs.displayStart < rhs.displayStart }

                    return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
                }
                .map { occurrence in
                    PlannerTaskRowData(
                        occurrence: occurrence,
                        modelCompleted: occurrence.task.isCompleted(on: dayKey)
                    )
                }

            let importedRows: [PlannerImportedEventRowData] = {
                guard isOverlayEnabled else { return [] }
                let events = externalEventsByDay[dayKey] ?? []
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
                dayKey: dayKey,
                sortDoneOverride: sortDoneOverride
            )

            let indicatorColors = mergedItems.compactMap { item -> TaskColor? in
                switch item {
                case .task(let row):
                    let taskId = row.occurrence.task.persistentModelID
                    let completedForSort = sortDoneOverride[taskId] ?? row.occurrence.task.isCompleted(on: dayKey)
                    return completedForSort ? nil : row.occurrence.color

                case .imported(let row):
                    return row.mappedColor
                }
            }

            indicatorColorsByDay[dayKey] = Array(indicatorColors.prefix(3))

            if calendar.isDate(dayKey, inSameDayAs: normalizedSelectedDay) {
                selectedDayItems = mergedItems
                selectedDayTaskCount = sortedTaskRows.count
            }
        }

        let monthDays = gridItems.map { item in
            PlannerMonthDayViewData(
                id: item.id,
                date: item.date,
                dayNumber: item.dayNumber,
                isInDisplayedMonth: item.isInDisplayedMonth,
                isSelected: calendar.isDate(item.date, inSameDayAs: normalizedSelectedDay),
                indicatorColors: indicatorColorsByDay[calendar.startOfDay(for: item.date)] ?? []
            )
        }

        return PlannerScreenSnapshot(
            weekdaySymbols: CalendarGridBuilder.weekdaySymbols(
                weekStartsOnMonday: weekStartsOnMonday,
                calendar: calendar
            ),
            monthDays: monthDays,
            selectedDaySection: PlannerSelectedDaySectionData(
                title: normalizedSelectedDay.dayTitle(using: calendar),
                taskCount: selectedDayTaskCount,
                items: selectedDayItems
            )
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
