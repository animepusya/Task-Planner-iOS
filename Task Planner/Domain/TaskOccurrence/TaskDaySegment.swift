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

enum TaskDaySegment {
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
