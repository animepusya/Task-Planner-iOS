//
//  TaskCardView.swift
//  Task Planner
//
//  Created by Руслан Меланин on 10.02.2026.
//

import SwiftUI
import SwiftData

struct TaskCardView: View {
    let occurrence: DayOccurrence
    let isCompleted: Bool

    private let surfaceOpacity: Double = 0.4

    var body: some View {
        HStack(spacing: 12) {

            VStack(alignment: .leading, spacing: 6) {

                HStack(spacing: 8) {
                    Text(occurrence.task.title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(DS.ColorToken.textPrimary)
                        .strikethrough(isCompleted, color: DS.ColorToken.textSecondary.opacity(0.8))
                        .opacity(isCompleted ? 0.55 : 1.0)

                    if let badge = occurrence.badge {
                        badgePill(text: badge.rawValue)
                            .opacity(isCompleted ? 0.55 : 1.0)
                    }

                    Spacer(minLength: 0)
                }

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
        .background(occurrence.task.color.surface(opacity: surfaceOpacity))
        .cornerRadius(DS.Radius.md)
        .shadow(color: DS.Shadow.soft, radius: 12, x: 0, y: 8)
        .opacity(isCompleted ? 0.70 : 1.0)
    }

    private var subtitleText: String {
        if let notes = occurrence.task.notes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return notes
        }
        return occurrence.task.categoryTitle ?? CategorySystem.uncategorizedTitle
    }

    private var timeRangeText: String {
        if occurrence.task.isAllDay || occurrence.isAllDaySegment {
            return "All day"
        }
        return "\(occurrence.displayStart.formatted(date: .omitted, time: .shortened)) – \(occurrence.displayEnd.formatted(date: .omitted, time: .shortened))"
    }

    private func badgePill(text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(DS.ColorToken.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(DS.ColorToken.textSecondary.opacity(0.14))
            )
    }
}
