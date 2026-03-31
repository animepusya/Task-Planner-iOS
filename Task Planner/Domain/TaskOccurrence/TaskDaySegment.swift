//
//  TaskDaySegment.swift
//  Task Planner
//
//  Created by Руслан Меланин on 24.02.2026.
//

import Foundation
import SwiftData

struct DayOccurrence: Identifiable, Hashable {
    enum Badge: String, Hashable {
        case continues = "Continues"
        case ongoing = "Ongoing"
        case ends = "Ends"

        var localizedTitle: String {
            switch self {
            case .continues:
                return String(localized: "Continues")
            case .ongoing:
                return String(localized: "Ongoing")
            case .ends:
                return String(localized: "Ends")
            }
        }
    }

    let id: String

    let task: TaskEntity
    let dayStart: Date

    let occurrenceStartDay: Date

    let title: String
    let notes: String?
    let categoryTitle: String?
    let color: TaskColor
    let photoThumbData: Data?

    let displayStart: Date
    let displayEnd: Date

    let isAllDayOccurrence: Bool
    let isStartDay: Bool
    let isEndDay: Bool
    let isAllDaySegment: Bool

    let badge: Badge?

    init(
        task: TaskEntity,
        dayStart: Date,
        occurrenceStartDay: Date,
        title: String,
        notes: String?,
        categoryTitle: String?,
        color: TaskColor,
        photoThumbData: Data?,
        displayStart: Date,
        displayEnd: Date,
        isAllDayOccurrence: Bool,
        isStartDay: Bool,
        isEndDay: Bool,
        isAllDaySegment: Bool,
        badge: Badge?
    ) {
        self.task = task
        self.dayStart = dayStart
        self.occurrenceStartDay = occurrenceStartDay
        self.title = title
        self.notes = notes
        self.categoryTitle = categoryTitle
        self.color = color
        self.photoThumbData = photoThumbData
        self.displayStart = displayStart
        self.displayEnd = displayEnd
        self.isAllDayOccurrence = isAllDayOccurrence
        self.isStartDay = isStartDay
        self.isEndDay = isEndDay
        self.isAllDaySegment = isAllDaySegment
        self.badge = badge

        self.id = "\(String(describing: task.persistentModelID))_\(dayStart.timeIntervalSince1970)"
    }
}

struct PlannerTaskOccurrence: Identifiable, Hashable, Sendable {
    enum Badge: String, Hashable, Sendable {
        case continues = "Continues"
        case ongoing = "Ongoing"
        case ends = "Ends"

        var localizedTitle: String {
            switch self {
            case .continues:
                return String(localized: "Continues")
            case .ongoing:
                return String(localized: "Ongoing")
            case .ends:
                return String(localized: "Ends")
            }
        }
    }

    let id: String
    let taskKey: String
    let dayStart: Date
    let occurrenceStartDay: Date
    let title: String
    let notes: String?
    let categoryTitle: String?
    let color: TaskColor
    let photoThumbData: Data?
    let displayStart: Date
    let displayEnd: Date
    let isAllDayOccurrence: Bool
    let isStartDay: Bool
    let isEndDay: Bool
    let isAllDaySegment: Bool
    let badge: Badge?
    let isRepeatingTask: Bool
    let modelCompleted: Bool
}

enum TaskDaySegment {
    static func plannerOccurrencesByDay(
        for visibleDays: [Date],
        from tasks: [PlannerTaskSource],
        weekStartsOnMonday: Bool
    ) -> [Date: [PlannerTaskOccurrence]] {
        let calendar = TaskOccurrence.calendar(weekStartsOnMonday: weekStartsOnMonday)
        let normalizedVisibleDays = visibleDays
            .map { calendar.startOfDay(for: $0) }
            .sorted()

        guard
            let visibleStart = normalizedVisibleDays.first,
            let visibleEnd = normalizedVisibleDays.last
        else {
            return [:]
        }

        let visibleDaySet = Set(normalizedVisibleDays)

        var occurrencesByDay: [Date: [PlannerTaskOccurrence]] = [:]
        occurrencesByDay.reserveCapacity(normalizedVisibleDays.count)

        for day in normalizedVisibleDays {
            occurrencesByDay[day] = []
        }

        let candidateTasks = tasks.filter {
            $0.hasRelevantStarts(between: visibleStart, and: visibleEnd, calendar: calendar)
        }

        for task in candidateTasks {
            appendPlannerOccurrences(
                for: task,
                visibleStart: visibleStart,
                visibleEnd: visibleEnd,
                visibleDaySet: visibleDaySet,
                calendar: calendar,
                weekStartsOnMonday: weekStartsOnMonday,
                into: &occurrencesByDay
            )
        }

        return occurrencesByDay
    }

