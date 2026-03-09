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
        let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(86400)

        TaskSeriesEngine.ensureBaseSegmentIfNeeded(for: task, calendar: cal)

        guard let interval = TaskDayOverlap.occurrenceInterval(task: task, dayStart: dayStart, weekStartsOnMonday: weekStartsOnMonday) else {
            return nil
        }

        guard let tpl = TaskSeriesEngine.template(for: task, startDay: interval.occurrenceStartDay, calendar: cal) else {
            return nil
        }

        let effectiveTitle = tpl.title
        let effectiveNotes = tpl.notes
        let effectiveCategory = tpl.categoryTitle
        let effectiveColor = TaskColor(rawValue: tpl.colorRaw) ?? task.color
        let effectivePhoto = tpl.photoThumbData

        if tpl.isAllDay {
            let startsInDay = TaskDayOverlap.startsWithinDay(task: task, dayStart: dayStart, weekStartsOnMonday: weekStartsOnMonday)
            let endsInDay = TaskDayOverlap.endsWithinDay(task: task, dayStart: dayStart, weekStartsOnMonday: weekStartsOnMonday)

            return DayOccurrence(
                task: task,
                dayStart: dayStart,
                occurrenceStartDay: interval.occurrenceStartDay,
                title: effectiveTitle,
                notes: effectiveNotes,
                categoryTitle: effectiveCategory,
                color: effectiveColor,
                photoThumbData: effectivePhoto,
                displayStart: dayStart,
                displayEnd: dayEnd,
                isStartDay: startsInDay,
                isEndDay: endsInDay,
                isAllDaySegment: true,
                badge: nil
            )
        }

        let overlapStart = max(interval.start, dayStart)
        let overlapEnd = min(interval.end, dayEnd)
        guard overlapEnd > overlapStart else { return nil }

        let startsInThisDay = (interval.start >= dayStart && interval.start < dayEnd)
        let endsInThisDay = (interval.end > dayStart && interval.end <= dayEnd)

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
            occurrenceStartDay: interval.occurrenceStartDay,
            title: effectiveTitle,
            notes: effectiveNotes,
            categoryTitle: effectiveCategory,
            color: effectiveColor,
            photoThumbData: effectivePhoto,
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
