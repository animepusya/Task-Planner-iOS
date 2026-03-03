//
//  DSRowButton.swift
//  Task Planner
//
//  Created by Руслан Меланин on 03.03.2026.
//

import SwiftUI

struct DSRowButton: View {
    let title: String
    let value: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Text(title)
                    .font(DS.Typography.body)
                    .foregroundStyle(DS.ColorToken.textPrimary)

                Spacer(minLength: 12)

                Text(value)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(DS.ColorToken.textSecondary)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DS.ColorToken.textSecondary.opacity(0.7))
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(Color.black.opacity(0.04))
            .cornerRadius(DS.Radius.sm)
        }
        .buttonStyle(.plain)
    }
}
