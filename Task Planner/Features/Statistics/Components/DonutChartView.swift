//
//  DonutChartView.swift
//  Task Planner
//
//  Created by Руслан Меланин on 10.02.2026.
//

import SwiftUI

struct DonutChartSlice: Identifiable, Hashable {
    let id: String
    let fraction: Double // 0...1 (normalized)
    let color: Color
}

struct DonutChartView: View {
    let slices: [DonutChartSlice]
    let lineWidth: CGFloat
    let gapDegrees: Double

    @Binding var selectedSliceId: String?

    @State private var isInteracting = false

    init(
        slices: [DonutChartSlice],
        lineWidth: CGFloat = 34,
        gapDegrees: Double = 6,
        selectedSliceId: Binding<String?>
    ) {
        self.slices = slices
        self.lineWidth = lineWidth
        self.gapDegrees = gapDegrees
        self._selectedSliceId = selectedSliceId
    }

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)

            let outerRadius = size / 2
            let innerRadius = outerRadius - lineWidth

            ZStack {
                // background ring
                Circle()
                  .stroke(Color.black.opacity(0.06), style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                // segments
                ForEach(segments(innerRadius: innerRadius, outerRadius: outerRadius)) { seg in
                    DonutArc(
                        startAngle: seg.visibleStart,
                        endAngle: seg.visibleEnd
                    )
                    .stroke(
                        seg.color,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt)
                    )
                    .opacity(selectedSliceId == nil || selectedSliceId == seg.id ? 1.0 : 0.35)
                }
            }
            .contentShape(
                // важно: жесты ловим только на кольце, а не на всей рамке
                DonutHitShape(innerRadius: innerRadius, outerRadius: outerRadius)
            )
            .highPriorityGesture(interactionGesture(center: center, innerRadius: innerRadius, outerRadius: outerRadius))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Donut chart")
    }

    // MARK: - Gesture: long press to lock, then drag updates selection

    private func interactionGesture(center: CGPoint, innerRadius: CGFloat, outerRadius: CGFloat) -> some Gesture {
        LongPressGesture(minimumDuration: 0.18, maximumDistance: 12)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .local))
            .onChanged { value in
                switch value {
                case .first(true):
                    // long press recognized — now we “own” the interaction
                    if !isInteracting {
                        isInteracting = true
                    }
                case .second(true, let drag?):
                    guard isInteracting else { return }
                    selectedSliceId = hitTestSlice(
                        at: drag.location,
                        center: center,
                        innerRadius: innerRadius,
                        outerRadius: outerRadius
                    )
                default:
                    break
                }
            }
            .onEnded { _ in
                isInteracting = false
                selectedSliceId = nil
            }
    }

    // MARK: - Segments geometry

    private struct Segment: Identifiable {
        let id: String
        let visibleStart: Angle
        let visibleEnd: Angle
        let color: Color
    }

    private func segments(innerRadius: CGFloat, outerRadius: CGFloat) -> [Segment] {
        guard !slices.isEmpty else { return [] }

        // start at top (-90°)
        var cursor = -Double.pi / 2
        let gap = gapDegrees * Double.pi / 180.0

        var result: [Segment] = []
        result.reserveCapacity(slices.count)

        for s in slices {
            let full = 2 * Double.pi * max(0, s.fraction)
            let start = cursor
            let end = cursor + full

            // apply gap (split gap across both sides)
            let soften = 0.5 * Double.pi / 180.0   // ~0.5°
            let visibleStart = start + gap / 2 - soften
            let visibleEnd = end - gap / 2 + soften
            
            if visibleEnd > visibleStart {
                result.append(
                    Segment(
                        id: s.id,
                        visibleStart: .radians(visibleStart),
                        visibleEnd: .radians(visibleEnd),
                        color: s.color
                    )
                )
            }

            cursor = end
        }

        return result
    }

    // MARK: - Hit testing

    private func hitTestSlice(at point: CGPoint, center: CGPoint, innerRadius: CGFloat, outerRadius: CGFloat) -> String? {
        let dx = point.x - center.x
        let dy = point.y - center.y
        let r = hypot(dx, dy)

        // must be within ring
        guard r >= innerRadius, r <= outerRadius else { return nil }

        // angle in [0, 2π), where 0 is at top (12 o’clock)
        var angle = atan2(dy, dx) // [-π, π]
        angle = angle < 0 ? angle + 2 * Double.pi : angle
        // rotate so that -90° becomes 0
        angle = angle + Double.pi / 2
        angle = angle >= 2 * Double.pi ? angle - 2 * Double.pi : angle

        // walk over segments with gaps respected
        var cursor = 0.0
        let gap = gapDegrees * Double.pi / 180.0

        for s in slices {
            let full = 2 * Double.pi * max(0, s.fraction)
            let start = cursor
            let end = cursor + full

            let visibleStart = start + gap / 2
            let visibleEnd = end - gap / 2

            if angle >= visibleStart && angle <= visibleEnd {
                return s.id
            }

            cursor = end
        }

        return nil
    }
}

// MARK: - Arc shape

private struct DonutArc: Shape {
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        var p = Path()
        p.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        return p
    }
}

// MARK: - Hit shape (ring area only)

private struct DonutHitShape: Shape {
    let innerRadius: CGFloat
    let outerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var p = Path()

        // outer circle
        p.addEllipse(in: CGRect(
            x: center.x - outerRadius,
            y: center.y - outerRadius,
            width: outerRadius * 2,
            height: outerRadius * 2
        ))

        // inner hole (subtracted via even-odd fill)
        p.addEllipse(in: CGRect(
            x: center.x - innerRadius,
            y: center.y - innerRadius,
            width: innerRadius * 2,
            height: innerRadius * 2
        ))

        return p
    }
}
