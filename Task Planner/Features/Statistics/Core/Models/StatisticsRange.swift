//
//  StatisticsRange.swift
//  Task Planner
//
//  Created by Руслан Меланин on 10.02.2026.
//

import Foundation

enum StatisticsRange: String, CaseIterable, Identifiable, Sendable {
    case day
    case week
    case month
    case year

    var id: String { rawValue }

    var title: String {
        switch self {
        case .day:   return String(localized: "Day")
        case .week:  return String(localized: "Week")
        case .month: return String(localized: "Month")
        case .year:  return String(localized: "Year")
        }
    }
}
