//
//  CalendarEventCardView.swift
//  Task Planner
//
//  Created by Руслан Меланин on 01.03.2026.
//

import SwiftUI

struct CalendarEventCardView: View {
    let event: ExternalCalendarEvent

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .fill(event.calendarColor)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(event.title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(DS.ColorToken.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    Text(timeText)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    Text(event.calendarTitle)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)

                    if let location = event.location, !location.isEmpty {
                        Text("• \(location)")
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding()
        .background(
            DS.ColorToken.cardBackground.opacity(0.75),
            in: RoundedRectangle(cornerRadius: DS.Radius.lg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .strokeBorder(.white.opacity(0.06), lineWidth: 1)
        )
    }

    private var timeText: String {
        if event.isAllDay { return "All day" }
        return "\(event.startDate.timeTitle())–\(event.endDate.timeTitle())"
    }
}
