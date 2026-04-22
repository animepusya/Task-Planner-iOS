//
//  NotificationsTopBar.swift
//  Task Planner
//
//  Created by Руслан Меланин on 04.03.2026.
//

import SwiftUI

struct NotificationsTopBar: View {
    @Environment(\.dsAdaptiveMetrics) private var dsMetrics

    let title: String
    let onBack: () -> Void

    var body: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(
                        dsMetrics.font(
                            16,
                            weight: .semibold,
                            category: .micro
                        )
                    )
                    .foregroundStyle(DS.ColorToken.textPrimary)
                    .padding(dsMetrics.spacing(10))
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")

            Spacer()

            Text(title)
                .font(
                    dsMetrics.font(
                        18,
                        weight: .semibold,
                        category: .title
                    )
                )
                .foregroundStyle(DS.ColorToken.textPrimary)

            Spacer()

            Color.clear.frame(
                width: dsMetrics.controlSize(44),
                height: dsMetrics.controlSize(44)
            )
        }
        .padding(.horizontal, dsMetrics.screenPadding(DS.Spacing.lg))
        .padding(.vertical, dsMetrics.spacing(10))
        .dsContentFrame(.modal)
    }
}
