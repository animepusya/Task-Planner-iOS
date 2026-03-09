//
//  Minutes+TimeOfDay.swift
//  Task Planner
//
//  Created by Руслан Меланин on 03.03.2026.
//

import Foundation

enum TimeOfDayMinutes {
    static func clamp(_ minutes: Int) -> Int {
        max(0, min(24 * 60 - 1, minutes))
    }

    static func format(_ minutes: Int) -> String {
        let m = clamp(minutes)
        let h = m / 60
        let mm = m % 60
        return String(format: "%02d:%02d", h, mm)
    }

    static func date(on day: Date, minutes: Int, calendar: Calendar = .current) -> Date {
        let dayStart = calendar.startOfDay(for: day)
        let m = clamp(minutes)
        let h = m / 60
        let mm = m % 60
        return calendar.date(bySettingHour: h, minute: mm, second: 0, of: dayStart) ?? dayStart
    }

    static func minutes(from date: Date, calendar: Calendar = .current) -> Int {
        let comps = calendar.dateComponents([.hour, .minute], from: date)
        let h = comps.hour ?? 0
        let m = comps.minute ?? 0
        return clamp(h * 60 + m)
    }
}
