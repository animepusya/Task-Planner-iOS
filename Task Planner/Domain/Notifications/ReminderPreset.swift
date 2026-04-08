//
//  ReminderPreset.swift
//  Task Planner
//
//  Created by Руслан Меланин on 03.03.2026.
//

import Foundation

nonisolated enum ReminderPreset: Int, CaseIterable, Identifiable, Hashable, Sendable {
    case minutes5 = 5
    case minutes10 = 10
    case minutes15 = 15
    case minutes30 = 30
    case minutes60 = 60
    case minutes120 = 120
    case minutes1440 = 1440
    case minutes2880 = 2880
    case minutes10080 = 10080

    var id: Int { rawValue }
    var minutes: Int { rawValue }

    static var `default`: ReminderPreset { .minutes5 }

    var displayName: String {
        switch self {
        case .minutes5: return String(localized: "5 minutes before")
        case .minutes10: return String(localized: "10 minutes before")
        case .minutes15: return String(localized: "15 minutes before")
        case .minutes30: return String(localized: "30 minutes before")
        case .minutes60: return String(localized: "1 hour before")
        case .minutes120: return String(localized: "2 hours before")
        case .minutes1440: return String(localized: "1 day before")
        case .minutes2880: return String(localized: "2 days before")
        case .minutes10080: return String(localized: "1 week before")
        }
    }

    static func normalizeOffsetMinutes(_ minutes: Int) -> Int {
        ReminderPreset(rawValue: minutes)?.minutes ?? ReminderPreset.default.minutes
    }
}
