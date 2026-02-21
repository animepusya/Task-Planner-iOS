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
        HStack(spacing: 3) {
            ForEach(Array(indicatorColors.prefix(3).enumerated()), id: \.offset) { _, color in
                Capsule(style: .continuous)
                    .fill(color.uiColor)
                    .frame(width: 7, height: 3)
            }

            if indicatorColors.isEmpty {
                Color.clear.frame(width: 7, height: 3)
            }
        }
    }
}

