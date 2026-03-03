//
//  ScheduledReminderRow.swift
//  Task Planner
//
//  Created by Руслан Меланин on 03.03.2026.
//

import SwiftUI

struct ScheduledReminderRow: View {
    let reminder: PendingReminder

    private var timeText: String {
        let f = DateFormatter()
        f.dateFormat = reminder.isAllDay ? "d MMM, HH:mm" : "d MMM, HH:mm"
        return f.string(from: reminder.fireDate)
    }

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(reminder.taskColor.uiColor)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 4) {
                Text(reminder.taskTitle)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(DS.ColorToken.textPrimary)
                    .lineLimit(1)

                Text(timeText)
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.ColorToken.textSecondary)
            }

            Spacer()

            Image(systemName: "bell.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DS.ColorToken.textSecondary.opacity(0.8))
        }
        .padding(12)
        .background(DS.ColorToken.cardBackground)
        .cornerRadius(DS.Radius.md)
        .shadow(color: DS.Shadow.soft, radius: 12, x: 0, y: 8)
    }
}
