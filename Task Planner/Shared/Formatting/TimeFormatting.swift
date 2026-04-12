//
//  TimeFormatting.swift
//  Task Planner
//
//  Created by Руслан Меланин on 10.02.2026.
//

import Foundation

private enum LocalizedTimeFormatter {
    nonisolated static func abbreviatedHoursMinutes(fromMinutes minutes: Int) -> String {
        let totalMinutes = Swift.max(0, minutes)
        let timeInterval = TimeInterval(totalMinutes * 60)

        if let formatted = makeHoursMinutesFormatter().string(from: timeInterval), formatted.isEmpty == false {
            return formatted
        }

        // `.dropAll` returns `nil` for a zero duration, so we fall back to a localized zero-minute string.
        return makeZeroMinutesFormatter().string(from: 0) ?? "0"
    }

    nonisolated private static func makeHoursMinutesFormatter() -> DateComponentsFormatter {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .dropAll
        formatter.calendar = autoupdatingCalendar()
        return formatter
    }

    nonisolated private static func makeZeroMinutesFormatter() -> DateComponentsFormatter {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute]
        formatter.unitsStyle = .abbreviated
        formatter.calendar = autoupdatingCalendar()
        return formatter
    }

    nonisolated private static func autoupdatingCalendar() -> Calendar {
        var calendar = Calendar.autoupdatingCurrent
        calendar.locale = .autoupdatingCurrent
        return calendar
    }
}

extension Int {
    nonisolated func formattedHoursMinutes() -> String {
        LocalizedTimeFormatter.abbreviatedHoursMinutes(fromMinutes: self)
    }

    nonisolated func formattedSignedHoursMinutes() -> String {
        if self == 0 {
            return LocalizedTimeFormatter.abbreviatedHoursMinutes(fromMinutes: 0)
        }

        let prefix = self > 0 ? "+" : "-"
        return prefix + abs(self).formattedHoursMinutes()
    }
}
