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

    private let thumbSide: CGFloat = 52
    private let thumbCornerRadius: CGFloat = DS.Radius.sm

    var body: some View {
        HStack(spacing: 12) {
            contentLeft

            Spacer(minLength: 0)

            if let thumb = thumbImage {
                thumbContainer(thumb)
            }
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

    private var contentLeft: some View {
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

                // ✅ removed checkmark (per your request)
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
    }

    private var thumbImage: UIImage? {
        guard let data = occurrence.task.photoThumbData else { return nil }
        return UIImage(data: data)
    }

    /// ✅ Key point:
    /// We DO NOT clip the Image.
    /// We clip the *container* so edges are always perfect and premium.
    private func thumbContainer(_ ui: UIImage) -> some View {
        ZStack {
            // a subtle surface under the image so it always looks clean
            RoundedRectangle(cornerRadius: thumbCornerRadius, style: .continuous)
                .fill(Color.white.opacity(0.55))

            Image(uiImage: ui)
                .resizable()
                .scaledToFill()
                .frame(width: thumbSide, height: thumbSide)
        }
        .frame(width: thumbSide, height: thumbSide)
        .clipShape(RoundedRectangle(cornerRadius: thumbCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: thumbCornerRadius, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
        .padding(.leading, 2)
        .accessibilityLabel("Task photo")
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
