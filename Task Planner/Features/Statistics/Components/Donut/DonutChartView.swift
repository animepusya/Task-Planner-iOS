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
    let renderKey: String
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
        let renderState = DonutChartRenderState(
            slices: slices,
            innerRadiusRatio: innerRadiusRatio,
            gapDegrees: gapDegrees,
            cornerRadius: cornerRadius
        )
        let data = renderState.slices

        Chart {
            ForEach(data, id: \.renderKey) { s in
                SectorMark(
                    angle: .value("Value", s.fraction),
                    innerRadius: .ratio(renderState.innerRadiusRatio),
                    angularInset: renderState.gapDegrees
                )
                .foregroundStyle(by: .value("Slice", s.renderKey))
                .cornerRadius(renderState.cornerRadius)
                .opacity(selectedSliceId == nil || selectedSliceId == s.id ? 1.0 : 0.32)
            }
        }
        .chartLegend(.hidden)
        .chartForegroundStyleScale(
            domain: data.map(\.renderKey),
            range: data.map(\.color)
        )
        .chartPlotStyle { plot in
            plot.background(Color.clear)
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                if let plotFrame = proxy.plotFrame.map({ geo[$0] }),
                   plotFrame.width.isFinite,
                   plotFrame.height.isFinite,
                   plotFrame.width > 0,
                   plotFrame.height > 0 {
                    let localCenter = CGPoint(
                        x: plotFrame.width / 2,
                        y: plotFrame.height / 2
                    )

                    Color.clear
                        .frame(width: plotFrame.width, height: plotFrame.height)
                        .position(x: plotFrame.midX, y: plotFrame.midY)
                        .contentShape(
                            DonutInteractionRingShape(innerRadiusRatio: renderState.innerRadiusRatio)
                        )
                        .gesture(
                            tapSelectionGesture(
                                center: localCenter,
                                plotSize: plotFrame.size,
                                data: data,
                                gapDegrees: renderState.gapDegrees,
                                innerRadiusRatio: renderState.innerRadiusRatio
                            )
                        )
                        .simultaneousGesture(
                            dragSelectionGesture(
                                center: localCenter,
                                plotSize: plotFrame.size,
                                data: data,
                                gapDegrees: renderState.gapDegrees,
                                innerRadiusRatio: renderState.innerRadiusRatio
                            )
                        )
                }
            }
        }
        .animation(.easeInOut(duration: 0.20), value: sliceAnimationState(for: data))
        .animation(.easeInOut(duration: 0.14), value: selectedSliceId)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Donut chart")
    }

    private func sliceAnimationState(for data: [DonutChartSlice]) -> [DonutChartSliceAnimationState] {
        data.map {
            DonutChartSliceAnimationState(
                renderKey: $0.renderKey,
                semanticID: $0.id,
                fraction: $0.fraction
            )
        }
    }

    private func tapSelectionGesture(
        center: CGPoint,
        plotSize: CGSize,
        data: [DonutChartSlice],
        gapDegrees: Double,
        innerRadiusRatio: Double
    ) -> some Gesture {
        SpatialTapGesture()
            .onEnded { value in
                let id = hitTest(
                    point: value.location,
                    center: center,
                    plotSize: plotSize,
                    data: data,
                    gapDegrees: gapDegrees,
                    innerRadiusRatio: innerRadiusRatio
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
        data: [DonutChartSlice],
        gapDegrees: Double,
        innerRadiusRatio: Double
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
                        data: data,
                        gapDegrees: gapDegrees,
                        innerRadiusRatio: innerRadiusRatio
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
        data: [DonutChartSlice],
        gapDegrees: Double,
        innerRadiusRatio: Double
    ) -> String? {
        guard
            !data.isEmpty,
            point.x.isFinite,
            point.y.isFinite,
            center.x.isFinite,
            center.y.isFinite,
            plotSize.width.isFinite,
            plotSize.height.isFinite
        else {
            return nil
        }

        let outerR = min(plotSize.width, plotSize.height) / 2
        let innerR = outerR * innerRadiusRatio
        guard
            outerR.isFinite,
            innerR.isFinite,
            outerR > 0,
            innerR >= 0,
            innerR < outerR
        else {
            return nil
        }

        let dx = point.x - center.x
        let dy = point.y - center.y
        let r = hypot(dx, dy)
        guard r.isFinite else { return nil }

        guard r >= innerR, r <= outerR else { return nil }

        var a = atan2(dy, dx)
        if a < 0 { a += 2 * .pi }
        a += .pi / 2
        if a >= 2 * .pi { a -= 2 * .pi }

        var cursor = 0.0
        let gap = gapDegrees * .pi / 180.0

        for s in data {
            let full = 2 * .pi * s.fraction
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
}

private struct DonutChartSliceAnimationState: Equatable {
    let renderKey: String
    let semanticID: String
    let fraction: Double
}

private struct DonutChartRenderState {
    let slices: [DonutChartSlice]
    let innerRadiusRatio: Double
    let gapDegrees: Double
    let cornerRadius: CGFloat

    init(
        slices: [DonutChartSlice],
        innerRadiusRatio: Double,
        gapDegrees: Double,
        cornerRadius: CGFloat
    ) {
        self.slices = Self.normalizedSlices(from: slices)
        self.innerRadiusRatio = Self.sanitizedInnerRadiusRatio(innerRadiusRatio)
        self.gapDegrees = Self.sanitizedGapDegrees(
            requested: gapDegrees,
            slices: self.slices
        )
        self.cornerRadius = Self.sanitizedCornerRadius(cornerRadius)
    }

    private static func normalizedSlices(from slices: [DonutChartSlice]) -> [DonutChartSlice] {
        let sanitized = slices.compactMap { slice -> DonutChartSlice? in
            guard slice.fraction.isFinite, slice.fraction > 0 else { return nil }
            return slice
        }

        let total = sanitized.reduce(0.0) { $0 + $1.fraction }
        guard total.isFinite, total > 0 else { return [] }

        return sanitized.map { slice in
            DonutChartSlice(
                id: slice.id,
                renderKey: slice.renderKey,
                fraction: slice.fraction / total,
                color: slice.color
            )
        }
    }

    private static func sanitizedInnerRadiusRatio(_ value: Double) -> Double {
        guard value.isFinite else { return 0.62 }
        return min(max(value, 0.05), 0.95)
    }

    private static func sanitizedGapDegrees(
        requested: Double,
        slices: [DonutChartSlice]
    ) -> Double {
        guard requested.isFinite, requested > 0, slices.count > 1 else { return 0 }
        guard let smallestSliceDegrees = slices.map({ $0.fraction * 360.0 }).min(),
              smallestSliceDegrees.isFinite
        else {
            return 0
        }

        let maxGap = max(0, smallestSliceDegrees - 0.5)
        return min(requested, maxGap)
    }

    private static func sanitizedCornerRadius(_ value: CGFloat) -> CGFloat {
        guard value.isFinite else { return 0 }
        return max(0, value)
    }
}

private struct DonutInteractionRingShape: Shape {
    let innerRadiusRatio: Double

    func path(in rect: CGRect) -> Path {
        guard
            rect.width.isFinite,
            rect.height.isFinite,
            rect.width > 0,
            rect.height > 0
        else {
            return Path()
        }

        let outerRadius = min(rect.width, rect.height) / 2
        let safeInnerRadiusRatio = innerRadiusRatio.isFinite
            ? min(max(innerRadiusRatio, 0.05), 0.95)
            : 0.62
        let innerRadius = outerRadius * safeInnerRadiusRatio
        guard outerRadius.isFinite, innerRadius.isFinite, innerRadius >= 0, innerRadius < outerRadius else {
            return Path()
        }

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
