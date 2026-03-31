//
//  ScheduledReminderRow.swift
//  Task Planner
//
//  Created by Руслан Меланин on 03.03.2026.
//

import SwiftUI

struct ScheduledReminderRow: View {
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
        HStack(spacing: 12) {
            Circle()
                .fill(reminder.taskColor.uiColor)
                .frame(width: 10, height: 10)
                .opacity(isSuppressed ? 0.55 : 1.0)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(LocalizedDisplayText.taskTitle(reminder.taskTitle))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(isSuppressed ? DS.ColorToken.textSecondary : DS.ColorToken.textPrimary)
                        .strikethrough(isSuppressed, color: DS.ColorToken.textSecondary.opacity(0.85))
                        .lineLimit(1)

                    StatusPill(title: String(localized: "Disabled for this day"), isOn: false)
                        .scaleEffect(0.92, anchor: .leading)
                        .opacity(isSuppressed ? 1.0 : 0.0)

                    Spacer(minLength: 0)

                    Image(systemName: isSuppressed ? "bell.slash.fill" : "bell.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DS.ColorToken.textSecondary.opacity(isSuppressed ? 0.55 : 0.8))
                }

                Text(timeText)
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.ColorToken.textSecondary)
                    .strikethrough(isSuppressed, pattern: .solid, color: DS.ColorToken.textSecondary.opacity(0.55))
                    .opacity(isSuppressed ? 0.65 : 1.0)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(cardSurface)
        .saturation(isSuppressed ? 0.35 : 1.0)
        .grayscale(isSuppressed ? 0.25 : 0.0)
        .scaleEffect(isSuppressed ? 0.995 : 1.0)

        .animation(doneAnim, value: isSuppressed)
    }

    private var cardSurface: some View {
        RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
            .fill(DS.ColorToken.cardBackground)
            .overlay(topHighlight.clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)))
            .overlay(border)
    }

    private var topHighlight: some View {
        LinearGradient(
            colors: [
                Color.white.opacity(0.55),
                Color.white.opacity(0.18),
                Color.white.opacity(0.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .blendMode(.screen)
        .opacity(0.9)
    }

    private var border: some View {
        RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
            .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
    }
}
