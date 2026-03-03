//
//  ReminderPreset.swift
//  Task Planner
//
//  Created by Руслан Меланин on 03.03.2026.
//

import Foundation

enum ReminderPreset: Hashable, CaseIterable, Identifiable {
    case atTime
    case minutes(Int)
    case customMinutes

    var id: String {
        switch self {
        case .atTime: return "atTime"
        case .minutes(let m): return "m-\(m)"
        case .customMinutes: return "custom"
        }
    }

    static var allCases: [ReminderPreset] {
        [
            .atTime,
            .minutes(5),
            .minutes(10),
            .minutes(15),
            .minutes(30),
            .minutes(60),
            .minutes(24 * 60),
            .customMinutes
        ]
    }

    var title: String {
        switch self {
        case .atTime: return "At time"
        case .minutes(let m):
            if m == 60 { return "1h" }
            if m == 24 * 60 { return "1d" }
            return "\(m)m"
        case .customMinutes: return "Custom"
        }
    }

    static func fromOffsetMinutes(_ minutes: Int) -> ReminderPreset {
        if minutes == 0 { return .atTime }
        let candidates = [5, 10, 15, 30, 60, 24 * 60]
        if candidates.contains(minutes) { return .minutes(minutes) }
        return .customMinutes
    }

    func resolvedOffsetMinutes(customValue: Int) -> Int {
        switch self {
        case .atTime: return 0
        case .minutes(let m): return max(0, m)
        case .customMinutes: return max(0, customValue)
        }
    }
}
