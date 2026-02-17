//
//  TaskEditorPillField.swift
//  Task Planner
//
//  Created by Руслан Меланин on 11.02.2026.
//

import SwiftUI

struct TaskEditorPillField<Trailing: View>: View {
    let title: String?
    let icon: String
    let trailingWidth: CGFloat
    let showsIcon: Bool

    @ViewBuilder var trailing: () -> Trailing

    init(
        title: String?,
        icon: String,
        trailingWidth: CGFloat,
        showsIcon: Bool = true,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.title = title
        self.icon = icon
        self.trailingWidth = trailingWidth
        self.showsIcon = showsIcon
        self.trailing = trailing
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title {
                Text(title)
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.ColorToken.textSecondary)
            } else {
                Color.clear
                    .frame(height: 14)
            }

            HStack(spacing: 8) {
                if showsIcon {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DS.ColorToken.textSecondary)
                }

                Spacer(minLength: 0)

                trailing()
                    .frame(width: trailingWidth, alignment: .trailing)
            }
            .padding(10)
            .background(Color.black.opacity(0.04))
            .cornerRadius(DS.Radius.sm)
        }
        .frame(maxWidth: .infinity)
    }
}
