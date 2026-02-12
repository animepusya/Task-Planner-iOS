//
//  TaskOccurrence.swift
//  Task Planner
//
//  Created by Руслан Меланин on 11.02.2026.
//

import Foundation

enum TaskOccurrence {

    static func calendar(weekStartsOnMonday: Bool) -> Calendar {
        var cal = Calendar.current
        cal.firstWeekday = weekStartsOnMonday ? 2 : 1
        return cal
    }

    /// Combines day (startOfDay) + hour/minute from `time`
    static func combine(day: Date, time: Date, calendar: Calendar) -> Date {
        let dayStart = calendar.startOfDay(for: day)
        let comps = calendar.dateComponents([.hour, .minute], from: time)
        let hour = comps.hour ?? 0
        let minute = comps.minute ?? 0
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: dayStart) ?? dayStart
    }

    /// ✅ Old behavior, but renamed: determines whether an occurrence STARTS on this day.
    static func occursStartOn(_ task: TaskEntity, on date: Date, weekStartsOnMonday: Bool) -> Bool {
        let cal = calendar(weekStartsOnMonday: weekStartsOnMonday)

        let targetDay = cal.startOfDay(for: date)
        let baseDay = cal.startOfDay(for: task.dayDate)

        guard targetDay >= baseDay else { return false }

        switch task.repeatRule {
        case .none:
            return cal.isDate(targetDay, inSameDayAs: baseDay)

        case .daily:
            return true

        case .weekly:
            return cal.component(.weekday, from: targetDay) == cal.component(.weekday, from: baseDay)

        case .monthly:
            return cal.component(.day, from: targetDay) == cal.component(.day, from: baseDay)

        case .everyNDays:
            let n = max(1, task.repeatIntervalDays ?? 1)
            let days = cal.dateComponents([.day], from: baseDay, to: targetDay).day ?? 0
            return days % n == 0
        }
    }

    /// ✅ New: does the task affect the day at all (range-aware)
    static func occurs(_ task: TaskEntity, on date: Date, weekStartsOnMonday: Bool) -> Bool {
        TaskDayOverlap.affectsDay(task: task, day: date, weekStartsOnMonday: weekStartsOnMonday)
    }
}
