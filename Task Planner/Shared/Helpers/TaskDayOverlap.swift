//
//  TaskDayOverlap.swift
//  Task Planner
//
//  Created by Руслан Меланин on 12.02.2026.
//

import Foundation

/// Source of truth for:
/// - does a task affect a given day?
/// - how many minutes fall into a given day?
/// - effective start time inside the day (for sorting)
enum TaskDayOverlap {

    struct OccurrenceInterval {
        let start: Date
        let end: Date
    }

    /// Returns minutes of the task that fall within [dayStart; dayStart+1day)
    static func minutesOnDay(
        task: TaskEntity,
        day: Date,
        weekStartsOnMonday: Bool
    ) -> Int {
        let cal = TaskOccurrence.calendar(weekStartsOnMonday: weekStartsOnMonday)
        let dayStart = cal.startOfDay(for: day)
        let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(86400)

        guard let occ = occurrenceOverlapping(task: task, dayStart: dayStart, weekStartsOnMonday: weekStartsOnMonday) else {
            return 0
        }

        let overlapStart = max(occ.start, dayStart)
        let overlapEnd = min(occ.end, dayEnd)

        guard overlapEnd > overlapStart else { return 0 }

        let minutes = Int((overlapEnd.timeIntervalSince(overlapStart) / 60.0).rounded(.toNearestOrAwayFromZero))
        return max(0, minutes)
    }

    /// True if any part of the task overlaps the day.
    static func affectsDay(
        task: TaskEntity,
        day: Date,
        weekStartsOnMonday: Bool
    ) -> Bool {
        minutesOnDay(task: task, day: day, weekStartsOnMonday: weekStartsOnMonday) > 0
    }

    /// For sorting inside a day: when the task starts within the day (or 00:00 if it started earlier)
    static func effectiveStartOnDay(
        task: TaskEntity,
        day: Date,
        weekStartsOnMonday: Bool
    ) -> Date? {
        let cal = TaskOccurrence.calendar(weekStartsOnMonday: weekStartsOnMonday)
        let dayStart = cal.startOfDay(for: day)

        guard let occ = occurrenceOverlapping(task: task, dayStart: dayStart, weekStartsOnMonday: weekStartsOnMonday) else {
            return nil
        }

        return max(occ.start, dayStart)
    }

    // MARK: - Core overlap

    private static func occurrenceOverlapping(
        task: TaskEntity,
        dayStart: Date,
        weekStartsOnMonday: Bool
    ) -> OccurrenceInterval? {
        let cal = TaskOccurrence.calendar(weekStartsOnMonday: weekStartsOnMonday)
        let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(86400)

        let duration = task.endTime.timeIntervalSince(task.startTime)
        guard duration > 0 else { return nil }

        // if no repeats: one real interval
        if task.repeatRule == .none {
            let s = task.startTime
            let e = task.endTime
            if overlaps(aStart: s, aEnd: e, bStart: dayStart, bEnd: dayEnd) {
                return OccurrenceInterval(start: s, end: e)
            }
            return nil
        }

        // repeating: an occurrence might have started today OR within previous days (because it can span > 1 day).
        // thanks to "repeat conflict" prevention, at most one occurrence can overlap a given day.
        let spanDays = max(0, Int(ceil(duration / 86400.0))) // e.g. 9h -> 1, 30h -> 2

        for back in 0...spanDays {
            guard let candidateStartDay = cal.date(byAdding: .day, value: -back, to: dayStart) else { continue }
            let candidateStartDaySOD = cal.startOfDay(for: candidateStartDay)

            if TaskOccurrence.occursStartOn(task, on: candidateStartDaySOD, weekStartsOnMonday: weekStartsOnMonday) {
                let occStart = TaskOccurrence.combine(day: candidateStartDaySOD, time: task.startTime, calendar: cal)
                let occEnd = occStart.addingTimeInterval(duration)

                if overlaps(aStart: occStart, aEnd: occEnd, bStart: dayStart, bEnd: dayEnd) {
                    return OccurrenceInterval(start: occStart, end: occEnd)
                }
            }
        }

        return nil
    }

    private static func overlaps(aStart: Date, aEnd: Date, bStart: Date, bEnd: Date) -> Bool {
        // [aStart, aEnd) intersects [bStart, bEnd)
        return aEnd > bStart && aStart < bEnd
    }
}
