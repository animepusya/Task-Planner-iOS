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

    static func occurs(_ task: TaskEntity, on date: Date, weekStartsOnMonday: Bool) -> Bool {
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
}
