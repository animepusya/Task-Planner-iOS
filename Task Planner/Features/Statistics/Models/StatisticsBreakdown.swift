//
//  StatisticsBreakdown.swift
//  Task Planner
//
//  Created by Руслан Меланин on 15.02.2026.
//

import Foundation

enum StatisticsBreakdown: String, CaseIterable, Identifiable, Sendable {
    case category
    case task

    var id: String { rawValue }

    var title: String {
        switch self {
        case .category: return "By category"
        case .task:     return "By task"
        }
    }
}
