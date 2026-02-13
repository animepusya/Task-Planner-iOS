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

    // Accent / primary color used across UI (donut, legend, indicators, picker, etc.)
    var uiColor: Color {
        switch self {
        case .blue:   return Color(red: 0.32, green: 0.62, blue: 0.98)
        case .purple: return Color.purple
        case .pink:   return Color(red: 0.98, green: 0.45, blue: 0.72)
        case .red:    return Color(red: 0.98, green: 0.35, blue: 0.35)
        case .yellow: return Color(red: 0.98, green: 0.80, blue: 0.20)
        case .green:  return Color(red: 0.20, green: 0.75, blue: 0.48)
        case .orange: return Color(red: 0.98, green: 0.56, blue: 0.24)
        case .teal:   return Color(red: 0.20, green: 0.72, blue: 0.72)
        case .indigo: return Color(red: 0.36, green: 0.36, blue: 0.94)
        case .mint:   return Color(red: 0.35, green: 0.86, blue: 0.62)
        case .brown:  return Color(red: 0.64, green: 0.45, blue: 0.32)
        }
    }

    // Soft/pastel background for cards (keeps the same "family" as uiColor)
    var backgroundColor: Color {
        switch self {
        case .blue:   return Color(red: 0.84, green: 0.92, blue: 1.00)
        case .purple: return Color(red: 0.90, green: 0.86, blue: 1.00)
        case .pink:   return Color(red: 1.00, green: 0.88, blue: 0.94)
        case .red:    return Color(red: 1.00, green: 0.88, blue: 0.88)
        case .yellow: return Color(red: 1.00, green: 0.96, blue: 0.84)
        case .green:  return Color(red: 0.86, green: 0.97, blue: 0.90)
        case .orange: return Color(red: 1.00, green: 0.92, blue: 0.84)
        case .teal:   return Color(red: 0.84, green: 0.97, blue: 0.97)
        case .indigo: return Color(red: 0.88, green: 0.90, blue: 1.00)
        case .mint:   return Color(red: 0.86, green: 0.99, blue: 0.92)
        case .brown:  return Color(red: 0.96, green: 0.92, blue: 0.88)
        }
    }
}
