//
//  StatusPill.swift
//  Task Planner
//
//  Created by Руслан Меланин on 03.03.2026.
//

import SwiftUI

struct StatusPill: View {
    let title: String
    let isOn: Bool

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(isOn ? DS.ColorToken.textPrimary : DS.ColorToken.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.pill)
                    .fill(isOn ? DS.ColorToken.lavender.opacity(0.55) : DS.ColorToken.controlFillStrong)
            )
    }
}
