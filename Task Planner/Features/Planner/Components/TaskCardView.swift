//
//  TaskCardView.swift
//  Task Planner
//
//  Created by Руслан Меланин on 10.02.2026.
//

import SwiftUI
import SwiftData

struct TaskCardView: View {
    let task: TaskEntity
    let isCompleted: Bool

    var body: some View {
        HStack(spacing: 12) {

            VStack(alignment: .leading, spacing: 6) {
                Text(task.title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(DS.ColorToken.textPrimary)
                    .strikethrough(isCompleted, color: DS.ColorToken.textSecondary.opacity(0.8))
                    .opacity(isCompleted ? 0.55 : 1.0)

                Text(subtitleText)
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.ColorToken.textSecondary)
                    .lineLimit(1)
                    .opacity(isCompleted ? 0.55 : 1.0)

                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(DS.ColorToken.textSecondary)
                        .opacity(isCompleted ? 0.55 : 1.0)

                    Text(timeRangeText)
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.ColorToken.textSecondary)
                        .opacity(isCompleted ? 0.55 : 1.0)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(DS.Spacing.md)
        .background(task.color.backgroundColor) // ✅ единая точка правды
        .cornerRadius(DS.Radius.md)
        .shadow(color: DS.Shadow.soft, radius: 12, x: 0, y: 8)
        .opacity(isCompleted ? 0.70 : 1.0)
    }

    private var subtitleText: String {
        if let notes = task.notes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return notes
        }
        return task.categoryTitle ?? CategorySystem.uncategorizedTitle
    }

    private var timeRangeText: String {
        if task.isAllDay {
            return "All day"
        }
        return "\(task.startTime.formatted(date: .omitted, time: .shortened)) – \(task.endTime.formatted(date: .omitted, time: .shortened))"
    }
}
