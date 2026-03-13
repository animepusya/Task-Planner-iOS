//
//  WidgetSnapshotBuilder.swift
//  Task Planner
//
//  Created by Руслан Меланин on 13.03.2026.
//

import Foundation
import SwiftData

@MainActor
enum WidgetSnapshotBuilder {
    static func build(tasks: [TaskEntity], weekStartsOnMonday: Bool, referenceDate: Date = .now) -> PlannerWidgetSnapshot {
        let calendar = TaskOccurrence.calendar(weekStartsOnMonday: weekStartsOnMonday)
        let start = calendar.startOfDay(for: referenceDate)

        let days: [PlannerWidgetDaySnapshot] = (0..<30).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            let dayKey = calendar.startOfDay(for: date)

            let occurrences = TaskDaySegment
                .occurrences(for: dayKey, from: tasks, weekStartsOnMonday: weekStartsOnMonday)
                .sorted { lhs, rhs in
                    let lhsCompleted = lhs.task.isCompleted(on: dayKey, calendar: calendar)
                    let rhsCompleted = rhs.task.isCompleted(on: dayKey, calendar: calendar)

                    if lhsCompleted != rhsCompleted { return !lhsCompleted }
                    if lhs.displayStart != rhs.displayStart { return lhs.displayStart < rhs.displayStart }
                    return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
                }

            let rows = occurrences.map { occ in
                PlannerWidgetTaskSnapshot(
                    id: widgetTaskId(for: occ, day: dayKey),
                    title: occ.title,
                    subtitle: subtitle(for: occ),
                    timeText: timeText(for: occ),
                    isCompleted: occ.task.isCompleted(on: dayKey, calendar: calendar),
                    colorRaw: occ.color.rawValue
                )
            }

            return PlannerWidgetDaySnapshot(
                dayKey: WidgetDayKey.make(from: dayKey, calendar: calendar),
                date: dayKey,
                titleText: headerFormatter.string(from: dayKey),
                weekdayShortText: weekdayFormatter.string(from: dayKey).uppercased(),
                dayNumberText: dayNumberFormatter.string(from: dayKey),
                tasks: rows
            )
        }

        return PlannerWidgetSnapshot(
            generatedAt: .now,
            days: days
        )
    }

    private static func widgetTaskId(for occurrence: DayOccurrence, day: Date) -> String {
        let taskId = String(describing: occurrence.task.persistentModelID)
        let dayKey = WidgetDayKey.make(from: day)
        return "\(taskId)-\(dayKey)"
    }

    private static func subtitle(for occurrence: DayOccurrence) -> String {
        if let notes = occurrence.notes?.trimmingCharacters(in: .whitespacesAndNewlines),
           !notes.isEmpty {
            return notes
        }
        return occurrence.categoryTitle ?? CategorySystem.uncategorizedTitle
    }

    private static func timeText(for occurrence: DayOccurrence) -> String {
        if occurrence.isAllDaySegment {
            return "All day"
        }

        let start = occurrence.displayStart.formatted(date: .omitted, time: .shortened)
        let end = occurrence.displayEnd.formatted(date: .omitted, time: .shortened)
        return "\(start) – \(end)"
    }

    private static let headerFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = .current
        f.setLocalizedDateFormatFromTemplate("d MMMM")
        return f
    }()

    private static let weekdayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = .current
        f.setLocalizedDateFormatFromTemplate("EEE")
        return f
    }()

    private static let dayNumberFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = .current
        f.setLocalizedDateFormatFromTemplate("d")
        return f
    }()
}
