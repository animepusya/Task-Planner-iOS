//
//  RepeatRule.swift
//  Task Planner
//
//  Created by Руслан Меланин on 09.02.2026.
//

import Foundation

enum RepeatRule: String, CaseIterable, Codable, Sendable {
    case none
    case daily
    case weekdays
    case weekends
    case weekly
    case monthly
    case everyNDays
}

extension RepeatRule {
    static var allCases: [RepeatRule] {
        [
            .none,
            .daily,
            .weekdays,
            .weekends,
            .weekly,
            .monthly,
            .everyNDays
        ]
    }

    var displayName: String {
        switch self {
        case .none: return String(localized: "None")
        case .daily: return String(localized: "Daily")
        case .weekdays: return String(localized: "Weekdays")
        case .weekends: return String(localized: "Weekends")
        case .weekly: return String(localized: "Weekly")
        case .monthly: return String(localized: "Monthly")
        case .everyNDays: return String(localized: "Select manually")
        }
    }
}
