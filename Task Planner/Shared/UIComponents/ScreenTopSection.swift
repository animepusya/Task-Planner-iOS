//
//  ScreenTopSection.swift
//  Task Planner
//
//  Created by Руслан Меланин on 13.03.2026.
//

import SwiftUI

struct ScreenTopSection<Trailing: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder let trailing: () -> Trailing

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: subtitle == nil ? .center : .top, spacing: DS.Spacing.md) {
            VStack(alignment: .leading, spacing: subtitle == nil ? 0 : 6) {
                Text(title)
                    .font(DS.Typography.title)
                    .foregroundStyle(DS.ColorToken.textPrimary)

                if let subtitle {
                    Text(subtitle)
                        .font(DS.Typography.subtitle)
                        .foregroundStyle(DS.ColorToken.textSecondary)
                }
            }

            Spacer(minLength: 12)

            trailing()
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.top, DS.Spacing.sm)
        .padding(.bottom, DS.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.clear)
    }
}
