//
//  ScheduledReminderRow.swift
//  Task Planner
//
//  Created by Руслан Меланин on 03.03.2026.
//

import SwiftUI

struct ScheduledReminderRow: View {
    @Environment(\.dsAdaptiveMetrics) private var dsMetrics

    let reminder: ScheduledReminderItem

    private let doneAnim: Animation = .easeInOut(duration: 0.18)

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = .current
        f.calendar = .current
        f.dateFormat = "d MMM, HH:mm"
        return f
    }()

    private var timeText: String { Self.timeFormatter.string(from: reminder.fireDate) }
    private var isSuppressed: Bool { reminder.isSuppressed }

    var body: some View {
        HStack(spacing: dsMetrics.spacing(12)) {
            Circle()
                .fill(reminder.taskColor.uiColor)
                .frame(
                    width: dsMetrics.spacing(10),
                    height: dsMetrics.spacing(10)
                )
                .opacity(isSuppressed ? 0.55 : 1.0)

            VStack(alignment: .leading, spacing: dsMetrics.spacing(6)) {
                HStack(spacing: dsMetrics.spacing(8)) {
                    Text(LocalizedDisplayText.taskTitle(reminder.taskTitle))
                        .font(
                            dsMetrics.font(
                                15,
                                weight: .semibold,
                                category: .body
                            )
                        )
                        .foregroundStyle(isSuppressed ? DS.ColorToken.textSecondary : DS.ColorToken.textPrimary)
                        .strikethrough(isSuppressed, color: DS.ColorToken.textSecondary.opacity(0.85))
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .layoutPriority(1)

                    if isSuppressed {
                        StatusPill(title: String(localized: "Disabled for this day"), isOn: false)
                            .scaleEffect(0.92, anchor: .leading)
                            .fixedSize(horizontal: true, vertical: false)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: isSuppressed ? "bell.slash.fill" : "bell.fill")
                        .font(
                            dsMetrics.font(
                                13,
                                weight: .semibold,
                                category: .micro
                            )
                        )
                        .foregroundStyle(DS.ColorToken.textSecondary.opacity(isSuppressed ? 0.55 : 0.8))
                }

                Text(timeText)
                    .font(
                        dsMetrics.font(
                            12,
                            weight: .medium,
                            category: .caption
                        )
                    )
                    .foregroundStyle(DS.ColorToken.textSecondary)
                    .strikethrough(isSuppressed, pattern: .solid, color: DS.ColorToken.textSecondary.opacity(0.55))
                    .opacity(isSuppressed ? 0.65 : 1.0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(dsMetrics.spacing(12))
        .background(cardSurface)
        .saturation(isSuppressed ? 0.35 : 1.0)
        .grayscale(isSuppressed ? 0.25 : 0.0)
        .scaleEffect(isSuppressed ? 0.995 : 1.0)

        .animation(doneAnim, value: isSuppressed)
    }

    private var cardSurface: some View {
        RoundedRectangle(
            cornerRadius: dsMetrics.cornerRadius(DS.Radius.md),
            style: .continuous
        )
            .fill(DS.ColorToken.cardBackground)
            .overlay(
                topHighlight.clipShape(
                    RoundedRectangle(
                        cornerRadius: dsMetrics.cornerRadius(DS.Radius.md),
                        style: .continuous
                    )
                )
            )
            .overlay(border)
    }

    private var topHighlight: some View {
        DS.GradientToken.cardTopHighlight
        .blendMode(.screen)
        .opacity(0.9)
    }

    private var border: some View {
        RoundedRectangle(
            cornerRadius: dsMetrics.cornerRadius(DS.Radius.md),
            style: .continuous
        )
            .strokeBorder(DS.Border.subtle, lineWidth: dsMetrics.strokeWidth(1))
    }
}
