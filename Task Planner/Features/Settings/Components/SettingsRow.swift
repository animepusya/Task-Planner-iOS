//
//  SettingsRow.swift
//  Task Planner
//
//  Created by Руслан Меланин on 14.03.2026.
//

import SwiftUI

struct SettingsRow<Accessory: View>: View {
    @Environment(\.dsAdaptiveMetrics) private var dsMetrics

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
        HStack(alignment: .center, spacing: dsMetrics.spacing(DS.Spacing.sm)) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(
                        dsMetrics.font(
                            16,
                            weight: .semibold,
                            category: .micro
                        )
                    )
                    .foregroundStyle(iconColor)
                    .frame(width: dsMetrics.controlSize(22))
            }

            VStack(alignment: .leading, spacing: dsMetrics.spacing(2)) {
                Text(title)
                    .font(
                        dsMetrics.font(
                            15,
                            weight: .regular,
                            category: .body
                        )
                    )
                    .foregroundStyle(titleColor)
                    .multilineTextAlignment(.leading)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(
                            dsMetrics.font(
                                12,
                                weight: .medium,
                                category: .caption
                            )
                        )
                        .foregroundStyle(DS.ColorToken.textSecondary)
                        .multilineTextAlignment(.leading)
                }
            }

            Spacer(minLength: dsMetrics.spacing(DS.Spacing.sm))

            accessory()
        }
        .padding(.horizontal, dsMetrics.spacing(DS.Spacing.md))
        .padding(.vertical, dsMetrics.spacing(14))
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
    @Environment(\.dsAdaptiveMetrics) private var dsMetrics

    var body: some View {
        Divider()
            .padding(.leading, dsMetrics.spacing(DS.Spacing.md))
    }
}
