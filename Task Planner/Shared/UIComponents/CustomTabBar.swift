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
                title: "Statistics",
                systemImage: "chart.pie.fill",
                isActive: selected == .statistics,
                activeStyle: .statistics
            ) {
                onSelectStatistics()
            }
        }
        .padding(10)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.70))
                .shadow(color: DS.Shadow.soft, radius: 16, x: 0, y: 10)
        )
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.bottom, 10)
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
            .background(background(isActive: isActive, activeStyle: activeStyle))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func background(isActive: Bool, activeStyle: ActiveStyle) -> some View {
        Group {
            if isActive {
                switch activeStyle {
                case .planner:
                    DS.ColorToken.purple
                case .statistics:
                    DS.GradientToken.brandPink
                }
            } else {
                Color.white.opacity(0.95)
            }
        }
        .shadow(color: DS.Shadow.soft, radius: isActive ? 18 : 10, x: 0, y: isActive ? 10 : 6)
    }

    private func foreground(isActive: Bool, activeStyle: ActiveStyle) -> some ShapeStyle {
        if isActive {
            return Color.white
        } else {
            return DS.ColorToken.textPrimary.opacity(0.85)
        }
    }
}
