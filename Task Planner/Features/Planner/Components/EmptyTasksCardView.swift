//
//  EmptyTasksCardView.swift
//  Task Planner
//
//  Created by Руслан Меланин on 10.02.2026.
//

import SwiftUI

struct EmptyTasksCardView: View {
    @Environment(\.dsAdaptiveMetrics) private var dsMetrics

    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            content
        }
        .buttonStyle(EmptyTasksCardPressStyle())
        .accessibilityLabel("Create Task")
        .accessibilityHint("Opens task editor")
    }

    private var content: some View {
        HStack(spacing: dsMetrics.spacing(12)) {
            VStack(alignment: .leading, spacing: dsMetrics.spacing(4)) {
                Text("No tasks yet")
                    .font(
                        dsMetrics.font(
                            15,
                            weight: .semibold,
                            category: .body
                        )
                    )
                    .foregroundColor(DS.ColorToken.textPrimary)

                Text("Tap + to create your first task.")
                    .font(
                        dsMetrics.font(
                            12,
                            weight: .medium,
                            category: .caption
                        )
                    )
                    .foregroundColor(DS.ColorToken.textSecondary)
            }

            Spacer(minLength: 0)
        }
        .dsCard()
        .contentShape(Rectangle())
    }
}

private struct EmptyTasksCardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
