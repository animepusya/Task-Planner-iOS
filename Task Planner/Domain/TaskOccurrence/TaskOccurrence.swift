//
//  TaskOccurrence.swift
//  Task Planner
//
//  Created by Руслан Меланин on 11.02.2026.
//

import Foundation

enum TaskOccurrence {

    nonisolated static func calendar(weekStartsOnMonday: Bool) -> Calendar {
        var cal = Calendar.current
        cal.firstWeekday = weekStartsOnMonday ? 2 : 1
        return cal
    }

    nonisolated static func combine(day: Date, time: Date, calendar: Calendar) -> Date {
        let dayStart = calendar.startOfDay(for: day)
        let comps = calendar.dateComponents([.hour, .minute], from: time)
        let hour = comps.hour ?? 0
        let minute = comps.minute ?? 0
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: dayStart) ?? dayStart
    }

    nonisolated static func occursStartOnBase(
        rule: RepeatRule,
        intervalDays: Int?,
        baseDay: Date,
        targetDay: Date,
        calendar cal: Calendar,
        weekStartsOnMonday: Bool
    ) -> Bool {
        guard targetDay >= baseDay else { return false }

        switch rule {
        case .none:
            return cal.isDate(targetDay, inSameDayAs: baseDay)

        case .daily:
            return true

        case .weekdays:
            if cal.isDate(targetDay, inSameDayAs: baseDay) { return true }
            return Workweek.isWeekday(targetDay, calendar: cal, weekStartsOnMonday: weekStartsOnMonday)

        case .weekends:
            if cal.isDate(targetDay, inSameDayAs: baseDay) { return true }
            return Workweek.isWeekend(targetDay, calendar: cal, weekStartsOnMonday: weekStartsOnMonday)

        case .weekly:
            return cal.component(.weekday, from: targetDay) == cal.component(.weekday, from: baseDay)

        case .monthly:
            return cal.component(.day, from: targetDay) == cal.component(.day, from: baseDay)

        case .everyNDays:
            let n = max(1, intervalDays ?? 1)
            let days = cal.dateComponents([.day], from: baseDay, to: targetDay).day ?? 0
            return days % n == 0
        }
    }

    static func occursStartOn(_ task: TaskEntity, on date: Date, weekStartsOnMonday: Bool) -> Bool {
        TaskSeriesEngine.occursStartOn(task, on: date, weekStartsOnMonday: weekStartsOnMonday)
    }

    static func occurs(_ task: TaskEntity, on date: Date, weekStartsOnMonday: Bool) -> Bool {
        TaskDayOverlap.affectsDay(task: task, day: date, weekStartsOnMonday: weekStartsOnMonday)
    }
}
