//
//  EmptyTasksCardView.swift
//  Task Planner
//
//  Created by Руслан Меланин on 10.02.2026.
//

import SwiftUI

struct EmptyTasksCardView: View {
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
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("No tasks yet")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(DS.ColorToken.textPrimary)

                Text("Tap + to create your first task.")
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.ColorToken.textSecondary)
            }

            Spacer(minLength: 0)
        }
        .padding(DS.Spacing.md)
        .background(Color.white)
        .cornerRadius(DS.Radius.md)
        .shadow(color: DS.Shadow.soft, radius: 12, x: 0, y: 8)
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
