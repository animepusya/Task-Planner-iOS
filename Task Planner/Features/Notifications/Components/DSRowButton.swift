//
//  DSRowButton.swift
//  Task Planner
//
//  Created by Руслан Меланин on 03.03.2026.
//

import SwiftUI

private struct DSRowContent: View {
    let title: String
    let value: String
    let showsChevron: Bool

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(DS.Typography.body)
                .foregroundStyle(DS.ColorToken.textPrimary)

            Spacer(minLength: 12)

            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(DS.ColorToken.textSecondary)

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DS.ColorToken.textSecondary.opacity(0.7))
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(DS.ColorToken.controlFill)
        .cornerRadius(DS.Radius.sm)
    }
}

struct DSRowButton: View {
    let title: String
    let value: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            DSRowContent(title: title, value: value, showsChevron: true)
        }
        .buttonStyle(.plain)
    }
}

struct DSRowMenu<Content: View>: View {
    let title: String
    let value: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        Menu {
            content()
        } label: {
            DSRowContent(title: title, value: value, showsChevron: true)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
    }
}
