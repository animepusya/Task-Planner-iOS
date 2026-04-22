//
//  DayCellView.swift
//  Task Planner
//
//  Created by Руслан Меланин on 09.02.2026.
//

import SwiftUI

struct DayCellView: View {
    @Environment(\.dsAdaptiveMetrics) private var dsMetrics

    let dayNumber: Int
    let date: Date
    let isSelected: Bool

    let indicatorColors: [TaskColor]
    let onTap: () -> Void

    private let indAnim: Animation = .easeInOut(duration: 0.18)

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: dsMetrics.spacing(6)) {
                Text("\(dayNumber)")
                    .font(
                        dsMetrics.font(
                            14,
                            weight: .semibold,
                            category: .micro
                        )
                    )
                    .foregroundColor(isSelected ? .white : DS.ColorToken.textPrimary)
                    .frame(
                        width: dsMetrics.controlSize(34),
                        height: dsMetrics.controlSize(34)
                    )
                    .background(isSelected ? DS.ColorToken.purple : Color.clear)
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: dsMetrics.cornerRadius(12),
                            style: .continuous
                        )
                    )

                indicators
            }
            .frame(maxWidth: .infinity, minHeight: dsMetrics.controlSize(44))
        }
        .buttonStyle(.plain)
    }

    private var indicators: some View {
        let colors = Array(indicatorColors.prefix(3))
        return HStack(spacing: dsMetrics.detailSize(3)) {
            if colors.isEmpty {
                // placeholder keeps layout stable
                Color.clear
                    .frame(
                        width: dsMetrics.detailSize(7),
                        height: dsMetrics.detailSize(3)
                    )
                    .transition(.opacity)
            } else {
                ForEach(colors, id: \.rawValue) { color in
                    Capsule(style: .continuous)
                        .fill(color.uiColor)
                        .frame(
                            width: dsMetrics.detailSize(7),
                            height: dsMetrics.detailSize(3)
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.85)))
                }
            }
        }
        .animation(indAnim, value: indicatorColorsKey)
    }

    private var indicatorColorsKey: String {
        indicatorColors.prefix(3).map(\.rawValue).joined(separator: "|")
    }
}
