//
//  SettingsScreenHeader.swift
//  Task Planner
//
//  Created by Руслан Меланин on 14.03.2026.
//

import SwiftUI

struct SettingsScreenHeader: View {
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: DS.Spacing.sm) {
            Capsule()
                .fill(Color.secondary.opacity(0.22))
                .frame(width: 38, height: 5)

            HStack(alignment: .center) {
                Text("Settings")
                    .font(DS.Typography.title)
                    .foregroundStyle(DS.ColorToken.textPrimary)

                Spacer()

                IconCircleButton(systemName: "xmark") {
                    onClose()
                }
            }
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.top, DS.Spacing.sm)
        .padding(.bottom, DS.Spacing.xs)
    }
}
