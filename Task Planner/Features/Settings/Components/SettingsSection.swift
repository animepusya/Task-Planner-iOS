//
//  SettingsSection.swift
//  Task Planner
//
//  Created by Руслан Меланин on 14.03.2026.
//

import SwiftUI

struct SettingsSection<Content: View>: View {
    let title: String
    let footer: String?
    @ViewBuilder let content: () -> Content

    init(
        title: String,
        footer: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.footer = footer
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(title.uppercased())
                .font(DS.Typography.caption)
                .foregroundStyle(DS.ColorToken.textSecondary)
                .padding(.horizontal, DS.Spacing.xs)

            content()

            if let footer, !footer.isEmpty {
                Text(footer)
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.ColorToken.textSecondary)
                    .padding(.horizontal, DS.Spacing.xs)
                    .padding(.top, 2)
            }
        }
    }
}
