//
//  TaskSeriesModels.swift
//  Task Planner
//
//  Created by Руслан Меланин on 06.03.2026.
//

import Foundation

// MARK: - Template stored inside segments/overrides

struct TaskSeriesTemplate: Codable, Equatable {
    var title: String
    var notes: String?
    var isAllDay: Bool

    var startMinutes: Int
    var endMinutes: Int
    var endDayOffset: Int

    var repeatRuleRaw: String
    var repeatIntervalDays: Int?

    var colorRaw: String
    var categoryTitle: String?
    var photoThumbData: Data?

    var reminderEnabled: Bool
    var reminderOffsetMinutes: Int
    var reminderAllDayTimeMinutes: Int?

    var repeatRule: RepeatRule {
        RepeatRule(rawValue: repeatRuleRaw) ?? .none
    }

    var durationSeconds: TimeInterval {
        let safeEndOffset = max(0, endDayOffset)
        let totalEnd = safeEndOffset * 1440 + max(0, endMinutes)
        let totalStart = max(0, startMinutes)
        let minutes = max(1, totalEnd - totalStart)
        return TimeInterval(minutes * 60)
    }
}

struct TaskSeriesSegment: Codable, Identifiable, Equatable {
    var id: UUID
    var startDayKey: String
    var endDayKey: String?
    var template: TaskSeriesTemplate

    var startDay: Date {
        DayKey.parse(startDayKey)
    }

    var endDay: Date? {
        guard let endDayKey else { return nil }
        return DayKey.parse(endDayKey)
    }
}

struct TaskSeriesOverride: Codable, Identifiable, Equatable {
    var id: UUID
    var dayKey: String
    var isDeleted: Bool
    var template: TaskSeriesTemplate?
}

// MARK: - DayKey parsing/formatting (LOCAL DAY, stable)
enum DayKey {

    static func format(_ day: Date, calendar: Calendar = .current) -> String {
        TaskEntity.dayKey(for: day, calendar: calendar)
    }

    static func parse(_ key: String, calendar: Calendar = .current) -> Date {
        let parts = key.split(separator: "-")
        guard parts.count == 3,
              let y = Int(parts[0]),
              let m = Int(parts[1]),
              let d = Int(parts[2])
        else {
            return Date.distantPast
        }

        var comps = DateComponents()
        comps.calendar = calendar
        comps.timeZone = calendar.timeZone
        comps.year = y
        comps.month = m
        comps.day = d
        comps.hour = 0
        comps.minute = 0
        comps.second = 0

        return calendar.date(from: comps) ?? Date.distantPast
    }

    static func parse(_ key: String) -> Date {
        parse(key, calendar: .current)
    }
}
