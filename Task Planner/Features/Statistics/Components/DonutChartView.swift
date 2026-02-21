//
//  DonutChartView.swift
//  Task Planner
//
//  Created by Руслан Меланин on 10.02.2026.
//

//
//  DonutChartView.swift
//  Task Planner
//
//  iOS 17+ Swift Charts donut with:
//  - gaps between slices
//  - rounded tile corners
//  - long-press to lock + drag to select slice (ScrollView-friendly)
//

import SwiftUI
import Charts

// MARK: - Model

struct DonutChartSlice: Identifiable, Hashable {
    let id: String
    /// Can be normalized or not — we normalize internally.
    let fraction: Double
    let color: Color
}

// MARK: - Donut View

struct DonutChartView: View {
    let slices: [DonutChartSlice]

    /// Inner hole ratio (0...1). Bigger = thinner ring.
    /// Example: 0.62 looks close to most “wide donut” designs.
    let innerRadiusRatio: Double

    /// Gap between tiles in degrees.
    let gapDegrees: Double

    /// Soft rounding for tiles (pt).
    let cornerRadius: CGFloat

    @Binding var selectedSliceId: String?

    @State private var isInteracting = false

    init(
        slices: [DonutChartSlice],
        innerRadiusRatio: Double = 0.62,
        gapDegrees: Double = 1.2,
        cornerRadius: CGFloat = 6,
        selectedSliceId: Binding<String?>
    ) {
        self.slices = slices
        self.innerRadiusRatio = innerRadiusRatio
        self.gapDegrees = gapDegrees
        self.cornerRadius = cornerRadius
        self._selectedSliceId = selectedSliceId
    }

    var body: some View {
        let data = normalized(slices)

        Chart {
            ForEach(data) { s in
                SectorMark(
                    angle: .value("Value", s.fraction),
                    innerRadius: .ratio(innerRadiusRatio),
                    angularInset: gapDegrees
                )
                .foregroundStyle(s.color)
                .cornerRadius(cornerRadius)
                .opacity(selectedSliceId == nil || selectedSliceId == s.id ? 1.0 : 0.35)
            }
        }
        .chartLegend(.hidden)
        .chartPlotStyle { plot in
            plot.background(Color.clear)
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                let frame = geo[proxy.plotAreaFrame]
                let center = CGPoint(x: frame.midX, y: frame.midY)

                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .highPriorityGesture(selectionGesture(center: center, plotFrame: frame, data: data))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Donut chart")
    }

    // MARK: - Gesture

    private func selectionGesture(
        center: CGPoint,
        plotFrame: CGRect,
        data: [DonutChartSlice]
    ) -> some Gesture {
        LongPressGesture(minimumDuration: 0.18, maximumDistance: 12)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .local))
            .onChanged { value in
                switch value {
                case .first(true):
                    isInteracting = true

                case .second(true, let drag?):
                    guard isInteracting else { return }
                    let id = hitTest(
                        point: drag.location,
                        center: center,
                        plotFrame: plotFrame,
                        data: data
                    )
                    if selectedSliceId != id {
                        selectedSliceId = id
                    }

                default:
                    break
                }
            }
            .onEnded { _ in
                isInteracting = false
                selectedSliceId = nil
            }
    }

    // MARK: - Hit testing

    private func hitTest(
        point: CGPoint,
        center: CGPoint,
        plotFrame: CGRect,
        data: [DonutChartSlice]
    ) -> String? {
        guard !data.isEmpty else { return nil }

        let outerR = min(plotFrame.width, plotFrame.height) / 2
        let innerR = outerR * innerRadiusRatio

        let dx = point.x - center.x
        let dy = point.y - center.y
        let r = hypot(dx, dy)

        // only ring
        guard r >= innerR, r <= outerR else { return nil }

        // angle: 0 at top, clockwise
        var a = atan2(dy, dx) // [-π, π]
        if a < 0 { a += 2 * .pi }
        a += .pi / 2
        if a >= 2 * .pi { a -= 2 * .pi }

        var cursor = 0.0
        let gap = gapDegrees * .pi / 180.0

        for s in data {
            let full = 2 * .pi * max(0, s.fraction)
            let start = cursor
            let end = cursor + full

            // ignore gaps on both sides
            let v0 = start + gap / 2
            let v1 = end - gap / 2

            if v1 > v0, a >= v0, a <= v1 {
                return s.id
            }

            cursor = end
        }

        return nil
    }

    // MARK: - Normalize

    private func normalized(_ input: [DonutChartSlice]) -> [DonutChartSlice] {
        let sum = input.reduce(0.0) { $0 + max(0, $1.fraction) }
        guard sum > 0 else { return [] }
        return input.map {
            DonutChartSlice(id: $0.id, fraction: max(0, $0.fraction) / sum, color: $0.color)
        }
    }
}
