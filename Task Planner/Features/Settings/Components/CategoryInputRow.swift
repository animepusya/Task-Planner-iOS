//
//  CategoryInputRow.swift
//  Task Planner
//
//  Created by Руслан Меланин on 14.03.2026.
//

import SwiftUI

struct CategoryInputRow: View {
    let title: String
    let showsProBadge: Bool
    let action: () -> Void

    var body: some View {
        SettingsRow(
            title: title,
            systemImage: "plus.circle",
            action: action,
            accessory: {
                HStack(spacing: DS.Spacing.sm) {
                    if showsProBadge {
                        ProBadge(size: .small)
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DS.ColorToken.textSecondary.opacity(0.9))
                }
            }
        )
        .accessibilityHint(Text("Opens category creation"))
    }
}

#Preview {
    ZStack {
        AppBackgroundView(gradient: DS.GradientToken.splash)

        SettingsCard {
            CategoryInputRow(
                title: "Add Category",
                showsProBadge: true,
                action: { }
            )
        }
    }
}
