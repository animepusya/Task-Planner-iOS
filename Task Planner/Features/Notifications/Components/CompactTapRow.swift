//
//  CompactTapRow.swift
//  Task Planner
//
//  Created by Руслан Меланин on 04.03.2026.
//

import SwiftUI

struct CompactTapRow: View {
    let title: String
    let value: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Text(title)
                    .font(DS.Typography.body)
                    .foregroundStyle(DS.ColorToken.textPrimary)

                Spacer(minLength: 10)

                Text(value)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(DS.ColorToken.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DS.ColorToken.textSecondary.opacity(0.65))
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(DS.ColorToken.controlFill)
            .cornerRadius(DS.Radius.sm)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(value)
    }
}
