//
//  PlannerCardView.swift
//  Task Planner
//
//  Created by Руслан Меланин on 03.03.2026.
//

import SwiftUI
import UIKit

struct PlannerCardModel: Hashable {
    let title: String
    let subtitle: String
    let timeText: String
    let badgeText: String?
    let thumb: UIImage?

    let surfaceColor: Color
    let isMuted: Bool
}

struct PlannerCardView<TopRight: View>: View {
    let model: PlannerCardModel
    @ViewBuilder let topRight: () -> TopRight

    private var surfaceOpacity: Double { model.isMuted ? 0.16 : 0.40 }
    private let doneAnim: Animation = .easeInOut(duration: 0.18)

    private let thumbSide: CGFloat = 52
    private let thumbCornerRadius: CGFloat = DS.Radius.sm

    var body: some View {
        HStack(spacing: 12) {
            contentLeft

            Spacer(minLength: 0)

            if let thumb = model.thumb {
                thumbContainer(thumb)
            }
        }
        .padding(DS.Spacing.md)
        .background(model.surfaceColor.opacity(surfaceOpacity))
        .overlay(doneOverlay)
        .cornerRadius(DS.Radius.md)
        .shadow(color: DS.Shadow.soft, radius: 12, x: 0, y: 8)
        .saturation(model.isMuted ? 0.35 : 1.0)
        .grayscale(model.isMuted ? 0.25 : 0.0)
        .scaleEffect(model.isMuted ? 0.995 : 1.0)
        .animation(doneAnim, value: model.isMuted)
    }

    private var contentLeft: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(model.title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(model.isMuted ? DS.ColorToken.textSecondary : DS.ColorToken.textPrimary)
                    .strikethrough(model.isMuted, color: DS.ColorToken.textSecondary.opacity(0.85))

                if let badge = model.badgeText {
                    badgePill(text: badge, isMuted: model.isMuted)
                }

                Spacer(minLength: 0)

                topRight()
            }

            Text(model.subtitle)
                .font(DS.Typography.caption)
                .foregroundStyle(DS.ColorToken.textSecondary)
                .lineLimit(1)

            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DS.ColorToken.textSecondary)

                Text(model.timeText)
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.ColorToken.textSecondary)
            }
        }
    }

    private func thumbContainer(_ ui: UIImage) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: thumbCornerRadius, style: .continuous)
                .fill(Color.white.opacity(0.55))

            Image(uiImage: ui)
                .resizable()
                .scaledToFill()
                .frame(width: thumbSide, height: thumbSide)
        }
        .frame(width: thumbSide, height: thumbSide)
        .clipShape(RoundedRectangle(cornerRadius: thumbCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: thumbCornerRadius, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
        .padding(.leading, 2)
        .accessibilityLabel("Task photo")
    }

    private var doneOverlay: some View {
        RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
            .stroke(
                DS.ColorToken.textSecondary.opacity(model.isMuted ? 0.22 : 0.0),
                lineWidth: 1
            )
    }

    private func badgePill(text: String, isMuted: Bool) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(DS.ColorToken.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(DS.ColorToken.textSecondary.opacity(isMuted ? 0.10 : 0.14))
            )
    }
}

struct ImportedIndicatorPill: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "applelogo")
                .font(.system(size: 11, weight: .semibold))
            Text("Imported")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(DS.ColorToken.textSecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(DS.ColorToken.textSecondary.opacity(0.12))
        )
        .accessibilityLabel("Imported from Apple Calendar")
    }
}

// MARK: - TaskColor mapping for external colors

extension Color {
    fileprivate func uiRGBA() -> (CGFloat, CGFloat, CGFloat, CGFloat)? {
        let ui = UIColor(self)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        guard ui.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        return (r, g, b, a)
    }
}

extension TaskColor {
    var sortIndex: Int { TaskColor.allCases.firstIndex(of: self) ?? 0 }

    static func closest(to external: Color) -> TaskColor {
        guard let (er, eg, eb, _) = external.uiRGBA() else { return .blue }

        var best: TaskColor = .blue
        var bestD: CGFloat = .greatestFiniteMagnitude

        for c in TaskColor.allCases {
            guard let (r, g, b, _) = c.uiColor.uiRGBA() else { continue }
            let dr = r - er
            let dg = g - eg
            let db = b - eb
            let d = dr*dr + dg*dg + db*db
            if d < bestD {
                bestD = d
                best = c
            }
        }
        return best
    }
}
