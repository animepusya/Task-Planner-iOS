//
//  ImportedEventCardView.swift
//  Task Planner
//
//  Created by Руслан Меланин on 01.03.2026.
//

import SwiftUI

struct ImportedEventCardView: View {
    let event: ExternalCalendarEvent

    var body: some View {
        PlannerCardView(model: model) {
            ImportedIndicatorPill()
        }
    }

    private var model: PlannerCardModel {
        let mapped = TaskColor.closest(to: event.calendarColor)

        let subtitleParts: [String] = [
            event.calendarTitle,
            (event.location?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
        ].compactMap { $0 }

        return .init(
            title: event.title,
            subtitle: subtitleParts.joined(separator: " • "),
            timeText: timeText,
            badgeText: nil,
            thumb: nil,
            surfaceColor: mapped.surface(opacity: 1.0),
            isMuted: false
        )
    }

    private var timeText: String {
        if event.isAllDay { return "All day" }
        return "\(event.startDate.formatted(date: .omitted, time: .shortened)) – \(event.endDate.formatted(date: .omitted, time: .shortened))"
    }
}
