//
//  ImportedEventCardView.swift
//  Task Planner
//
//  Created by Руслан Меланин on 01.03.2026.
//

import SwiftUI

struct ImportedEventCardView: View {
    let row: PlannerImportedEventRowData

    var body: some View {
        PlannerCardView(model: model) {
            ImportedIndicatorPill()
        }
    }

    private var model: PlannerCardModel {
        let subtitleParts: [String] = [
            row.calendarTitle,
            (row.location?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
        ].compactMap { $0 }

        return .init(
            title: LocalizedDisplayText.taskTitle(row.title),
            subtitle: subtitleParts.joined(separator: " • "),
            timeText: timeText,
            badgeText: nil,
            thumb: nil,
            surfaceColor: row.mappedColor.surface(opacity: 1.0),
            colorTreatment: .fullSurface,
            isMuted: false
        )
    }

    private var timeText: String {
        if row.isAllDay { return String(localized: "All day") }
        return "\(row.startDate.formatted(date: .omitted, time: .shortened)) – \(row.endDate.formatted(date: .omitted, time: .shortened))"
    }
}
