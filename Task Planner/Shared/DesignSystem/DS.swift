//
//  DS.swift
//  Task Planner
//
//  Created by Руслан Меланин on 09.02.2026.
//

import SwiftUI

enum DS {
    enum CardStyle {
        case solid
        case outlined
    }

    enum Spacing {
        static let xs: CGFloat = 6
        static let sm: CGFloat = 10
        static let md: CGFloat = 16
        static let lg: CGFloat = 22
        static let xl: CGFloat = 28
    }

    enum Layout {
        static let tabBarMinHeight: CGFloat = 42
        static let tabBarBottomSpacing: CGFloat = 6
        static let tabBarReservedScrollSpace: CGFloat = 72
    }

    enum Radius {
        static let sm: CGFloat = 12
        static let md: CGFloat = 18
        static let lg: CGFloat = 26
        static let pill: CGFloat = 999
    }

    enum Border {
        static let subtle = Color.black.opacity(0.045)
        static let muted = Color.black.opacity(0.025)
        static let inverted = Color.white.opacity(0.18)
    }

    enum ColorToken {
        static let purple = Color(red: 0.55, green: 0.39, blue: 0.98)
        static let purpleDark = Color(red: 0.38, green: 0.23, blue: 0.82)

        static let appBackground = Color(red: 0.98, green: 0.98, blue: 1.00)
        static let cardBackground = Color.white

        static let lavender = Color(red: 0.85, green: 0.82, blue: 0.98)
        static let lightPink = Color(red: 0.98, green: 0.83, blue: 0.92)

        static let textPrimary = Color(red: 0.12, green: 0.12, blue: 0.16)
        static let textSecondary = Color(red: 0.45, green: 0.45, blue: 0.52)
    }

    enum Surface {
        static let card = Color.white.opacity(0.94)
        static let chrome = Color.white.opacity(0.90)
        static let frosted = Color.white.opacity(0.78)
    }

    enum GradientToken {
        static let splash = LinearGradient(
            colors: [ColorToken.lavender, ColorToken.lightPink],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let brand = LinearGradient(
            colors: [ColorToken.purple, ColorToken.purpleDark],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let brandPink = LinearGradient(
            colors: [
                Color(red: 0.98, green: 0.42, blue: 0.77),
                ColorToken.purple
            ],
            startPoint: .leading,
            endPoint: .trailing
        )

        static let pinkPurpleSoft = LinearGradient(
            colors: [
                ColorToken.lightPink,
                ColorToken.lavender
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        @ViewBuilder
        static var pinkPurpleCardBackground: some View {
            ZStack {
                pinkPurpleSoft
                    .opacity(0.90)

                Color.white.opacity(0.62)
            }
        }
    }

    enum Typography {
        static let title = Font.system(size: 28, weight: .bold, design: .rounded)
        static let subtitle = Font.system(size: 15, weight: .medium, design: .rounded)
        static let sectionTitle = Font.system(size: 18, weight: .semibold, design: .rounded)
        static let body = Font.system(size: 15, weight: .regular, design: .rounded)
        static let caption = Font.system(size: 12, weight: .medium, design: .rounded)
    }
}
