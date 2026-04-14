//
//  TaskColor+UI.swift
//  Task Planner
//
//  Created by Codex on 15.04.2026.
//

import SwiftUI
import UIKit

@MainActor
extension TaskColor {
    /// UI palette for accents, indicators and cards.
    var uiColor: Color {
        palette.baseColor
    }

    /// Preserves the hue while adjusting only opacity for surfaces.
    func surface(opacity: Double) -> Color {
        uiColor.opacity(max(0, min(1, opacity)))
    }

    var labelColor: Color {
        switch palette.labelTone {
        case .dark:
            return .black.opacity(0.85)
        case .light:
            return .white
        }
    }

    static func closest(to external: Color) -> TaskColor {
        guard let (er, eg, eb, _) = external.uiRGBA() else { return .blue }

        var bestMatch: TaskColor = .blue
        var bestDistance: CGFloat = .greatestFiniteMagnitude

        for candidate in TaskColor.allCases {
            let rgba = candidate.palette.rgba
            let dr = rgba.red - er
            let dg = rgba.green - eg
            let db = rgba.blue - eb
            let distance = dr * dr + dg * dg + db * db

            if distance < bestDistance {
                bestDistance = distance
                bestMatch = candidate
            }
        }

        return bestMatch
    }

    private var palette: TaskColorPalette {
        switch self {
        case .blue:
            return .init(red: 0.32, green: 0.62, blue: 0.98, labelTone: .light)
        case .purple:
            return .init(baseColor: .purple, red: 0.50, green: 0.00, blue: 0.50, labelTone: .light)
        case .pink:
            return .init(red: 0.98, green: 0.45, blue: 0.72, labelTone: .light)
        case .red:
            return .init(red: 0.98, green: 0.35, blue: 0.35, labelTone: .light)
        case .yellow:
            return .init(red: 0.98, green: 0.80, blue: 0.20, labelTone: .dark)
        case .green:
            return .init(red: 0.20, green: 0.75, blue: 0.48, labelTone: .light)
        case .orange:
            return .init(red: 0.98, green: 0.56, blue: 0.24, labelTone: .light)
        case .teal:
            return .init(red: 0.20, green: 0.72, blue: 0.72, labelTone: .light)
        case .indigo:
            return .init(red: 0.36, green: 0.36, blue: 0.94, labelTone: .light)
        case .mint:
            return .init(red: 0.35, green: 0.86, blue: 0.62, labelTone: .dark)
        case .brown:
            return .init(red: 0.64, green: 0.45, blue: 0.32, labelTone: .light)
        }
    }
}

@MainActor
private extension Color {
    func uiRGBA() -> (CGFloat, CGFloat, CGFloat, CGFloat)? {
        let ui = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        guard ui.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return nil }
        return (red, green, blue, alpha)
    }
}

private struct TaskColorPalette {
    let baseColor: Color
    let rgba: RGBA
    let labelTone: TaskColorLabelTone

    init(baseColor: Color? = nil, red: CGFloat, green: CGFloat, blue: CGFloat, labelTone: TaskColorLabelTone) {
        let resolvedColor = baseColor ?? Color(red: red, green: green, blue: blue)
        self.baseColor = resolvedColor
        self.rgba = RGBA(red: red, green: green, blue: blue)
        self.labelTone = labelTone
    }
}

private struct RGBA {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
}

private enum TaskColorLabelTone {
    case light
    case dark
}
