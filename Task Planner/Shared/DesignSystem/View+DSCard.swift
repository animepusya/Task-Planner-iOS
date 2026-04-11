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
}

private struct DSSurfaceModifier<Shape: InsettableShape, Fill: ShapeStyle>: ViewModifier {
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
                shape.stroke(stroke, lineWidth: lineWidth)
            )
    }
}

private struct DSCardModifier<Background: View>: ViewModifier {
    let padding: CGFloat
    let cornerRadius: CGFloat
    let style: DS.CardStyle
    let background: Background

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content
            .padding(padding)
            .background(background)
            .clipShape(shape)
            .overlay {
                shape.stroke(DS.Border.subtle, lineWidth: 1)
            }
    }
}
