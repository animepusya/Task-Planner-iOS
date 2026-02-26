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
    let isVisuallyDone: Bool

    private var surfaceOpacity: Double { isVisuallyDone ? 0.16 : 0.40 }
    private let doneAnim: Animation = .easeInOut(duration: 0.18)

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {

                HStack(spacing: 8) {
                    Text(occurrence.task.title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(isVisuallyDone ? DS.ColorToken.textSecondary : DS.ColorToken.textPrimary)
                        .strikethrough(isVisuallyDone, color: DS.ColorToken.textSecondary.opacity(0.85))

                    if let badge = occurrence.badge {
                        badgePill(text: badge.rawValue, isMuted: isVisuallyDone)
                    }

                    Spacer(minLength: 0)

                    if isVisuallyDone {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(DS.ColorToken.textSecondary.opacity(0.85))
                            // ✅ чуть мягче появление
                            .transition(.scale(scale: 0.92).combined(with: .opacity))
                    }
                }

                Text(subtitleText)
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.ColorToken.textSecondary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DS.ColorToken.textSecondary)

                    Text(timeRangeText)
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.ColorToken.textSecondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(DS.Spacing.md)
        .background(occurrence.task.color.surface(opacity: surfaceOpacity))
        .overlay(doneOverlay)
        .cornerRadius(DS.Radius.md)
        .shadow(color: DS.Shadow.soft, radius: 12, x: 0, y: 8)
        .saturation(isVisuallyDone ? 0.35 : 1.0)
        .grayscale(isVisuallyDone ? 0.25 : 0.0)
        .scaleEffect(isVisuallyDone ? 0.995 : 1.0)
        .animation(doneAnim, value: isVisuallyDone)
    }

    private var doneOverlay: some View {
        RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
            .stroke(
                DS.ColorToken.textSecondary.opacity(isVisuallyDone ? 0.22 : 0.0),
                lineWidth: 1
            )
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

    private func badgePill(text: String, isMuted: Bool) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(DS.ColorToken.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(DS.ColorToken.textSecondary.opacity(isMuted ? 0.10 : 0.14))
            )
    }
}
