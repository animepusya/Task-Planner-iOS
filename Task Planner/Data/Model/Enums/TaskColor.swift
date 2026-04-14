//
//  TaskColor.swift
//  Task Planner
//
//  Created by Руслан Меланин on 09.02.2026.
//

import Foundation

nonisolated enum TaskColor: String, CaseIterable, Codable, Hashable, Sendable {
    case blue
    case purple
    case pink
    case red
    case yellow
    case green
    case orange
    case teal
    case indigo
    case mint
    case brown
    
    /// Stable domain sort order for snapshot/build pipelines.
    var sortIndex: Int {
        switch self {
        case .blue: return 0
        case .purple: return 1
        case .pink: return 2
        case .red: return 3
        case .yellow: return 4
        case .green: return 5
        case .orange: return 6
        case .teal: return 7
        case .indigo: return 8
        case .mint: return 9
        case .brown: return 10
        }
    }
}
