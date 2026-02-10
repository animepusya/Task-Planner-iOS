//
//  CalendarGridBuilder.swift
//  Task Planner
//
//  Created by Руслан Меланин on 09.02.2026.
//

import Foundation

struct DayItem: Identifiable, Hashable {
    let id: String
    let date: Date
    let dayNumber: Int
    let isInDisplayedMonth: Bool
}

enum CalendarGridBuilder {
    static func makeMonthGrid(
        monthAnchor: Date,
        weekStartsOnMonday: Bool,
        calendar: Calendar = .current
    ) -> [DayItem] {
        var cal = calendar
        cal.firstWeekday = weekStartsOnMonday ? 2 : 1 // 2 = Monday, 1 = Sunday

        guard let monthInterval = cal.dateInterval(of: .month, for: monthAnchor) else { return [] }

        let monthStart = monthInterval.start
        let monthEnd = monthInterval.end

        // Первый день сетки = начало недели, в которую попадает 1-е число месяца
        let startWeekInterval = cal.dateInterval(of: .weekOfYear, for: monthStart)
        let gridStart = startWeekInterval?.start ?? monthStart

        // Последний день сетки = конец недели, в которую попадает последний день месяца
        let lastDayOfMonth = cal.date(byAdding: .day, value: -1, to: monthEnd) ?? monthStart
        let endWeekInterval = cal.dateInterval(of: .weekOfYear, for: lastDayOfMonth)
        let gridEndExclusive = endWeekInterval?.end ?? monthEnd

        var days: [DayItem] = []
        var cursor = gridStart

        while cursor < gridEndExclusive {
            let comps = cal.dateComponents([.day], from: cursor)
            let day = comps.day ?? 1
            let inMonth = (cursor >= monthStart) && (cursor < monthEnd)

            let id = "\(Int(cursor.timeIntervalSince1970))"
            days.append(DayItem(id: id, date: cursor, dayNumber: day, isInDisplayedMonth: inMonth))

            cursor = cal.date(byAdding: .day, value: 1, to: cursor) ?? cursor.addingTimeInterval(86400)
        }

        // Обычно 5-6 рядов. Если получилось 4 (редко) — добьем до 5.
        while days.count < 35, let last = days.last {
            let next = cal.date(byAdding: .day, value: 1, to: last.date) ?? last.date.addingTimeInterval(86400)
            let comps = cal.dateComponents([.day], from: next)
            let day = comps.day ?? 1
            let inMonth = (next >= monthStart) && (next < monthEnd)
            days.append(DayItem(id: "\(Int(next.timeIntervalSince1970))", date: next, dayNumber: day, isInDisplayedMonth: inMonth))
        }

        return days
    }

    static func weekdaySymbols(weekStartsOnMonday: Bool, calendar: Calendar = .current) -> [String] {
        var cal = calendar
        cal.firstWeekday = weekStartsOnMonday ? 2 : 1

        // calendar.shortWeekdaySymbols обычно начинается с Sunday, поэтому сдвигаем вручную
        let symbols = cal.shortWeekdaySymbols // e.g. ["Sun","Mon",...]
        let shift = cal.firstWeekday - 1
        return Array(symbols[shift...] + symbols[..<shift])
    }
}
