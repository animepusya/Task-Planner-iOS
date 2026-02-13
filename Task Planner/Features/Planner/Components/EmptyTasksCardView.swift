//
//  EmptyTasksCardView.swift
//  Task Planner
//
//  Created by Руслан Меланин on 10.02.2026.
//

import SwiftUI

struct EmptyTasksCardView: View {
    var body: some View {
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
    }
}