    static func occurrence(
        for task: TaskEntity,
        on day: Date,
        weekStartsOnMonday: Bool
    ) -> DayOccurrence? {
        let cal = TaskOccurrence.calendar(weekStartsOnMonday: weekStartsOnMonday)
        let dayStart = cal.startOfDay(for: day)

        TaskSeriesEngine.ensureBaseSegmentIfNeeded(for: task, calendar: cal)

        guard let interval = TaskDayOverlap.occurrenceInterval(task: task, dayStart: dayStart, weekStartsOnMonday: weekStartsOnMonday) else {
            return nil
        }

        guard let tpl = TaskSeriesEngine.template(for: task, startDay: interval.occurrenceStartDay, calendar: cal) else {
            return nil
        }

        return makeOccurrence(
            task: task,
            dayStart: dayStart,
            occurrenceStartDay: interval.occurrenceStartDay,
            template: tpl,
            occurrenceStart: interval.start,
            occurrenceEnd: interval.end,
            calendar: cal
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

    static func occurrencesByDay(
        for visibleDays: [Date],
        from tasks: [TaskEntity],
        weekStartsOnMonday: Bool
    ) -> [Date: [DayOccurrence]] {
        let calendar = TaskOccurrence.calendar(weekStartsOnMonday: weekStartsOnMonday)
        let normalizedVisibleDays = visibleDays
            .map { calendar.startOfDay(for: $0) }
            .sorted()

        guard
            let visibleStart = normalizedVisibleDays.first,
            let visibleEnd = normalizedVisibleDays.last
        else {
            return [:]
        }

        let visibleDaySet = Set(normalizedVisibleDays)
        let searchStart = calendar.date(
            byAdding: .day,
            value: -TaskDayOverlap.maxOccurrenceLookbackDays,
            to: visibleStart
        ) ?? visibleStart.addingTimeInterval(TimeInterval(-TaskDayOverlap.maxOccurrenceLookbackDays * 86_400))

        var occurrencesByDay: [Date: [DayOccurrence]] = [:]
        occurrencesByDay.reserveCapacity(normalizedVisibleDays.count)

        for day in normalizedVisibleDays {
            occurrencesByDay[day] = []
        }

        let searchDays = enumerateDays(from: searchStart, to: visibleEnd, calendar: calendar)
        let candidateTasks = tasks.filter { task in
            let baseDay = calendar.startOfDay(for: task.dayDate)
            guard baseDay <= visibleEnd else { return false }

            if let seriesEndDay = task.seriesEndDay {
                return calendar.startOfDay(for: seriesEndDay) >= searchStart
            }

            return true
        }

        for task in candidateTasks {
            TaskSeriesEngine.ensureBaseSegmentIfNeeded(for: task, calendar: calendar)

            for occurrenceStartDay in searchDays {
                guard TaskOccurrence.occursStartOn(
                    task,
                    on: occurrenceStartDay,
                    weekStartsOnMonday: weekStartsOnMonday
                ) else {
                    continue
                }

                guard let template = TaskSeriesEngine.template(
                    for: task,
                    startDay: occurrenceStartDay,
                    calendar: calendar
                ) else {
                    continue
                }

                appendOccurrences(
                    for: task,
                    occurrenceStartDay: occurrenceStartDay,
                    template: template,
                    visibleStart: visibleStart,
                    visibleEnd: visibleEnd,
                    visibleDaySet: visibleDaySet,
                    calendar: calendar,
                    into: &occurrencesByDay
                )
            }
        }

        return occurrencesByDay
    }

    private static func appendPlannerOccurrences(
        for task: PlannerTaskSource,
        visibleStart: Date,
        visibleEnd: Date,
        visibleDaySet: Set<Date>,
        calendar: Calendar,
        weekStartsOnMonday: Bool,
        into result: inout [Date: [PlannerTaskOccurrence]]
    ) {
        let overrideDaysInRange = task.overrideByDay.keys
            .filter { $0 <= visibleEnd }
            .sorted()

        var baseSuppressedDays = Set<Date>()
        baseSuppressedDays.reserveCapacity(overrideDaysInRange.count)

        for day in overrideDaysInRange {
            guard let override = task.overrideByDay[day] else { continue }

            if override.isDeleted || override.template != nil {
                baseSuppressedDays.insert(day)
            }

            guard override.isDeleted == false, let template = override.template else { continue }
            guard plannerOccurrenceIntersectsVisibleRange(
                occurrenceStartDay: day,
                template: template,
                visibleStart: visibleStart,
                visibleEnd: visibleEnd,
                calendar: calendar
            ) else {
                continue
            }

            appendPlannerOccurrence(
                for: task,
                occurrenceStartDay: day,
                template: template,
                visibleStart: visibleStart,
                visibleEnd: visibleEnd,
                visibleDaySet: visibleDaySet,
                calendar: calendar,
                into: &result
            )
        }

        if task.seriesSegments.isEmpty {
            guard task.ownerRepeatRule == .none else { return }
            guard baseSuppressedDays.contains(task.baseDay) == false else { return }
            guard plannerOccurrenceIntersectsVisibleRange(
                occurrenceStartDay: task.baseDay,
                template: task.baseTemplate,
                visibleStart: visibleStart,
                visibleEnd: visibleEnd,
                calendar: calendar
            ) else {
                return
            }

            appendPlannerOccurrence(
                for: task,
                occurrenceStartDay: task.baseDay,
                template: task.baseTemplate,
                visibleStart: visibleStart,
                visibleEnd: visibleEnd,
                visibleDaySet: visibleDaySet,
                calendar: calendar,
                into: &result
            )
            return
        }

        for segment in task.seriesSegments {
            let segmentStart = calendar.startOfDay(for: segment.startDay)
            guard segmentStart <= visibleEnd else { break }

            let segmentEnd = effectivePlannerSegmentEnd(
                for: segment,
                task: task,
                searchEnd: visibleEnd,
                calendar: calendar
            )
            guard let segmentEnd, segmentEnd >= segmentStart else { continue }

            let lookbackStart = calendar.date(
                byAdding: .day,
                value: -segment.template.overlapLookbackDays,
                to: visibleStart
            ) ?? visibleStart.addingTimeInterval(TimeInterval(-segment.template.overlapLookbackDays * 86_400))

            let rangeStart = max(segmentStart, lookbackStart)
            let rangeEnd = min(segmentEnd, visibleEnd)
            guard rangeStart <= rangeEnd else { continue }

            appendPlannerStartDays(
                for: task,
                template: segment.template,
                anchorDay: segmentStart,
                rangeStart: rangeStart,
                rangeEnd: rangeEnd,
                suppressedDays: baseSuppressedDays,
                calendar: calendar,
                weekStartsOnMonday: weekStartsOnMonday,
                visibleStart: visibleStart,
                visibleEnd: visibleEnd,
                visibleDaySet: visibleDaySet,
                into: &result
            )
        }
    }

    private static func effectivePlannerSegmentEnd(
        for segment: TaskSeriesSegment,
        task: PlannerTaskSource,
        searchEnd: Date,
        calendar: Calendar
    ) -> Date? {
        var candidates: [Date] = [searchEnd]

        if let segmentEnd = segment.endDay {
            candidates.append(calendar.startOfDay(for: segmentEnd))
        }

        if let seriesEndDay = task.seriesEndDay {
            candidates.append(calendar.startOfDay(for: seriesEndDay))
        }

        return candidates.min()
    }

    private static func plannerOccurrenceIntersectsVisibleRange(
        occurrenceStartDay: Date,
        template: TaskSeriesTemplate,
        visibleStart: Date,
        visibleEnd: Date,
        calendar: Calendar
    ) -> Bool {
        let interval = template.occurrenceInterval(startDay: occurrenceStartDay, calendar: calendar)
        let dayAfterVisibleEnd = calendar.date(byAdding: .day, value: 1, to: visibleEnd)
            ?? visibleEnd.addingTimeInterval(86_400)

        return interval.end > visibleStart && interval.start < dayAfterVisibleEnd
    }

    private static func appendPlannerStartDays(
        for task: PlannerTaskSource,
        template: TaskSeriesTemplate,
        anchorDay: Date,
        rangeStart: Date,
        rangeEnd: Date,
        suppressedDays: Set<Date>,
        calendar: Calendar,
        weekStartsOnMonday: Bool,
        visibleStart: Date,
        visibleEnd: Date,
        visibleDaySet: Set<Date>,
        into result: inout [Date: [PlannerTaskOccurrence]]
    ) {
        func emit(_ day: Date) {
            let normalizedDay = calendar.startOfDay(for: day)
            guard normalizedDay >= rangeStart, normalizedDay <= rangeEnd else { return }
            guard suppressedDays.contains(normalizedDay) == false else { return }

            appendPlannerOccurrence(
                for: task,
                occurrenceStartDay: normalizedDay,
                template: template,
                visibleStart: visibleStart,
                visibleEnd: visibleEnd,
                visibleDaySet: visibleDaySet,
                calendar: calendar,
                into: &result
            )
        }

        switch template.repeatRule {
        case .none:
            emit(anchorDay)

        case .daily:
            for day in enumerateDays(from: rangeStart, to: rangeEnd, calendar: calendar) {
                emit(day)
            }

        case .weekdays, .weekends:
            for day in enumerateDays(from: rangeStart, to: rangeEnd, calendar: calendar) {
                if calendar.isDate(day, inSameDayAs: anchorDay) {
                    emit(day)
                    continue
                }

                let matchesRule: Bool = {
                    switch template.repeatRule {
                    case .weekdays:
                        return Workweek.isWeekday(day, calendar: calendar, weekStartsOnMonday: weekStartsOnMonday)
                    case .weekends:
                        return Workweek.isWeekend(day, calendar: calendar, weekStartsOnMonday: weekStartsOnMonday)
                    default:
                        return false
                    }
                }()

                if matchesRule {
                    emit(day)
                }
            }

        case .weekly:
            let dayDelta = max(0, calendar.dateComponents([.day], from: anchorDay, to: rangeStart).day ?? 0)
            let remainder = dayDelta % 7
            let offset = remainder == 0 ? 0 : (7 - remainder)
            let first = calendar.date(byAdding: .day, value: offset, to: rangeStart) ?? rangeStart

            for day in strideDays(from: first, through: rangeEnd, step: 7, calendar: calendar) {
                emit(day)
            }

        case .monthly:
            let anchorDayNumber = calendar.component(.day, from: anchorDay)
            var monthCursor = calendar.startOfMonth(for: rangeStart)
            let endMonth = calendar.startOfMonth(for: rangeEnd)

            while monthCursor <= endMonth {
                let components = calendar.dateComponents([.year, .month], from: monthCursor)
                var candidateComponents = DateComponents()
                candidateComponents.calendar = calendar
                candidateComponents.timeZone = calendar.timeZone
                candidateComponents.year = components.year
                candidateComponents.month = components.month
                candidateComponents.day = anchorDayNumber

                if let candidate = calendar.date(from: candidateComponents) {
                    emit(candidate)
                }

                guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthCursor),
                      nextMonth > monthCursor else {
                    break
                }
                monthCursor = nextMonth
            }

        case .everyNDays:
            let interval = max(1, template.repeatIntervalDays ?? 1)
            let daysFromAnchor = max(0, calendar.dateComponents([.day], from: anchorDay, to: rangeStart).day ?? 0)
            let firstStep = daysFromAnchor == 0 ? 0 : ((daysFromAnchor + interval - 1) / interval) * interval
            let first = calendar.date(byAdding: .day, value: firstStep, to: anchorDay) ?? anchorDay

            for day in strideDays(from: first, through: rangeEnd, step: interval, calendar: calendar) {
                emit(day)
            }
        }
    }

    private static func appendPlannerOccurrence(
        for task: PlannerTaskSource,
        occurrenceStartDay: Date,
        template: TaskSeriesTemplate,
        visibleStart: Date,
        visibleEnd: Date,
        visibleDaySet: Set<Date>,
        calendar: Calendar,
        into result: inout [Date: [PlannerTaskOccurrence]]
    ) {
        let occurrenceStart = TimeMinutes.date(
            on: occurrenceStartDay,
            minutes: template.startMinutes,
            calendar: calendar
        )
        let occurrenceEnd = occurrenceStart.addingTimeInterval(template.durationSeconds)
        let dayAfterVisibleEnd = calendar.date(byAdding: .day, value: 1, to: visibleEnd)
            ?? visibleEnd.addingTimeInterval(86_400)

        guard occurrenceEnd > visibleStart else { return }
        guard occurrenceStart < dayAfterVisibleEnd else { return }

        let lastOccurrenceMoment = occurrenceEnd.addingTimeInterval(-1)
        let firstDay = max(visibleStart, calendar.startOfDay(for: occurrenceStart))
        let lastDay = min(visibleEnd, calendar.startOfDay(for: lastOccurrenceMoment))

        guard firstDay <= lastDay else { return }

        for dayStart in enumerateDays(from: firstDay, to: lastDay, calendar: calendar) {
            guard visibleDaySet.contains(dayStart) else { continue }
            guard let occurrence = makePlannerOccurrence(
                task: task,
                dayStart: dayStart,
                occurrenceStartDay: occurrenceStartDay,
                template: template,
                occurrenceStart: occurrenceStart,
                occurrenceEnd: occurrenceEnd,
                calendar: calendar
            ) else {
                continue
            }

            result[dayStart, default: []].append(occurrence)
        }
    }

    private static func makePlannerOccurrence(
        task: PlannerTaskSource,
        dayStart: Date,
        occurrenceStartDay: Date,
        template: TaskSeriesTemplate,
        occurrenceStart: Date,
        occurrenceEnd: Date,
        calendar: Calendar
    ) -> PlannerTaskOccurrence? {
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(86_400)
        let effectiveColor = TaskColor(rawValue: template.colorRaw)
            ?? TaskColor(rawValue: task.baseTemplate.colorRaw)
            ?? .purple
        let modelCompleted = task.isCompleted(on: dayStart, calendar: calendar)

        if template.isAllDay {
            let startsInDay = occurrenceStart >= dayStart && occurrenceStart < dayEnd
            let endsInDay = occurrenceEnd > dayStart && occurrenceEnd <= dayEnd

            return PlannerTaskOccurrence(
                id: "\(task.taskKey)_\(dayStart.timeIntervalSince1970)",
                taskKey: task.taskKey,
                dayStart: dayStart,
                occurrenceStartDay: occurrenceStartDay,
                title: template.title,
                notes: template.notes,
                categoryTitle: template.categoryTitle,
                color: effectiveColor,
                photoThumbData: template.photoThumbData,
                displayStart: dayStart,
                displayEnd: dayEnd,
                isAllDayOccurrence: true,
                isStartDay: startsInDay,
                isEndDay: endsInDay,
                isAllDaySegment: true,
                badge: nil,
                isRepeatingTask: task.isRepeatingTask,
                modelCompleted: modelCompleted
            )
        }

        let overlapStart = max(occurrenceStart, dayStart)
        let overlapEnd = min(occurrenceEnd, dayEnd)
        guard overlapEnd > overlapStart else { return nil }

        let startsInThisDay = occurrenceStart >= dayStart && occurrenceStart < dayEnd
        let endsInThisDay = occurrenceEnd > dayStart && occurrenceEnd <= dayEnd
        let isMiddleDay = !startsInThisDay && !endsInThisDay
        let isFullDay = overlapStart == dayStart && overlapEnd == dayEnd
        let allDaySegment = isMiddleDay && isFullDay

        let badge: PlannerTaskOccurrence.Badge? = {
            if startsInThisDay && !endsInThisDay { return .continues }
            if isMiddleDay { return .ongoing }
            if endsInThisDay && !startsInThisDay { return .ends }
            return nil
        }()

        return PlannerTaskOccurrence(
            id: "\(task.taskKey)_\(dayStart.timeIntervalSince1970)",
            taskKey: task.taskKey,
            dayStart: dayStart,
            occurrenceStartDay: occurrenceStartDay,
            title: template.title,
            notes: template.notes,
            categoryTitle: template.categoryTitle,
            color: effectiveColor,
            photoThumbData: template.photoThumbData,
            displayStart: overlapStart,
            displayEnd: overlapEnd,
            isAllDayOccurrence: false,
            isStartDay: startsInThisDay,
            isEndDay: endsInThisDay,
            isAllDaySegment: allDaySegment,
            badge: badge,
            isRepeatingTask: task.isRepeatingTask,
            modelCompleted: modelCompleted
        )
    }

    private static func strideDays(
        from start: Date,
        through end: Date,
        step: Int,
        calendar: Calendar
    ) -> [Date] {
        guard start <= end else { return [] }

        var days: [Date] = []
        var cursor = calendar.startOfDay(for: start)

        while cursor <= end {
            days.append(cursor)
            cursor = calendar.date(byAdding: .day, value: step, to: cursor) ?? cursor.addingTimeInterval(TimeInterval(step * 86_400))
        }

        return days
    }

    private static func appendOccurrences(
        for task: TaskEntity,
        occurrenceStartDay: Date,
        template: TaskSeriesTemplate,
        visibleStart: Date,
        visibleEnd: Date,
        visibleDaySet: Set<Date>,
        calendar: Calendar,
        into result: inout [Date: [DayOccurrence]]
    ) {
        let occurrenceStart = TimeMinutes.date(
            on: occurrenceStartDay,
            minutes: template.startMinutes,
            calendar: calendar
        )
        let occurrenceEnd = occurrenceStart.addingTimeInterval(template.durationSeconds)
        let dayAfterVisibleEnd = calendar.date(byAdding: .day, value: 1, to: visibleEnd)
            ?? visibleEnd.addingTimeInterval(86_400)

        guard occurrenceEnd > visibleStart else { return }
        guard occurrenceStart < dayAfterVisibleEnd else { return }

        let lastOccurrenceMoment = occurrenceEnd.addingTimeInterval(-1)
        let firstDay = max(visibleStart, calendar.startOfDay(for: occurrenceStart))
        let lastDay = min(visibleEnd, calendar.startOfDay(for: lastOccurrenceMoment))

        guard firstDay <= lastDay else { return }

        for dayStart in enumerateDays(from: firstDay, to: lastDay, calendar: calendar) {
            guard visibleDaySet.contains(dayStart) else { continue }
            guard let occurrence = makeOccurrence(
                task: task,
                dayStart: dayStart,
                occurrenceStartDay: occurrenceStartDay,
                template: template,
                occurrenceStart: occurrenceStart,
                occurrenceEnd: occurrenceEnd,
                calendar: calendar
            ) else {
                continue
            }

            result[dayStart, default: []].append(occurrence)
        }
    }

    private static func makeOccurrence(
        task: TaskEntity,
        dayStart: Date,
        occurrenceStartDay: Date,
        template: TaskSeriesTemplate,
        occurrenceStart: Date,
        occurrenceEnd: Date,
        calendar: Calendar
    ) -> DayOccurrence? {
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(86_400)
        let effectiveColor = TaskColor(rawValue: template.colorRaw) ?? task.color

        if template.isAllDay {
            let startsInDay = occurrenceStart >= dayStart && occurrenceStart < dayEnd
            let endsInDay = occurrenceEnd > dayStart && occurrenceEnd <= dayEnd

            return DayOccurrence(
                task: task,
                dayStart: dayStart,
                occurrenceStartDay: occurrenceStartDay,
                title: template.title,
                notes: template.notes,
                categoryTitle: template.categoryTitle,
                color: effectiveColor,
                photoThumbData: template.photoThumbData,
                displayStart: dayStart,
                displayEnd: dayEnd,
                isAllDayOccurrence: true,
                isStartDay: startsInDay,
                isEndDay: endsInDay,
                isAllDaySegment: true,
                badge: nil
            )
        }

        let overlapStart = max(occurrenceStart, dayStart)
        let overlapEnd = min(occurrenceEnd, dayEnd)
        guard overlapEnd > overlapStart else { return nil }

        let startsInThisDay = occurrenceStart >= dayStart && occurrenceStart < dayEnd
        let endsInThisDay = occurrenceEnd > dayStart && occurrenceEnd <= dayEnd
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
            occurrenceStartDay: occurrenceStartDay,
            title: template.title,
            notes: template.notes,
            categoryTitle: template.categoryTitle,
            color: effectiveColor,
            photoThumbData: template.photoThumbData,
            displayStart: overlapStart,
            displayEnd: overlapEnd,
            isAllDayOccurrence: false,
            isStartDay: startsInThisDay,
            isEndDay: endsInThisDay,
            isAllDaySegment: allDaySegment,
            badge: badge
        )
    }

    private static func enumerateDays(from start: Date, to end: Date, calendar: Calendar) -> [Date] {
        let normalizedStart = calendar.startOfDay(for: start)
        let normalizedEnd = calendar.startOfDay(for: end)
        guard normalizedStart <= normalizedEnd else { return [] }

        var days: [Date] = []
        days.reserveCapacity((calendar.dateComponents([.day], from: normalizedStart, to: normalizedEnd).day ?? 0) + 1)

        var cursor = normalizedStart
        while cursor <= normalizedEnd {
            days.append(cursor)
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? cursor.addingTimeInterval(86_400)
        }

        return days
    }
}
