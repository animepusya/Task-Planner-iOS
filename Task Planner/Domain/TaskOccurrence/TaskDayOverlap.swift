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
        let normalizedDayStart = cal.startOfDay(for: dayStart)
        let dayEnd = cal.date(byAdding: .day, value: 1, to: normalizedDayStart) ?? normalizedDayStart.addingTimeInterval(86400)

        TaskSeriesEngine.ensureBaseSegmentIfNeeded(for: task, calendar: cal)

        if let overrideInterval = overlappingExplicitOverride(
            task: task,
            dayStart: normalizedDayStart,
            dayEnd: dayEnd,
            calendar: cal
        ) {
            return overrideInterval
        }

        if task.repeatRule == .none && task.seriesSegments.isEmpty {
            let baseDay = cal.startOfDay(for: task.dayDate)
            guard TaskOccurrence.occursStartOn(task, on: baseDay, weekStartsOnMonday: weekStartsOnMonday) else {
                return nil
            }

            let template = TaskSeriesEngine.template(for: task, startDay: baseDay, calendar: cal)
                ?? TaskSeriesEngine.templateFromTask(task, dayStart: baseDay, calendar: cal)

            return overlappingInterval(
                occurrenceStartDay: baseDay,
                template: template,
                dayStart: normalizedDayStart,
                dayEnd: dayEnd,
                calendar: cal
            )
        }

        let segments = task.seriesSegments.sorted { $0.startDay < $1.startDay }

        for segment in segments.reversed() {
            let segmentStart = cal.startOfDay(for: segment.startDay)
            guard segmentStart <= normalizedDayStart else { continue }

            let effectiveEnd = effectiveSegmentEnd(for: segment, task: task, calendar: cal)
            guard effectiveEnd >= segmentStart else { continue }

            let lookbackStart = cal.date(
                byAdding: .day,
                value: -segment.template.overlapLookbackDays,
                to: normalizedDayStart
            ) ?? normalizedDayStart.addingTimeInterval(TimeInterval(-segment.template.overlapLookbackDays * 86_400))

            let searchUpperBound = min(effectiveEnd, normalizedDayStart)
            guard searchUpperBound >= max(segmentStart, lookbackStart) else { continue }

            guard let candidateStartDay = latestStartDay(
                for: segment.template,
                anchorDay: segmentStart,
                onOrBefore: searchUpperBound,
                calendar: cal,
                weekStartsOnMonday: weekStartsOnMonday
            ) else {
                continue
            }

            guard candidateStartDay >= lookbackStart else { continue }
            guard TaskOccurrence.occursStartOn(task, on: candidateStartDay, weekStartsOnMonday: weekStartsOnMonday) else {
                continue
            }

            guard let template = TaskSeriesEngine.template(for: task, startDay: candidateStartDay, calendar: cal) else {
                continue
            }

            if let interval = overlappingInterval(
                occurrenceStartDay: candidateStartDay,
                template: template,
                dayStart: normalizedDayStart,
                dayEnd: dayEnd,
                calendar: cal
            ) {
                return interval
            }
        }

        return nil
    }

    private static func overlappingExplicitOverride(
        task: TaskEntity,
        dayStart: Date,
        dayEnd: Date,
        calendar: Calendar
    ) -> OccurrenceInterval? {
        for override in task.seriesOverrides.reversed() {
            let overrideDay = calendar.startOfDay(for: DayKey.parse(override.dayKey, calendar: calendar))
            guard overrideDay <= dayStart else { continue }
            guard override.isDeleted == false, let template = override.template else { continue }

            if let interval = overlappingInterval(
                occurrenceStartDay: overrideDay,
                template: template,
                dayStart: dayStart,
                dayEnd: dayEnd,
                calendar: calendar
            ) {
                return interval
            }
        }

        return nil
    }

    private static func overlappingInterval(
        occurrenceStartDay: Date,
        template: TaskSeriesTemplate,
        dayStart: Date,
        dayEnd: Date,
        calendar: Calendar
    ) -> OccurrenceInterval? {
        let normalizedStartDay = calendar.startOfDay(for: occurrenceStartDay)
        let interval = template.occurrenceInterval(startDay: normalizedStartDay, calendar: calendar)

        guard overlaps(aStart: interval.start, aEnd: interval.end, bStart: dayStart, bEnd: dayEnd) else {
            return nil
        }

        return OccurrenceInterval(
            start: interval.start,
            end: interval.end,
            occurrenceStart: interval.start,
            occurrenceStartDay: normalizedStartDay
        )
    }

    private static func effectiveSegmentEnd(
        for segment: TaskSeriesSegment,
        task: TaskEntity,
        calendar: Calendar
    ) -> Date {
        var candidates: [Date] = []

        if let segmentEnd = segment.endDay {
            candidates.append(calendar.startOfDay(for: segmentEnd))
        }

        if let seriesEndDay = task.seriesEndDay {
            candidates.append(calendar.startOfDay(for: seriesEndDay))
        }

        return candidates.min() ?? .distantFuture
    }

    private static func latestStartDay(
        for template: TaskSeriesTemplate,
        anchorDay: Date,
        onOrBefore targetDay: Date,
        calendar: Calendar,
        weekStartsOnMonday: Bool
    ) -> Date? {
        let normalizedAnchor = calendar.startOfDay(for: anchorDay)
        let normalizedTarget = calendar.startOfDay(for: targetDay)
        guard normalizedTarget >= normalizedAnchor else { return nil }

        switch template.repeatRule {
        case .none:
            return normalizedAnchor

        case .daily:
            return normalizedTarget

        case .weekdays, .weekends:
            if normalizedTarget == normalizedAnchor { return normalizedAnchor }

            var cursor = normalizedTarget
            for _ in 0..<7 {
                if cursor == normalizedAnchor { return normalizedAnchor }

                let matchesRule: Bool = {
                    switch template.repeatRule {
                    case .weekdays:
                        return Workweek.isWeekday(cursor, calendar: calendar, weekStartsOnMonday: weekStartsOnMonday)
                    case .weekends:
                        return Workweek.isWeekend(cursor, calendar: calendar, weekStartsOnMonday: weekStartsOnMonday)
                    default:
                        return false
                    }
                }()

                if cursor > normalizedAnchor && matchesRule {
                    return cursor
                }

                guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor), previous < cursor else {
                    break
                }
                cursor = previous
            }

            return normalizedAnchor

        case .weekly:
            let daysFromAnchor = calendar.dateComponents([.day], from: normalizedAnchor, to: normalizedTarget).day ?? 0
            let offset = daysFromAnchor - (daysFromAnchor % 7)
            return calendar.date(byAdding: .day, value: offset, to: normalizedAnchor)

        case .monthly:
            let anchorDayNumber = calendar.component(.day, from: normalizedAnchor)
            let minimumMonth = calendar.startOfMonth(for: normalizedAnchor)
            var monthCursor = calendar.startOfMonth(for: normalizedTarget)

            while monthCursor >= minimumMonth {
                if let candidate = monthlyStartDay(
                    dayNumber: anchorDayNumber,
                    monthAnchor: monthCursor,
                    calendar: calendar
                ), candidate <= normalizedTarget, candidate >= normalizedAnchor {
                    return candidate
                }

                guard let previousMonth = calendar.date(byAdding: .month, value: -1, to: monthCursor),
                      previousMonth < monthCursor else {
                    break
                }
                monthCursor = previousMonth
            }

            return normalizedAnchor

        case .everyNDays:
            let interval = max(1, template.repeatIntervalDays ?? 1)
            let daysFromAnchor = calendar.dateComponents([.day], from: normalizedAnchor, to: normalizedTarget).day ?? 0
            let offset = daysFromAnchor - (daysFromAnchor % interval)
            return calendar.date(byAdding: .day, value: offset, to: normalizedAnchor)
        }
    }

    private static func monthlyStartDay(
        dayNumber: Int,
        monthAnchor: Date,
        calendar: Calendar
    ) -> Date? {
        let components = calendar.dateComponents([.year, .month], from: monthAnchor)
        var candidateComponents = DateComponents()
        candidateComponents.calendar = calendar
        candidateComponents.timeZone = calendar.timeZone
        candidateComponents.year = components.year
        candidateComponents.month = components.month
        candidateComponents.day = dayNumber

        return calendar.date(from: candidateComponents)
    }

    private static func overlaps(aStart: Date, aEnd: Date, bStart: Date, bEnd: Date) -> Bool {
        return aEnd > bStart && aStart < bEnd
    }
}
