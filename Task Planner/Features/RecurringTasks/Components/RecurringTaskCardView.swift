//
//  RecurringTaskCardView.swift
//  Task Planner
//
//  Created by Руслан Меланин on 09.03.2026.
//

import SwiftUI
import UIKit

struct RecurringTaskCardView: View {
    let task: RecurringTaskSource

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
            surfaceColor: task.color.uiColor,
            colorTreatment: .subtleAccent,
            isMuted: false
        )
    }

    private var displayTitle: String {
        LocalizedDisplayText.taskTitle(task.title)
    }

    private var subtitleText: String {
        CategorySystem.localizedDisplayTitle(for: task.categoryTitle)
    }

    private var repeatText: String {
        task.repeatRule.displayName
    }

    private var thumbImage: UIImage? {
        guard let data = task.photoThumbData else { return nil }
        return UIImage(data: data)
    }
}
