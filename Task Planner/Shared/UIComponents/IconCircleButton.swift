//
//  IconCircleButton.swift
//  Task Planner
//
//  Created by Руслан Меланин on 09.02.2026.
//

import Foundation
import SwiftUI

struct IconCircleButton: View {
    @Environment(\.dsAdaptiveMetrics) private var dsMetrics

    let systemName: String
    let foregroundColor: Color
    let backgroundColor: Color
    let action: () -> Void

    init(
        systemName: String,
        foregroundColor: Color = DS.ColorToken.textPrimary,
        backgroundColor: Color = DS.Surface.chrome,
        action: @escaping () -> Void
    ) {
        self.systemName = systemName
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(
                    dsMetrics.font(
                        17,
                        weight: .semibold,
                        design: .rounded,
                        category: .micro
                    )
                )
                .foregroundStyle(foregroundColor)
                .frame(
                    width: dsMetrics.controlSize(42),
                    height: dsMetrics.controlSize(42)
                )
                .dsSurface(Circle(), fill: backgroundColor)
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
    }
}
