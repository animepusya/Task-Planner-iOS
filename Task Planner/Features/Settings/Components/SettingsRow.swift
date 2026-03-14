//
//  SettingsRow.swift
//  Task Planner
//
//  Created by Руслан Меланин on 14.03.2026.
//

import SwiftUI

struct SettingsRow<Accessory: View>: View {
    let title: String
    let subtitle: String?
    let systemImage: String?
    let isDestructive: Bool
    let action: (() -> Void)?
    @ViewBuilder let accessory: () -> Accessory

    init(
        title: String,
        subtitle: String? = nil,
        systemImage: String? = nil,
        isDestructive: Bool = false,
        action: (() -> Void)? = nil,
        @ViewBuilder accessory: @escaping () -> Accessory
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.isDestructive = isDestructive
        self.action = action
        self.accessory = accessory
    }

    var body: some View {
        Group {
            if let action {
                Button(action: action) {
                    rowContent
                }
                .buttonStyle(.plain)
            } else {
                rowContent
            }
        }
    }

    private var rowContent: some View {
        HStack(alignment: .center, spacing: DS.Spacing.sm) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 22)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DS.Typography.body)
                    .foregroundStyle(titleColor)
                    .multilineTextAlignment(.leading)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.ColorToken.textSecondary)
                        .multilineTextAlignment(.leading)
                }
            }

            Spacer(minLength: DS.Spacing.sm)

            accessory()
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    private var titleColor: Color {
        isDestructive ? .red : DS.ColorToken.textPrimary
    }

    private var iconColor: Color {
        isDestructive ? .red : DS.ColorToken.textSecondary
    }
}

struct SettingsRowDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, DS.Spacing.md)
    }
}
