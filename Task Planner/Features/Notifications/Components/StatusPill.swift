//
//  StatusPill.swift
//  Task Planner
//
//  Created by Руслан Меланин on 03.03.2026.
//

import SwiftUI

struct StatusPill: View {
    @Environment(\.dsAdaptiveMetrics) private var dsMetrics

    let title: String
    let isOn: Bool

    var body: some View {
        Text(title)
            .font(
                dsMetrics.font(
                    12,
                    weight: .semibold,
                    category: .micro
                )
            )
            .foregroundStyle(isOn ? DS.ColorToken.textPrimary : DS.ColorToken.textSecondary)
            .padding(.horizontal, dsMetrics.spacing(10))
            .padding(.vertical, dsMetrics.spacing(6))
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.pill)
                    .fill(isOn ? DS.ColorToken.lavender.opacity(0.55) : DS.ColorToken.controlFillStrong)
            )
    }
}
