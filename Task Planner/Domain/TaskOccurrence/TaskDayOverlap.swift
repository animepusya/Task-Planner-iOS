//
//  TaskDayOverlap.swift
//  Task Planner
//
//  Created by Руслан Меланин on 12.02.2026.
//

import Foundation

enum TaskDayOverlap {
    static let maxOccurrenceLookbackDays = 14


    struct OccurrenceInterval {
        let start: Date
        let end: Date
        let occurrenceStart: Date
        let occurrenceStartDay: Date
    }

    static func minutesOnDay(
        task: TaskEntity,
        day: Date,
        weekStartsOnMonday: Bool
    ) -> Int {
        let cal = TaskOccurrence.calendar(weekStartsOnMonday: weekStartsOnMonday)
        let dayStart = cal.startOfDay(for: day)
        let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(86400)

        guard let occ = occurrenceInterval(task: task, dayStart: dayStart, weekStartsOnMonday: weekStartsOnMonday) else {
            return 0
        }

        let overlapStart = max(occ.start, dayStart)
        let overlapEnd = min(occ.end, dayEnd)

        guard overlapEnd > overlapStart else { return 0 }

        let minutes = Int((overlapEnd.timeIntervalSince(overlapStart) / 60.0).rounded(.toNearestOrAwayFromZero))
        return max(0, minutes)
    }

    static func affectsDay(
        task: TaskEntity,
        day: Date,
        weekStartsOnMonday: Bool
    ) -> Bool {
        minutesOnDay(task: task, day: day, weekStartsOnMonday: weekStartsOnMonday) > 0
    }

    static func effectiveStartOnDay(
        task: TaskEntity,
        day: Date,
        weekStartsOnMonday: Bool
    ) -> Date? {
        let cal = TaskOccurrence.calendar(weekStartsOnMonday: weekStartsOnMonday)
        let dayStart = cal.startOfDay(for: day)

        guard let occ = occurrenceInterval(task: task, dayStart: dayStart, weekStartsOnMonday: weekStartsOnMonday) else {
            return nil
        }

        return max(occ.start, dayStart)
    }

    static func occurrenceInterval(
        task: TaskEntity,
        dayStart: Date,
        weekStartsOnMonday: Bool
    ) -> OccurrenceInterval? {
        occurrenceOverlapping(task: task, dayStart: dayStart, weekStartsOnMonday: weekStartsOnMonday)
    }

    static func startsWithinDay(
        task: TaskEntity,
        dayStart: Date,
        weekStartsOnMonday: Bool
    ) -> Bool {
        let cal = TaskOccurrence.calendar(weekStartsOnMonday: weekStartsOnMonday)
        let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(86400)

        guard let occ = occurrenceInterval(task: task, dayStart: dayStart, weekStartsOnMonday: weekStartsOnMonday) else { return false }
        return occ.start >= dayStart && occ.start < dayEnd
    }

    static func endsWithinDay(
        task: TaskEntity,
        dayStart: Date,
        weekStartsOnMonday: Bool
    ) -> Bool {
        let cal = TaskOccurrence.calendar(weekStartsOnMonday: weekStartsOnMonday)
        let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(86400)

        guard let occ = occurrenceInterval(task: task, dayStart: dayStart, weekStartsOnMonday: weekStartsOnMonday) else { return false }
        return occ.end > dayStart && occ.end <= dayEnd
    }

    // MARK: - Core overlap (series-aware)

    private static func occurrenceOverlapping(
        task: TaskEntity,
        dayStart: Date,
        weekStartsOnMonday: Bool
    ) -> OccurrenceInterval? {
        let cal = TaskOccurrence.calendar(weekStartsOnMonday: weekStartsOnMonday)
        let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(86400)

        TaskSeriesEngine.ensureBaseSegmentIfNeeded(for: task, calendar: cal)

        let maxBackDays = maxOccurrenceLookbackDays

        for back in 0...maxBackDays {
            guard let candidateStartDay = cal.date(byAdding: .day, value: -back, to: dayStart) else { continue }
            let candidateSOD = cal.startOfDay(for: candidateStartDay)

            guard TaskOccurrence.occursStartOn(task, on: candidateSOD, weekStartsOnMonday: weekStartsOnMonday) else { continue }

            guard let tpl = TaskSeriesEngine.template(for: task, startDay: candidateSOD, calendar: cal) else { continue }

            let occStart = TimeMinutes.date(on: candidateSOD, minutes: tpl.startMinutes, calendar: cal)
            let occEnd = occStart.addingTimeInterval(tpl.durationSeconds)

            if overlaps(aStart: occStart, aEnd: occEnd, bStart: dayStart, bEnd: dayEnd) {
                return OccurrenceInterval(
                    start: occStart,
                    end: occEnd,
                    occurrenceStart: occStart,
                    occurrenceStartDay: candidateSOD
                )
            }
        }

        return nil
    }

    private static func overlaps(aStart: Date, aEnd: Date, bStart: Date, bEnd: Date) -> Bool {
        return aEnd > bStart && aStart < bEnd
    }
}
