//
//  View+DSCard.swift
//  Task Planner
//
//  Created by Руслан Меланин on 16.02.2026.
//

import SwiftUI

extension View {
    func dsPrimaryCard(
        padding: CGFloat = DS.Spacing.md,
        cornerRadius: CGFloat = DS.Radius.md
    ) -> some View {
        dsCard(padding: padding, cornerRadius: cornerRadius) {
            DS.Surface.card
        }
    }

    func dsSurface<Shape: InsettableShape, Fill: ShapeStyle>(
        _ shape: Shape,
        fill: Fill,
        stroke: Color = DS.Border.subtle,
        lineWidth: CGFloat = 1
    ) -> some View {
        modifier(
            DSSurfaceModifier(
                shape: shape,
                fill: fill,
                stroke: stroke,
                lineWidth: lineWidth
            )
        )
    }

    func dsCard(
        padding: CGFloat = DS.Spacing.md,
        cornerRadius: CGFloat = DS.Radius.md,
        style: DS.CardStyle = .solid
    ) -> some View {
        dsCard(padding: padding, cornerRadius: cornerRadius, style: style) {
            switch style {
            case .solid:
                DS.ColorToken.cardBackground.opacity(0.96)
            case .outlined:
                DS.Surface.card
            }
        }
    }

    func dsCard<Background: View>(
        padding: CGFloat = DS.Spacing.md,
        cornerRadius: CGFloat = DS.Radius.md,
        style: DS.CardStyle = .solid,
        @ViewBuilder background: () -> Background
    ) -> some View {
        modifier(
            DSCardModifier(
                padding: padding,
                cornerRadius: cornerRadius,
                style: style,
                background: background()
            )
        )
    }

    func dsContentFrame(
        _ role: DSContentWidthRole = .screen,
        alignment: Alignment = .leading
    ) -> some View {
        modifier(
            DSContentFrameModifier(
                role: role,
                alignment: alignment
            )
        )
    }
}

private struct DSSurfaceModifier<Shape: InsettableShape, Fill: ShapeStyle>: ViewModifier {
    @Environment(\.dsAdaptiveMetrics) private var dsMetrics

    let shape: Shape
    let fill: Fill
    let stroke: Color
    let lineWidth: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                shape.fill(fill)
            )
            .overlay(
                shape.stroke(
                    stroke,
                    lineWidth: dsMetrics.strokeWidth(lineWidth)
                )
            )
    }
}

private struct DSCardModifier<Background: View>: ViewModifier {
    @Environment(\.dsAdaptiveMetrics) private var dsMetrics

    let padding: CGFloat
    let cornerRadius: CGFloat
    let style: DS.CardStyle
    let background: Background

    func body(content: Content) -> some View {
        let resolvedPadding = dsMetrics.spacing(padding)
        let resolvedCornerRadius = dsMetrics.cornerRadius(cornerRadius)
        let shape = RoundedRectangle(
            cornerRadius: resolvedCornerRadius,
            style: .continuous
        )

        return content
            .padding(resolvedPadding)
            .background(background)
            .clipShape(shape)
            .overlay {
                shape.stroke(
                    DS.Border.subtle,
                    lineWidth: dsMetrics.strokeWidth(1)
                )
            }
    }
}

private struct DSContentFrameModifier: ViewModifier {
    @Environment(\.dsAdaptiveMetrics) private var dsMetrics

    let role: DSContentWidthRole
    let alignment: Alignment

    func body(content: Content) -> some View {
        Group {
            if let maxWidth = dsMetrics.maxWidth(for: role) {
                content
                    .frame(maxWidth: maxWidth, alignment: alignment)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                content
                    .frame(maxWidth: .infinity, alignment: alignment)
            }
        }
    }
}
