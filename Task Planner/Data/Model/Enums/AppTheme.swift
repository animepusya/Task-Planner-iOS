//
//  AppTheme.swift
//  Task Planner
//
//  Created by Codex on 04.04.2026.
//

import Foundation
import SwiftUI

enum AppTheme: String, CaseIterable, Codable, Identifiable, Sendable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            return String(localized: "System")
        case .light:
            return String(localized: "Light")
        case .dark:
            return String(localized: "Dark")
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    func resolvedColorScheme(using systemScheme: ColorScheme) -> ColorScheme {
        preferredColorScheme ?? systemScheme
    }
}
