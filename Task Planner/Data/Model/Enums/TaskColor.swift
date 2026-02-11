//
//  TaskColor.swift
//  Task Planner
//
//  Created by Руслан Меланин on 09.02.2026.
//

import SwiftUI
import Foundation

enum TaskColor: String, CaseIterable, Codable, Hashable {
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

    var uiColor: Color {
        switch self {
        case .blue: return Color(red: 0.32, green: 0.62, blue: 0.98)
        case .purple: return Color.purple
        case .pink: return Color(red: 0.98, green: 0.45, blue: 0.72)
        case .red: return Color(red: 0.98, green: 0.35, blue: 0.35)
        case .yellow: return Color(red: 0.98, green: 0.80, blue: 0.20)
        case .green: return Color(red: 0.20, green: 0.75, blue: 0.48)
        case .orange: return Color(red: 0.98, green: 0.56, blue: 0.24)
        case .teal: return Color(red: 0.20, green: 0.72, blue: 0.72)
        case .indigo: return Color(red: 0.36, green: 0.36, blue: 0.94)
        case .mint: return Color(red: 0.35, green: 0.86, blue: 0.62)
        case .brown: return Color(red: 0.64, green: 0.45, blue: 0.32)
        }
    }
}
