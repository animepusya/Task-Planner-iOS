//
//  BaseRecurringTaskCardView.swift
//  Task Planner
//
//  Created by Руслан Меланин on 09.03.2026.
//

import SwiftUI
import UIKit

struct BaseRecurringTaskCardView: View {
    let task: TaskEntity

    var body: some View {
        PlannerCardView(model: model) {
            EmptyView()
        }
    }

    private var model: PlannerCardModel {
        .init(
            title: displayTitle,
            subtitle: subtitleText,
            timeText: repeatText,
            badgeText: nil,
            thumb: thumbImage,
            surfaceColor: task.color.surface(opacity: 1.0),
            isMuted: false
        )
    }

    private var displayTitle: String {
        let trimmed = task.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled" : trimmed
    }

    private var subtitleText: String {
        let trimmed = (task.categoryTitle ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return trimmed.isEmpty ? CategorySystem.uncategorizedTitle : trimmed
    }

    private var repeatText: String {
        task.repeatRule.displayName
    }

    private var thumbImage: UIImage? {
        guard let data = task.photoThumbData else { return nil }
        return UIImage(data: data)
    }
}
