//
//  CompactMenuRow.swift
//  Task Planner
//
//  Created by Руслан Меланин on 04.03.2026.
//

import SwiftUI

struct CompactMenuRow<Content: View>: View {
    @Environment(\.dsAdaptiveMetrics) private var dsMetrics

    let title: String
    let value: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        Menu {
            content()
        } label: {
            rowLabel
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(value)
    }

    private var rowLabel: some View {
        HStack(spacing: dsMetrics.spacing(10)) {
            Text(title)
                .font(
                    dsMetrics.font(
                        15,
                        weight: .regular,
                        category: .body
                    )
                )
                .foregroundStyle(DS.ColorToken.textPrimary)

            Spacer(minLength: dsMetrics.spacing(10))

            Text(value)
                .font(
                    dsMetrics.font(
                        14,
                        weight: .semibold,
                        category: .micro
                    )
                )
                .foregroundStyle(DS.ColorToken.textSecondary)
                .lineLimit(1)
                .truncationMode(.tail)

            Image(systemName: "chevron.down")
                .font(
                    dsMetrics.font(
                        12,
                        weight: .semibold,
                        category: .micro
                    )
                )
                .foregroundStyle(DS.ColorToken.textSecondary.opacity(0.65))
        }
        .padding(.vertical, dsMetrics.spacing(8))
        .padding(.horizontal, dsMetrics.spacing(10))
        .background(DS.ColorToken.controlFill)
        .cornerRadius(dsMetrics.cornerRadius(DS.Radius.sm))
    }
}
