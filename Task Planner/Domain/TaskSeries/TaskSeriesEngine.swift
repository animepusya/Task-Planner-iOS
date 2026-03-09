//
//  TaskSeriesEngine.swift
//  Task Planner
//
//  Created by Руслан Меланин on 06.03.2026.
//

import Foundation

// MARK: - Single source of truth for effective series state

enum TaskSeriesEngine {

    static func ensureBaseSegmentIfNeeded(for task: TaskEntity, calendar: Calendar = .current) {
        guard task.repeatRule != .none else { return }
        if task.seriesSegments.isEmpty {
            let baseStart = calendar.startOfDay(for: task.dayDate)
            let seg = TaskSeriesSegment(
                id: UUID(),
                startDayKey: DayKey.format(baseStart, calendar: calendar),
                endDayKey: nil,
                template: templateFromTask(task, dayStart: baseStart, calendar: calendar)
            )
            task.seriesSegments = [seg]
        }
    }

    static func template(for task: TaskEntity, startDay: Date, calendar: Calendar = .current) -> TaskSeriesTemplate? {
        let start = calendar.startOfDay(for: startDay)
        let key = DayKey.format(start, calendar: calendar)

        if let ov = task.seriesOverrides.first(where: { $0.dayKey == key }) {
            if ov.isDeleted { return nil }
            if let t = ov.template { return t }
        }

        let segs = task.seriesSegments.sorted { $0.startDay < $1.startDay }
        if let seg = segs.last(where: { s in
            let sStart = calendar.startOfDay(for: s.startDay)
            guard start >= sStart else { return false }
            if let end = s.endDay {
                let sEnd = calendar.startOfDay(for: end)
                return start <= sEnd
            }
            return true
        }) {
            return seg.template
        }

        return templateFromTask(task, dayStart: calendar.startOfDay(for: task.dayDate), calendar: calendar)
    }

    static func isBeyondSeriesEnd(_ task: TaskEntity, day: Date, calendar: Calendar = .current) -> Bool {
        guard let end = task.seriesEndDay else { return false }
        let d = calendar.startOfDay(for: day)
        let e = calendar.startOfDay(for: end)
        return d > e
    }

    static func occursStartOn(_ task: TaskEntity, on date: Date, weekStartsOnMonday: Bool) -> Bool {
        let cal = TaskOccurrence.calendar(weekStartsOnMonday: weekStartsOnMonday)
        let targetDay = cal.startOfDay(for: date)

        if isBeyondSeriesEnd(task, day: targetDay, calendar: cal) { return false }

        if task.repeatRule == .none && task.seriesSegments.isEmpty && task.seriesOverrides.isEmpty {
            let baseDay = cal.startOfDay(for: task.dayDate)
            return cal.isDate(targetDay, inSameDayAs: baseDay)
        }

        guard let tpl = template(for: task, startDay: targetDay, calendar: cal) else { return false }

        let rule = tpl.repeatRule
        if rule == .none {
            let anchor = activeSegmentStartDay(for: task, day: targetDay, calendar: cal) ?? cal.startOfDay(for: task.dayDate)
            return cal.isDate(targetDay, inSameDayAs: anchor)
        }

        guard let anchor = activeSegmentStartDay(for: task, day: targetDay, calendar: cal) else {
            return TaskOccurrence.occursStartOnBase(
                rule: rule,
                intervalDays: tpl.repeatIntervalDays,
                baseDay: cal.startOfDay(for: task.dayDate),
                targetDay: targetDay,
                calendar: cal,
                weekStartsOnMonday: weekStartsOnMonday
            )
        }

        return TaskOccurrence.occursStartOnBase(
            rule: rule,
            intervalDays: tpl.repeatIntervalDays,
            baseDay: anchor,
            targetDay: targetDay,
            calendar: cal,
            weekStartsOnMonday: weekStartsOnMonday
        )
    }

