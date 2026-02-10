//
//  DonutChartView.swift
//  Task Planner
//
//  Created by Руслан Меланин on 10.02.2026.
//

import Foundation
import SwiftUI

struct DonutChartSlice: Identifiable, Hashable {
    let id: String
    let fraction: Double // 0...1
    let color: Color
}

struct DonutChartView: View {
    let slices: [DonutChartSlice]
    let lineWidth: CGFloat

    init(slices: [DonutChartSlice], lineWidth: CGFloat = 18) {
        self.slices = slices
        self.lineWidth = lineWidth
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.black.opacity(0.06), style: StrokeStyle(lineWidth: lineWidth))

            ForEach(Array(slices.enumerated()), id: \.element.id) { idx, slice in
                let start = startTrim(for: idx)
                let end = start + slice.fraction

                Circle()
                    .trim(from: start, to: end)
                    .stroke(slice.color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
        }
        .animation(.easeInOut(duration: 0.35), value: slices)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Donut chart")
    }

    private func startTrim(for index: Int) -> Double {
        guard index > 0 else { return 0 }
        return slices.prefix(index).reduce(0) { $0 + $1.fraction }
    }
}
