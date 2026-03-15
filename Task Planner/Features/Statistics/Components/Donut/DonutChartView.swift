//
//  DonutChartView.swift
//  Task Planner
//
//  Created by Руслан Меланин on 10.02.2026.
//

import SwiftUI
import Charts

struct DonutChartSlice: Identifiable, Hashable {
    let id: String
    let fraction: Double
    let color: Color
}

struct DonutChartView: View {
    let slices: [DonutChartSlice]

    let innerRadiusRatio: Double
    let gapDegrees: Double
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
                .opacity(selectedSliceId == nil || selectedSliceId == s.id ? 1.0 : 0.32)
            }
        }
        .chartLegend(.hidden)
        .chartPlotStyle { plot in
            plot.background(Color.clear)
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                let plotFrame = geo[proxy.plotAreaFrame]

                if plotFrame.width > 0, plotFrame.height > 0 {
                    let localCenter = CGPoint(
                        x: plotFrame.width / 2,
                        y: plotFrame.height / 2
                    )

                    Color.clear
                        .frame(width: plotFrame.width, height: plotFrame.height)
                        .position(x: plotFrame.midX, y: plotFrame.midY)
                        .contentShape(
                            DonutInteractionRingShape(innerRadiusRatio: innerRadiusRatio)
                        )
                        .gesture(
                            tapSelectionGesture(
                                center: localCenter,
                                plotSize: plotFrame.size,
                                data: data
                            )
                        )
                        .simultaneousGesture(
                            dragSelectionGesture(
                                center: localCenter,
                                plotSize: plotFrame.size,
                                data: data
                            )
                        )
                }
            }
        }
        .animation(.easeInOut(duration: 0.14), value: selectedSliceId)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Donut chart")
    }

    private func tapSelectionGesture(
        center: CGPoint,
        plotSize: CGSize,
        data: [DonutChartSlice]
    ) -> some Gesture {
        SpatialTapGesture()
            .onEnded { value in
                let id = hitTest(
                    point: value.location,
                    center: center,
                    plotSize: plotSize,
                    data: data
                )

                withAnimation(.easeInOut(duration: 0.12)) {
                    if selectedSliceId == id {
                        selectedSliceId = nil
                    } else {
                        selectedSliceId = id
                    }
                }
            }
    }

    private func dragSelectionGesture(
        center: CGPoint,
        plotSize: CGSize,
        data: [DonutChartSlice]
    ) -> some Gesture {
        LongPressGesture(minimumDuration: 0.18, maximumDistance: 10)
            .sequenced(before: DragGesture(minimumDistance: 6, coordinateSpace: .local))
            .onChanged { value in
                switch value {
                case .first(true):
                    isInteracting = true

                case .second(true, let drag?):
                    guard isInteracting else { return }

                    let id = hitTest(
                        point: drag.location,
                        center: center,
                        plotSize: plotSize,
                        data: data
                    )

                    if selectedSliceId != id {
                        withAnimation(.easeInOut(duration: 0.10)) {
                            selectedSliceId = id
                        }
                    }

                default:
                    break
                }
            }
            .onEnded { _ in
                isInteracting = false
                withAnimation(.easeInOut(duration: 0.10)) {
                    selectedSliceId = nil
                }
            }
    }

    private func hitTest(
        point: CGPoint,
        center: CGPoint,
        plotSize: CGSize,
        data: [DonutChartSlice]
    ) -> String? {
        guard !data.isEmpty else { return nil }

        let outerR = min(plotSize.width, plotSize.height) / 2
        let innerR = outerR * innerRadiusRatio

        let dx = point.x - center.x
        let dy = point.y - center.y
        let r = hypot(dx, dy)

        guard r >= innerR, r <= outerR else { return nil }

        var a = atan2(dy, dx)
        if a < 0 { a += 2 * .pi }
        a += .pi / 2
        if a >= 2 * .pi { a -= 2 * .pi }

        var cursor = 0.0
        let gap = gapDegrees * .pi / 180.0

        for s in data {
            let full = 2 * .pi * max(0, s.fraction)
            let start = cursor
            let end = cursor + full

            let v0 = start + gap / 2
            let v1 = end - gap / 2

            if v1 > v0, a >= v0, a <= v1 {
                return s.id
            }

            cursor = end
        }

        return nil
    }

    private func normalized(_ input: [DonutChartSlice]) -> [DonutChartSlice] {
        let sum = input.reduce(0.0) { $0 + max(0, $1.fraction) }
        guard sum > 0 else { return [] }

        return input.map {
            DonutChartSlice(
                id: $0.id,
                fraction: max(0, $0.fraction) / sum,
                color: $0.color
            )
        }
    }
}

private struct DonutInteractionRingShape: Shape {
    let innerRadiusRatio: Double

    func path(in rect: CGRect) -> Path {
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * innerRadiusRatio
        let center = CGPoint(x: rect.midX, y: rect.midY)

        var path = Path()
        path.addArc(
            center: center,
            radius: outerRadius,
            startAngle: .degrees(0),
            endAngle: .degrees(360),
            clockwise: false
        )
        path.addArc(
            center: center,
            radius: innerRadius,
            startAngle: .degrees(360),
            endAngle: .degrees(0),
            clockwise: true
        )
        path.closeSubpath()
        return path
    }
}
