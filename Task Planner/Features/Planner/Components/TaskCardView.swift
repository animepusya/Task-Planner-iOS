//
//  TaskCardView.swift
//  Task Planner
//
//  Created by Руслан Меланин on 10.02.2026.
//

import SwiftUI
import SwiftData
import UIKit

struct TaskCardView: View {
    let occurrence: PlannerTaskOccurrence
    let isVisuallyDone: Bool

    var body: some View {
        PlannerCardView(model: model) {
            EmptyView()
        }
    }

    private var model: PlannerCardModel {
        .init(
            title: LocalizedDisplayText.taskTitle(occurrence.title),
            subtitle: subtitleText,
            timeText: timeRangeText,
            badgeText: occurrence.badge?.localizedTitle,
            thumb: thumbImage,
            surfaceColor: occurrence.color.surface(opacity: 1.0),
            isMuted: isVisuallyDone
        )
    }

    private var thumbImage: UIImage? {
        guard let data = occurrence.photoThumbData else { return nil }
        return UIImage(data: data)
    }

    private var subtitleText: String {
        if let notes = occurrence.notes,
           !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return notes
        }
        return CategorySystem.localizedDisplayTitle(for: occurrence.categoryTitle)
    }

    private var timeRangeText: String {
        if occurrence.isAllDaySegment {
            return String(localized: "All day")
        }
        return "\(occurrence.displayStart.formatted(date: .omitted, time: .shortened)) – \(occurrence.displayEnd.formatted(date: .omitted, time: .shortened))"
    }
}
