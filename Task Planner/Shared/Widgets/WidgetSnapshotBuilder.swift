//
//  WidgetSnapshotBuilder.swift
//  Task Planner
//
//  Created by Руслан Меланин on 13.03.2026.
//

import Foundation

enum WidgetSnapshotBuilder {
    static func build(
        tasks: [PlannerTaskSource],
        weekStartsOnMonday: Bool,
        referenceDate: Date = .now
    ) -> PlannerWidgetSnapshot {
        let calendar = TaskOccurrence.calendar(weekStartsOnMonday: weekStartsOnMonday)
        let start = calendar.startOfDay(for: referenceDate)
        let visibleDays: [Date] = (0..<30).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: start).map { calendar.startOfDay(for: $0) }
        }
        let occurrencesByDay = TaskDaySegment.plannerOccurrencesByDay(
            for: visibleDays,
            from: tasks,
            weekStartsOnMonday: weekStartsOnMonday
        )

        let days: [PlannerWidgetDaySnapshot] = visibleDays.map { dayKey in
            let occurrences = (occurrencesByDay[dayKey] ?? []).sorted { lhs, rhs in
                    if lhs.modelCompleted != rhs.modelCompleted { return !lhs.modelCompleted }
                    if lhs.displayStart != rhs.displayStart { return lhs.displayStart < rhs.displayStart }
                    return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
                }

            let rows = occurrences.map { occ in
                PlannerWidgetTaskSnapshot(
                    id: occ.id,
                    title: LocalizedDisplayText.taskTitle(occ.title),
                    subtitle: subtitle(for: occ),
                    timeText: timeText(for: occ),
                    isCompleted: occ.modelCompleted,
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

    private static func subtitle(for occurrence: PlannerTaskOccurrence) -> String {
        if let notes = occurrence.notes?.trimmingCharacters(in: .whitespacesAndNewlines),
           !notes.isEmpty {
            return notes
        }
        return CategorySystem.localizedDisplayTitle(for: occurrence.categoryTitle)
    }

    private static func timeText(for occurrence: PlannerTaskOccurrence) -> String {
        if occurrence.isAllDaySegment {
            return String(localized: "All day")
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
