//
//  SettingsScreenHeader.swift
//  Task Planner
//
//  Created by Руслан Меланин on 14.03.2026.
//

import SwiftUI

struct SettingsScreenHeader: View {
    let onBack: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: DS.Spacing.sm) {
            IconCircleButton(systemName: "chevron.left") {
                onBack()
            }

            Text("Settings")
                .font(DS.Typography.title)
                .foregroundStyle(DS.ColorToken.textPrimary)

            Spacer()
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.top, DS.Spacing.sm)
        .padding(.bottom, DS.Spacing.xs)
    }
}
