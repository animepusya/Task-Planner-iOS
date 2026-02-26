//
//  DayCellView.swift
//  Task Planner
//
//  Created by Руслан Меланин on 09.02.2026.
//

import SwiftUI

struct DayCellView: View {
    let dayNumber: Int
    let date: Date
    let isSelected: Bool

    let indicatorColors: [TaskColor]
    let onTap: () -> Void

    private let indAnim: Animation = .easeInOut(duration: 0.18)

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Text("\(dayNumber)")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(isSelected ? .white : DS.ColorToken.textPrimary)
                    .frame(width: 34, height: 34)
                    .background(isSelected ? DS.ColorToken.purple : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                indicators
            }
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.plain)
    }

    private var indicators: some View {
        let colors = Array(indicatorColors.prefix(3))
        return HStack(spacing: 3) {
            if colors.isEmpty {
                // placeholder keeps layout stable
                Color.clear
                    .frame(width: 7, height: 3)
                    .transition(.opacity)
            } else {
                ForEach(colors, id: \.rawValue) { color in
                    Capsule(style: .continuous)
                        .fill(color.uiColor)
                        .frame(width: 7, height: 3)
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
