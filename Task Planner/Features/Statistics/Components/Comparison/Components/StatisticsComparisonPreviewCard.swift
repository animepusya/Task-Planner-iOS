//
//  StatisticsComparisonPreviewCard.swift
//  Task Planner
//
//  Created by Codex on 08.04.2026.
//

import SwiftUI

struct StatisticsComparisonPreviewCard: View {
    @Environment(\.dsAdaptiveMetrics) private var dsMetrics

    let snapshot: StatisticsComparisonSnapshot
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: dsMetrics.spacing(DS.Spacing.md)) {
                header

                switch snapshot.availability {
                case .ready:
                    readyContent
                case .loading:
                    loadingContent
                case .insufficientData:
                    emptyContent
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .dsPrimaryCard(padding: DS.Spacing.lg, cornerRadius: DS.Radius.lg)
            .contentShape(Rectangle())
        }
        .buttonStyle(StatisticsComparisonPreviewButtonStyle())
    }

    private var header: some View {
        HStack(alignment: .top, spacing: dsMetrics.spacing(DS.Spacing.sm)) {
            VStack(alignment: .leading, spacing: dsMetrics.spacing(4)) {
                HStack(spacing: dsMetrics.spacing(8)) {
                    Text(snapshot.title)
                        .font(
                            dsMetrics.font(
                                18,
                                weight: .semibold,
                                category: .title
                            )
                        )
                        .foregroundStyle(DS.ColorToken.textPrimary)

                    ProBadge(size: .small)
                }

                Text(snapshot.subtitle)
                    .font(
                        dsMetrics.font(
                            12,
                            weight: .medium,
                            category: .caption
                        )
                    )
                    .foregroundStyle(DS.ColorToken.textSecondary)
            }

            Spacer(minLength: dsMetrics.spacing(12))

            Image(systemName: "chevron.right")
                .font(
                    dsMetrics.font(
                        13,
                        weight: .semibold,
                        category: .micro
                    )
                )
                .foregroundStyle(DS.ColorToken.textSecondary)
                .frame(
                    width: dsMetrics.controlSize(30),
                    height: dsMetrics.controlSize(30)
                )
                .background(DS.ColorToken.controlFill, in: Circle())
        }
    }

    private var readyContent: some View {
        VStack(alignment: .leading, spacing: dsMetrics.spacing(DS.Spacing.md)) {
            VStack(alignment: .leading, spacing: dsMetrics.spacing(4)) {
                Text(snapshot.totalDeltaText ?? "")
                    .font(
                        dsMetrics.font(
                            28,
                            weight: .bold,
                            category: .display
                        )
                    )
                    .foregroundStyle(DS.ColorToken.textPrimary)

                if let caption = snapshot.totalDeltaCaption {
                    Text(caption)
                        .font(
                            dsMetrics.font(
                                12,
                                weight: .medium,
                                category: .caption
                            )
                        )
                        .foregroundStyle(DS.ColorToken.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
            }

            Divider().opacity(0.15)

            VStack(spacing: dsMetrics.spacing(10)) {
                if let growthInsight = snapshot.growthInsight {
                    insightLine(growthInsight)
                }

                if let dropInsight = snapshot.dropInsight {
                    insightLine(dropInsight)
                }
            }
        }
    }

    private var loadingContent: some View {
        HStack(spacing: dsMetrics.spacing(12)) {
            ProgressView()
                .tint(DS.ColorToken.purple)

            Text(snapshot.message ?? "")
                .font(
                    dsMetrics.font(
                        12,
                        weight: .medium,
                        category: .caption
                    )
                )
                .foregroundStyle(DS.ColorToken.textSecondary)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)
        }
    }

    private var emptyContent: some View {
        HStack(spacing: dsMetrics.spacing(12)) {
            Circle()
                .fill(DS.ColorToken.controlFill)
                .frame(
                    width: dsMetrics.controlSize(34),
                    height: dsMetrics.controlSize(34)
                )
                .overlay(
                    Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                        .font(
                            dsMetrics.font(
                                13,
                                weight: .semibold,
                                category: .micro
                            )
                        )
                        .foregroundStyle(DS.ColorToken.textSecondary)
                )

            Text(snapshot.message ?? "")
                .font(
                    dsMetrics.font(
                        12,
                        weight: .medium,
                        category: .caption
                    )
                )
                .foregroundStyle(DS.ColorToken.textSecondary)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)
        }
    }

    private func insightLine(_ insight: StatisticsComparisonPreviewInsightSnapshot) -> some View {
        HStack(spacing: dsMetrics.spacing(10)) {
            Circle()
                .fill(insight.direction.backgroundColor)
                .frame(
                    width: dsMetrics.spacing(10),
                    height: dsMetrics.spacing(10)
                )
                .overlay(
                    Circle()
                        .stroke(
                            insight.direction.tintColor.opacity(0.35),
                            lineWidth: dsMetrics.strokeWidth(1)
                        )
                )

            Text(insight.label)
                .font(
                    dsMetrics.font(
                        12,
                        weight: .medium,
                        category: .caption
                    )
                )
                .foregroundStyle(DS.ColorToken.textSecondary)

            Spacer(minLength: dsMetrics.spacing(8))

            Text(insight.contentText)
                .font(
                    dsMetrics.font(
                        13,
                        weight: .semibold,
                        category: .micro
                    )
                )
                .foregroundStyle(
                    insight.direction == .neutral
                    ? DS.ColorToken.textSecondary
                    : DS.ColorToken.textPrimary
                )
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

private struct StatisticsComparisonPreviewButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.95 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.988 : 1.0)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}
