//
//  TaskColor.swift
//  Task Planner
//
//  Created by Руслан Меланин on 09.02.2026.
//

import Foundation
import SwiftUI

enum TaskColor: String, CaseIterable, Codable, Hashable {
    case blue
    case purple
    case pink
    case red
    case yellow
    case green

    var uiColor: Color {
        switch self {
        case .blue: return Color.blue
        case .purple: return Color.purple
        case .pink: return Color.pink
        case .red: return Color.red
        case .yellow: return Color.yellow
        case .green: return Color.green
        }
    }
}