    static func occurrenceStartDayOverlapping(task: TaskEntity, day: Date, weekStartsOnMonday: Bool) -> Date? {
        let cal = TaskOccurrence.calendar(weekStartsOnMonday: weekStartsOnMonday)
        let dayStart = cal.startOfDay(for: day)
        guard let occ = TaskDayOverlap.occurrenceInterval(task: task, dayStart: dayStart, weekStartsOnMonday: weekStartsOnMonday) else {
            return nil
        }
        return cal.startOfDay(for: occ.occurrenceStart)
    }

    static func nextOccurrenceStartDay(
        for task: TaskEntity,
        after day: Date,
        weekStartsOnMonday: Bool,
        searchLimitDays: Int = 3660
    ) -> Date? {
        let cal = TaskOccurrence.calendar(weekStartsOnMonday: weekStartsOnMonday)
        var cursor = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: day)) ?? cal.startOfDay(for: day).addingTimeInterval(86400)

        for _ in 0..<searchLimitDays {
            let candidate = cal.startOfDay(for: cursor)
            if occursStartOn(task, on: candidate, weekStartsOnMonday: weekStartsOnMonday) {
                return candidate
            }
            cursor = cal.date(byAdding: .day, value: 1, to: candidate) ?? candidate.addingTimeInterval(86400)
        }

        return nil
    }

    // MARK: - Internals

    private static func activeSegmentStartDay(for task: TaskEntity, day: Date, calendar: Calendar) -> Date? {
        let d = calendar.startOfDay(for: day)
        let segs = task.seriesSegments.sorted { $0.startDay < $1.startDay }
        guard let seg = segs.last(where: { s in
            let sStart = calendar.startOfDay(for: s.startDay)
            guard d >= sStart else { return false }
            if let end = s.endDay {
                let sEnd = calendar.startOfDay(for: end)
                return d <= sEnd
            }
            return true
        }) else { return nil }

        return calendar.startOfDay(for: seg.startDay)
    }

    static func templateFromTask(_ task: TaskEntity, dayStart: Date, calendar: Calendar) -> TaskSeriesTemplate {
        let startMinutes = TimeMinutes.minutes(from: task.startTime, calendar: calendar)
        let (endOffset, endMinutes) = TimeMinutes.endOffsetAndMinutes(start: task.startTime, end: task.endTime, calendar: calendar)

        return TaskSeriesTemplate(
            title: task.title,
            notes: task.notes,
            isAllDay: task.isAllDay,
            startMinutes: startMinutes,
            endMinutes: endMinutes,
            endDayOffset: endOffset,
            repeatRuleRaw: task.repeatRuleRaw,
            repeatIntervalDays: task.repeatIntervalDays,
            colorRaw: task.colorRaw,
            categoryTitle: task.categoryTitle,
            photoThumbData: task.photoThumbData,
            reminderEnabled: task.reminderEnabled,
            reminderOffsetMinutes: task.reminderOffsetMinutes,
            reminderAllDayTimeMinutes: task.reminderAllDayTimeMinutes
        )
    }
}

// MARK: - Time minutes helpers

enum TimeMinutes {
    static func minutes(from time: Date, calendar: Calendar) -> Int {
        let c = calendar.dateComponents([.hour, .minute], from: time)
        return max(0, (c.hour ?? 0) * 60 + (c.minute ?? 0))
    }

    static func endOffsetAndMinutes(start: Date, end: Date, calendar: Calendar) -> (Int, Int) {
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        let offset = max(0, calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0)
        let endMin = minutes(from: end, calendar: calendar)
        return (offset, endMin)
    }

    static func date(on day: Date, minutes: Int, calendar: Calendar) -> Date {
        let d = calendar.startOfDay(for: day)
        let h = max(0, minutes) / 60
        let m = max(0, minutes) % 60
        return calendar.date(bySettingHour: h, minute: m, second: 0, of: d) ?? d
    }
}
