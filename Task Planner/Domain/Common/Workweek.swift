//
//  Workweek.swift
//  Task Planner
//
//  Created by Руслан Меланин on 18.02.2026.
//

import Foundation

nonisolated enum Workweek {

    private static func weekendWeekdaySet(weekStartsOnMonday: Bool) -> Set<Int> {
        if weekStartsOnMonday {
            return [7, 1]
        } else {
            return [6, 7]
        }
    }

    static func isWeekend(_ date: Date, calendar: Calendar, weekStartsOnMonday: Bool) -> Bool {
        let wd = calendar.component(.weekday, from: date)
        return weekendWeekdaySet(weekStartsOnMonday: weekStartsOnMonday).contains(wd)
    }

    static func isWeekday(_ date: Date, calendar: Calendar, weekStartsOnMonday: Bool) -> Bool {
        !isWeekend(date, calendar: calendar, weekStartsOnMonday: weekStartsOnMonday)
    }

    static func nextMatchingStartDay(
        after fromDay: Date,
        rule: RepeatRule,
        calendar: Calendar,
        weekStartsOnMonday: Bool
    ) -> Date? {
        guard rule == .weekdays || rule == .weekends else { return nil }

        var day = calendar.startOfDay(for: fromDay)
        for _ in 0..<7 {
            day = calendar.date(byAdding: .day, value: 1, to: day) ?? day
            let ok: Bool
            switch rule {
            case .weekdays:
                ok = isWeekday(day, calendar: calendar, weekStartsOnMonday: weekStartsOnMonday)
            case .weekends:
                ok = isWeekend(day, calendar: calendar, weekStartsOnMonday: weekStartsOnMonday)
            default:
                ok = false
            }
            if ok { return day }
        }
        return nil
    }
}
