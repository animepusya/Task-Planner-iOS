//
//  TaskDaySegment.swift
//  Task Planner
//
//  Created by Руслан Меланин on 24.02.2026.
//

import Foundation
import SwiftData

// MARK: - DayOccurrence (virtual appearance of a task on a specific day)

struct DayOccurrence: Identifiable, Hashable {
    enum Badge: String, Hashable {
        case continues = "Continues"
        case ongoing = "Ongoing"
        case ends = "Ends"
    }

    let id: String

    let task: TaskEntity
    let dayStart: Date

    let displayStart: Date
    let displayEnd: Date

    let isStartDay: Bool
    let isEndDay: Bool
    let isAllDaySegment: Bool

    let badge: Badge?

    init(
        task: TaskEntity,
        dayStart: Date,
        displayStart: Date,
        displayEnd: Date,
        isStartDay: Bool,
        isEndDay: Bool,
        isAllDaySegment: Bool,
        badge: Badge?
    ) {
        self.task = task
        self.dayStart = dayStart
        self.displayStart = displayStart
        self.displayEnd = displayEnd
        self.isStartDay = isStartDay
        self.isEndDay = isEndDay
        self.isAllDaySegment = isAllDaySegment
        self.badge = badge

        // unique per (task, day)
        self.id = "\(String(describing: task.persistentModelID))_\(dayStart.timeIntervalSince1970)"
    }
}

// MARK: - TaskDaySegment (source of truth)

enum TaskDaySegment {

    /// Builds a day-specific occurrence (virtual segment) for rendering in lists.
    static func occurrence(
        for task: TaskEntity,
        on day: Date,
        weekStartsOnMonday: Bool
    ) -> DayOccurrence? {
        let cal = TaskOccurrence.calendar(weekStartsOnMonday: weekStartsOnMonday)
        let dayStart = cal.startOfDay(for: day)
        let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(86400)

        // All-day tasks keep current behavior (no segments / no badges).
        if task.isAllDay {
            // still show if affects this day
            guard TaskDayOverlap.affectsDay(task: task, day: dayStart, weekStartsOnMonday: weekStartsOnMonday) else { return nil }

            return DayOccurrence(
                task: task,
                dayStart: dayStart,
                displayStart: dayStart,
                displayEnd: dayEnd,
                isStartDay: TaskDayOverlap.startsWithinDay(task: task, dayStart: dayStart, weekStartsOnMonday: weekStartsOnMonday),
                isEndDay: TaskDayOverlap.endsWithinDay(task: task, dayStart: dayStart, weekStartsOnMonday: weekStartsOnMonday),
                isAllDaySegment: true,
                badge: nil
            )
        }

        guard let interval = TaskDayOverlap.occurrenceInterval(task: task, dayStart: dayStart, weekStartsOnMonday: weekStartsOnMonday) else {
            return nil
        }

        let overlapStart = max(interval.start, dayStart)
        let overlapEnd = min(interval.end, dayEnd)

        guard overlapEnd > overlapStart else { return nil }

        let startsInThisDay = (interval.start >= dayStart && interval.start < dayEnd)
        let endsInThisDay = (interval.end > dayStart && interval.end <= dayEnd)

        // Middle day = full day segment and neither start nor end day
        let isMiddleDay = !startsInThisDay && !endsInThisDay
        let isFullDay = overlapStart == dayStart && overlapEnd == dayEnd

        let allDaySegment = isMiddleDay && isFullDay

        let badge: DayOccurrence.Badge? = {
            if startsInThisDay && !endsInThisDay { return .continues }
            if isMiddleDay { return .ongoing }
            if endsInThisDay && !startsInThisDay { return .ends }
            return nil
        }()

        return DayOccurrence(
            task: task,
            dayStart: dayStart,
            displayStart: overlapStart,
            displayEnd: overlapEnd,
            isStartDay: startsInThisDay,
            isEndDay: endsInThisDay,
            isAllDaySegment: allDaySegment,
            badge: badge
        )
    }

    static func occurrences(
        for day: Date,
        from tasks: [TaskEntity],
        weekStartsOnMonday: Bool
    ) -> [DayOccurrence] {
        let cal = TaskOccurrence.calendar(weekStartsOnMonday: weekStartsOnMonday)
        let dayKey = cal.startOfDay(for: day)

        return tasks.compactMap { task in
            occurrence(for: task, on: dayKey, weekStartsOnMonday: weekStartsOnMonday)
        }
    }
}
