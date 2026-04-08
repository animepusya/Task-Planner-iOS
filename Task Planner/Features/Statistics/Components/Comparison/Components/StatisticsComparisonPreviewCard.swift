//
//  StatisticsComparisonPreviewCard.swift
//  Task Planner
//
//  Created by Codex on 08.04.2026.
//

import SwiftUI

struct StatisticsComparisonPreviewCard: View {
    let snapshot: StatisticsComparisonSnapshot
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
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
            .dsCard(padding: DS.Spacing.lg, cornerRadius: DS.Radius.lg) {
                DS.Surface.card
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(StatisticsComparisonPreviewButtonStyle())
    }

    private var header: some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(snapshot.title)
                        .font(DS.Typography.sectionTitle)
                        .foregroundStyle(DS.ColorToken.textPrimary)

                    ProBadge(size: .small)
                }

                Text(snapshot.subtitle)
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.ColorToken.textSecondary)
            }

            Spacer(minLength: 12)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DS.ColorToken.textSecondary)
                .frame(width: 30, height: 30)
                .background(DS.ColorToken.controlFill, in: Circle())
        }
    }

    private var readyContent: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text(snapshot.totalDeltaText ?? "")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(DS.ColorToken.textPrimary)

                if let caption = snapshot.totalDeltaCaption {
                    Text(caption)
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.ColorToken.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
            }

            Divider().opacity(0.15)

            VStack(spacing: 10) {
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
        HStack(spacing: 12) {
            ProgressView()
                .tint(DS.ColorToken.purple)

            Text(snapshot.message ?? "")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.ColorToken.textSecondary)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)
        }
    }

    private var emptyContent: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(DS.ColorToken.controlFill)
                .frame(width: 34, height: 34)
                .overlay(
                    Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DS.ColorToken.textSecondary)
                )

            Text(snapshot.message ?? "")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.ColorToken.textSecondary)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)
        }
    }

    private func insightLine(_ insight: StatisticsComparisonPreviewInsightSnapshot) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(insight.direction.backgroundColor)
                .frame(width: 10, height: 10)
                .overlay(
                    Circle()
                        .stroke(insight.direction.tintColor.opacity(0.35), lineWidth: 1)
                )

            Text(insight.label)
                .font(DS.Typography.caption)
                .foregroundStyle(DS.ColorToken.textSecondary)

            Spacer(minLength: 8)

            Text(insight.contentText)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
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
