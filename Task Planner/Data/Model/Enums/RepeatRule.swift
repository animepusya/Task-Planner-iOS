//
//  RepeatRule.swift
//  Task Planner
//
//  Created by Руслан Меланин on 09.02.2026.
//

import Foundation

enum RepeatRule: String, CaseIterable, Codable {
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
        case .none: return "None"
        case .daily: return "Daily"
        case .weekdays: return "Weekdays"
        case .weekends: return "Weekends"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .everyNDays: return "Select manually"
        }
    }
}
