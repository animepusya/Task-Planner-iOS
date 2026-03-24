//
//  TaskColor.swift
//  Task Planner
//
//  Created by Руслан Меланин on 09.02.2026.
//

import Foundation
import SwiftUI
import UIKit

enum TaskColor: String, CaseIterable, Codable, Hashable, Sendable {
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

    /// Единственная точка правды: основной цвет (donut / индикаторы / акценты)
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

    /// Цвет для поверхностей (карточки/плашки). ВАЖНО: оттенок не меняем — только opacity.
    func surface(opacity: Double) -> Color {
        uiColor.opacity(max(0, min(1, opacity)))
    }

    /// (Опционально) цвет текста/иконок поверх uiColor-сурфейса, если понадобится.
    var labelColor: Color {
        switch self {
        case .yellow, .mint:
            return .black.opacity(0.85)
        default:
            return .white
        }
    }
}

extension Color {
    fileprivate func uiRGBA() -> (CGFloat, CGFloat, CGFloat, CGFloat)? {
        let ui = UIColor(self)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        guard ui.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        return (r, g, b, a)
    }
}

extension TaskColor {
    var sortIndex: Int { TaskColor.allCases.firstIndex(of: self) ?? 0 }

    static func closest(to external: Color) -> TaskColor {
        guard let (er, eg, eb, _) = external.uiRGBA() else { return .blue }

        var best: TaskColor = .blue
        var bestDistance: CGFloat = .greatestFiniteMagnitude

        for candidate in TaskColor.allCases {
            guard let (r, g, b, _) = candidate.uiColor.uiRGBA() else { continue }

            let dr = r - er
            let dg = g - eg
            let db = b - eb
            let distance = dr * dr + dg * dg + db * db

            if distance < bestDistance {
                bestDistance = distance
                best = candidate
            }
        }

        return best
    }
}
