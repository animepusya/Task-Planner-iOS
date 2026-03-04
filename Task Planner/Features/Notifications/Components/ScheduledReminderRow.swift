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

    private var timeText: String {
        let f = DateFormatter()
        f.locale = Locale.current
        f.calendar = Calendar.current
        f.dateFormat = "d MMM, HH:mm"
        return f.string(from: reminder.fireDate)
    }

    private var isSuppressed: Bool { reminder.isSuppressed }

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(reminder.taskColor.uiColor)
                .frame(width: 10, height: 10)
                .opacity(isSuppressed ? 0.55 : 1.0)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(reminder.taskTitle)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(isSuppressed ? DS.ColorToken.textSecondary : DS.ColorToken.textPrimary)
                        .strikethrough(isSuppressed, color: DS.ColorToken.textSecondary.opacity(0.85))
                        .lineLimit(1)

                    StatusPill(title: "Disabled for this day", isOn: false)
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
        .background(DS.ColorToken.cardBackground)
        .cornerRadius(DS.Radius.md)
        .shadow(color: DS.Shadow.soft, radius: 12, x: 0, y: 8)
        .saturation(isSuppressed ? 0.35 : 1.0)
        .grayscale(isSuppressed ? 0.25 : 0.0)
        .scaleEffect(isSuppressed ? 0.995 : 1.0)
        .opacity(isSuppressed ? 0.90 : 1.0)
        .animation(doneAnim, value: isSuppressed)
    }
}
