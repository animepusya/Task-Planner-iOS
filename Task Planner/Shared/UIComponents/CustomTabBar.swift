//
//  CustomTabBar.swift
//  Task Planner
//
//  Created by Руслан Меланин on 16.02.2026.
//

import SwiftUI

struct CustomTabBar: View {
    let selected: AppTab
    let plannerTitle: String

    let onSelectPlanner: () -> Void
    let onSelectStatistics: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            tabButton(
                title: plannerTitle,
                systemImage: "calendar",
                isActive: selected == .planner,
                activeStyle: .planner
            ) {
                onSelectPlanner()
            }

            tabButton(
                title: String(localized: "Statistics"),
                systemImage: "chart.pie.fill",
                isActive: selected == .statistics,
                activeStyle: .statistics
            ) {
                onSelectStatistics()
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .frame(minHeight: DS.Layout.tabBarMinHeight)
        .dsSurface(Capsule(), fill: DS.Surface.frosted)
        .padding(.horizontal, DS.Spacing.lg)
        .accessibilityElement(children: .contain)
    }

    private enum ActiveStyle {
        case planner
        case statistics
    }

    private func tabButton(
        title: String,
        systemImage: String,
        isActive: Bool,
        activeStyle: ActiveStyle,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))

                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(foreground(isActive: isActive, activeStyle: activeStyle))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .dsSurface(
                Capsule(),
                fill: backgroundFill(isActive: isActive, activeStyle: activeStyle),
                stroke: backgroundStroke(isActive: isActive)
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func backgroundFill(
        isActive: Bool,
        activeStyle: ActiveStyle
    ) -> AnyShapeStyle {
        if isActive {
            switch activeStyle {
            case .planner:
                return AnyShapeStyle(DS.ColorToken.purple)
            case .statistics:
                return AnyShapeStyle(DS.GradientToken.brandPink)
            }
        } else {
            return AnyShapeStyle(DS.Surface.card)
        }
    }

    private func backgroundStroke(isActive: Bool) -> Color {
        isActive ? DS.Border.inverted : DS.Border.subtle
    }

    private func foreground(isActive: Bool, activeStyle: ActiveStyle) -> some ShapeStyle {
        if isActive {
            return Color.white
        } else {
            return DS.ColorToken.textPrimary.opacity(0.85)
        }
    }
}
