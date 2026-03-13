//
//  TaskPlannerWidgetTaskRow.swift
//  TaskPlannerWidgetsExtension
//
//  Created by Руслан Меланин on 13.03.2026.
//

import SwiftUI
import WidgetKit

struct TaskPlannerWidgetTaskRow: View {
    let task: PlannerWidgetTaskSnapshot
    let isAccented: Bool

    private let rowHeight: CGFloat = 56

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(accentColor.opacity(task.isCompleted ? 0.35 : 0.95))
                .frame(width: 4, height: 32)
                .widgetAccentable(isAccented)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)
                    .strikethrough(task.isCompleted, color: .secondary)
                    .lineLimit(1)

                Text(task.subtitle)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(task.timeText)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, minHeight: rowHeight, maxHeight: rowHeight, alignment: .leading)
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var accentColor: Color {
        TaskColor(rawValue: task.colorRaw)?.uiColor ?? DS.ColorToken.purple
    }

    @ViewBuilder
    private var rowBackground: some View {
        if isAccented {
            Color.white.opacity(0.10)
        } else {
            DS.ColorToken.cardBackground.opacity(0.82)
        }
    }
}
