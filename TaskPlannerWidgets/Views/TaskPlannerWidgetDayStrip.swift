//
//  TaskPlannerWidgetDayStrip.swift
//  TaskPlannerWidgetsExtension
//
//  Created by Руслан Меланин on 13.03.2026.
//

import SwiftUI
import AppIntents
import WidgetKit

struct TaskPlannerWidgetDayStrip: View {
    let days: [PlannerWidgetDaySnapshot]
    let selectedDayKey: String
    let isAccented: Bool

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        VStack(spacing: 0) {
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(days) { day in
                    Button(intent: SelectWidgetDayIntent(dayKey: day.dayKey)) {
                        dayCell(day)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(stripBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func dayCell(_ day: PlannerWidgetDaySnapshot) -> some View {
        let isSelected = day.dayKey == selectedDayKey

        return VStack(spacing: 4) {
            Text(day.weekdayShortText)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(day.dayNumberText)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(numberForeground(isSelected: isSelected))
                .frame(width: 28, height: 28)
                .background(numberBackground(isSelected: isSelected))

            dayIndicators(day)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func numberBackground(isSelected: Bool) -> some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isAccented ? Color.white.opacity(0.20) : DS.ColorToken.purple)
                .widgetAccentable(isAccented)
        } else {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isAccented ? Color.white.opacity(0.08) : DS.ColorToken.cardBackground.opacity(0.58))
        }
    }

    private func numberForeground(isSelected: Bool) -> some ShapeStyle {
        if isAccented {
            return AnyShapeStyle(.primary)
        } else {
            return AnyShapeStyle(isSelected ? Color.white : DS.ColorToken.textPrimary)
        }
    }

    private func dayIndicators(_ day: PlannerWidgetDaySnapshot) -> some View {
        let colors = Array(day.tasks.filter { !$0.isCompleted }.prefix(3)).compactMap {
            TaskColor(rawValue: $0.colorRaw)?.uiColor
        }

        return HStack(spacing: 3) {
            if colors.isEmpty {
                Capsule(style: .continuous)
                    .fill(Color.clear)
                    .frame(width: 7, height: 3)
            } else {
                ForEach(Array(colors.enumerated()), id: \.offset) { _, color in
                    Capsule(style: .continuous)
                        .fill(isAccented ? Color.white.opacity(0.70) : color.opacity(0.95))
                        .frame(width: 7, height: 3)
                        .widgetAccentable(isAccented)
                }
            }
        }
        .frame(height: 4)
    }

    @ViewBuilder
    private var stripBackground: some View {
        if isAccented {
            Color.white.opacity(0.08)
        } else {
            ZStack {
                DS.GradientToken.pinkPurpleSoft.opacity(0.40)
                DS.ColorToken.appBackground.opacity(0.72)
            }
        }
    }
}
