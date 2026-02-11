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
        .background(taskBackgroundColor(for: task.color))
        .cornerRadius(DS.Radius.md)
        .shadow(color: DS.Shadow.soft, radius: 12, x: 0, y: 8)
        .opacity(isCompleted ? 0.70 : 1.0) // ✅ “completed” ощущается как приглушённое
    }

    private var subtitleText: String {
        if let notes = task.notes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return notes
        }
        return task.categoryTitle ?? "Work"
    }

    private var timeRangeText: String {
        "\(task.startTime.formatted(date: .omitted, time: .shortened)) – \(task.endTime.formatted(date: .omitted, time: .shortened))"
    }

    private func taskBackgroundColor(for color: TaskColor) -> Color {
        switch color {
        case .blue:   return Color(red: 0.84, green: 0.92, blue: 1.00)
        case .purple: return Color(red: 0.90, green: 0.86, blue: 1.00)
        case .pink:   return Color(red: 1.00, green: 0.88, blue: 0.94)
        case .red:    return Color(red: 1.00, green: 0.88, blue: 0.88)
        case .yellow: return Color(red: 1.00, green: 0.96, blue: 0.84)
        case .green:  return Color(red: 0.86, green: 0.97, blue: 0.90)
        }
    }
}
