//
//  PlannerCardView.swift
//  Task Planner
//
//  Created by Руслан Меланин on 03.03.2026.
//

import SwiftUI
import UIKit

struct PlannerCardModel: Hashable {
    enum ColorTreatment: Hashable {
        case fullSurface
        case subtleAccent
    }

    let title: String
    let subtitle: String
    let timeText: String
    let badgeText: String?
    let thumb: UIImage?

    let surfaceColor: Color
    let colorTreatment: ColorTreatment
    let isMuted: Bool
}

struct PlannerCardView<TopRight: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dsAdaptiveMetrics) private var dsMetrics

    let model: PlannerCardModel
    @ViewBuilder let topRight: () -> TopRight

    private var surfaceOpacity: Double { model.isMuted ? 0.16 : 0.40 }
    private let doneAnim: Animation = .easeInOut(duration: 0.18)

    var body: some View {
        HStack(spacing: dsMetrics.spacing(12)) {
            leadingContent

            Spacer(minLength: 0)

            if let thumb = model.thumb {
                thumbContainer(thumb)
            }
        }
        .padding(.vertical, dsMetrics.spacing(DS.Spacing.md))
        .padding(.trailing, dsMetrics.spacing(DS.Spacing.md))
        .padding(.leading, dsMetrics.spacing(DS.Spacing.sm))
        .dsCard(padding: 0) {
            cardBackground
        }
        .overlay(doneOverlay)
        .saturation(model.isMuted ? 0.35 : 1.0)
        .grayscale(model.isMuted ? 0.25 : 0.0)
        .scaleEffect(model.isMuted ? 0.995 : 1.0)
        .animation(doneAnim, value: model.isMuted)
    }


    private var leadingContent: some View {
        HStack(spacing: usesDarkAccentTreatment ? dsMetrics.spacing(DS.Spacing.sm) : 0) {
            if usesDarkAccentTreatment {
                accentBar
            }

            contentLeft
        }
    }

    private var contentLeft: some View {
        VStack(alignment: .leading, spacing: dsMetrics.spacing(6)) {
            HStack(spacing: dsMetrics.spacing(8)) {
                Text(model.title)
                    .font(
                        dsMetrics.font(
                            15,
                            weight: .semibold,
                            category: .body
                        )
                    )
                    .foregroundStyle(model.isMuted ? DS.ColorToken.textSecondary : DS.ColorToken.textPrimary)
                    .strikethrough(model.isMuted, color: DS.ColorToken.textSecondary.opacity(0.85))

                if let badge = model.badgeText {
                    badgePill(text: badge, isMuted: model.isMuted)
                }

                Spacer(minLength: 0)

                topRight()
            }

            Text(model.subtitle)
                .font(
                    dsMetrics.font(
                        12,
                        weight: .medium,
                        category: .caption
                    )
                )
                .foregroundStyle(DS.ColorToken.textSecondary)
                .lineLimit(1)

            HStack(spacing: dsMetrics.spacing(6)) {
                Image(systemName: "clock")
                    .font(
                        dsMetrics.font(
                            12,
                            weight: .semibold,
                            category: .micro
                        )
                    )
                    .foregroundStyle(DS.ColorToken.textSecondary)

                Text(model.timeText)
                    .font(
                        dsMetrics.font(
                            12,
                            weight: .medium,
                            category: .caption
                        )
                    )
                    .foregroundStyle(DS.ColorToken.textSecondary)
            }
        }
    }

    private func thumbContainer(_ ui: UIImage) -> some View {
        let thumbSide = dsMetrics.controlSize(52)
        let thumbCornerRadius = dsMetrics.cornerRadius(DS.Radius.sm)

        return ZStack {
            RoundedRectangle(cornerRadius: thumbCornerRadius, style: .continuous)
                .fill(DS.Surface.chrome)

            Image(uiImage: ui)
                .resizable()
                .scaledToFill()
                .frame(width: thumbSide, height: thumbSide)
        }
        .frame(width: thumbSide, height: thumbSide)
        .clipShape(RoundedRectangle(cornerRadius: thumbCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: thumbCornerRadius, style: .continuous)
                .stroke(DS.Border.subtle, lineWidth: 1)
        )
        .padding(.leading, dsMetrics.spacing(2))
        .accessibilityLabel("Task photo")
    }

    @ViewBuilder
    private var cardBackground: some View {
        if usesDarkAccentTreatment {
            ZStack {
                DS.Surface.card
                model.surfaceColor.opacity(model.isMuted ? 0.07 : 0.12)
            }
        } else {
            model.surfaceColor.opacity(surfaceOpacity)
        }
    }

    private var accentBar: some View {
        RoundedRectangle(cornerRadius: dsMetrics.detailSize(3), style: .continuous)
            .fill(model.surfaceColor.opacity(model.isMuted ? 0.45 : 0.96))
            .frame(
                width: dsMetrics.detailSize(4),
                height: dsMetrics.controlSize(58)
            )
            .shadow(
                color: model.surfaceColor.opacity(model.isMuted ? 0.0 : 0.24),
                radius: dsMetrics.spacing(10),
                x: 0,
                y: 0
            )
    }

    private var doneOverlay: some View {
        RoundedRectangle(
            cornerRadius: dsMetrics.cornerRadius(DS.Radius.md),
            style: .continuous
        )
            .stroke(
                DS.ColorToken.textSecondary.opacity(model.isMuted ? 0.22 : 0.0),
                lineWidth: dsMetrics.strokeWidth(1)
            )
    }

    private var usesDarkAccentTreatment: Bool {
        colorScheme == .dark && model.colorTreatment == .subtleAccent
    }

    private func badgePill(text: String, isMuted: Bool) -> some View {
        Text(text)
            .font(
                dsMetrics.font(
                    12,
                    weight: .semibold,
                    category: .micro
                )
            )
            .foregroundStyle(DS.ColorToken.textSecondary)
            .padding(.horizontal, dsMetrics.spacing(10))
            .padding(.vertical, dsMetrics.spacing(4))
            .background(
                Capsule()
                    .fill(DS.ColorToken.textSecondary.opacity(isMuted ? 0.10 : 0.14))
            )
    }
}

struct ImportedIndicatorPill: View {
    @Environment(\.dsAdaptiveMetrics) private var dsMetrics

    var body: some View {
        HStack(spacing: dsMetrics.spacing(6)) {
            Image(systemName: "applelogo")
                .font(
                    dsMetrics.font(
                        11,
                        weight: .semibold,
                        category: .micro
                    )
                )
            Text("Imported")
                .font(
                    dsMetrics.font(
                        11,
                        weight: .semibold,
                        category: .micro
                    )
                )
        }
        .foregroundStyle(DS.ColorToken.textSecondary)
        .padding(.horizontal, dsMetrics.spacing(10))
        .padding(.vertical, dsMetrics.spacing(4))
        .background(
            Capsule()
                .fill(DS.ColorToken.textSecondary.opacity(0.12))
        )
        .accessibilityLabel("Imported from Apple Calendar")
    }
}
