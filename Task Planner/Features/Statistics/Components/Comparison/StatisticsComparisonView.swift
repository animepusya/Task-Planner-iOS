//
//  StatisticsComparisonView.swift
//  Task Planner
//
//  Created by Codex on 08.04.2026.
//

import SwiftUI

struct StatisticsComparisonView: View {
    @ObservedObject var viewModel: StatisticsViewModel
    @Environment(\.dsAdaptiveMetrics) private var dsMetrics

    var body: some View {
        let snapshot = viewModel.snapshot.comparison

        ZStack {
            AppBackgroundView(
                gradient: DS.GradientToken.pinkPurpleSoft,
                gradientOpacity: 0.55,
                blurRadius: 22
            )

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: dsMetrics.spacing(DS.Spacing.lg)) {
                    StatisticsPeriodCard(viewModel: viewModel)
                    summaryCard(snapshot)

                    if snapshot.isLoading, let message = snapshot.message {
                        stateCard(message: message, showsProgress: true)
                    } else if snapshot.showsEmptyState, let message = snapshot.message {
                        stateCard(message: message, showsProgress: false)
                    } else {
                        if snapshot.categoryRows.isEmpty == false {
                            deltaSection(
                                title: StatisticsBreakdown.category.title,
                                rows: snapshot.categoryRows
                            )
                        }

                        if snapshot.taskRows.isEmpty == false {
                            deltaSection(
                                title: StatisticsBreakdown.task.title,
                                rows: snapshot.taskRows
                            )
                        }

                        if snapshot.categoryRows.isEmpty && snapshot.taskRows.isEmpty {
                            stateCard(
                                message: String(localized: "No category or task changes yet."),
                                showsProgress: false
                            )
                        }
                    }
                }
                .padding(.horizontal, dsMetrics.screenPadding(DS.Spacing.lg))
                .padding(.top, dsMetrics.spacing(DS.Spacing.lg))
                .padding(.bottom, dsMetrics.spacing(DS.Spacing.xl))
                .dsContentFrame(.screen)
            }
        }
        .navigationTitle(snapshot.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func summaryCard(_ snapshot: StatisticsComparisonSnapshot) -> some View {
        VStack(alignment: .leading, spacing: dsMetrics.spacing(DS.Spacing.md)) {
            HStack(alignment: .top, spacing: dsMetrics.spacing(DS.Spacing.md)) {
                VStack(alignment: .leading, spacing: dsMetrics.spacing(6)) {
                    Text(snapshot.subtitle)
                        .font(
                            dsMetrics.font(
                                12,
                                weight: .medium,
                                category: .caption
                            )
                        )
                        .foregroundStyle(DS.ColorToken.textSecondary)

                    Text(summaryValue(for: snapshot))
                        .font(
                            dsMetrics.font(
                                28,
                                weight: .bold,
                                category: .display
                            )
                        )
                        .foregroundStyle(DS.ColorToken.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)

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
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: dsMetrics.spacing(12))

                if let totalDeltaText = snapshot.totalDeltaText {
                    trendBadge(
                        text: totalDeltaText,
                        direction: snapshot.totalDeltaDirection
                    )
                }
            }

            Divider().opacity(0.15)

            HStack(alignment: .top, spacing: dsMetrics.spacing(DS.Spacing.md)) {
                periodColumn(
                    label: String(localized: "Current period"),
                    title: snapshot.currentPeriodTitle,
                    value: snapshot.currentTotalText
                )

                Divider()
                    .frame(height: dsMetrics.controlSize(54))
                    .opacity(0.12)

                periodColumn(
                    label: String(localized: "Previous period"),
                    title: snapshot.previousPeriodTitle,
                    value: snapshot.previousTotalText
                )
            }
        }
        .dsPrimaryCard(padding: DS.Spacing.lg, cornerRadius: DS.Radius.lg)
    }

    private func deltaSection(
        title: String,
        rows: [StatisticsComparisonDeltaRowSnapshot]
    ) -> some View {
        VStack(alignment: .leading, spacing: dsMetrics.spacing(DS.Spacing.md)) {
            Text(title)
                .font(
                    dsMetrics.font(
                        18,
                        weight: .semibold,
                        category: .title
                    )
                )
                .foregroundStyle(DS.ColorToken.textPrimary)

            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    deltaRow(row)

                    if index < rows.count - 1 {
                        Divider()
                            .padding(.leading, dsMetrics.spacing(DS.Spacing.md))
                    }
                }
            }
            .dsPrimaryCard(padding: 0, cornerRadius: DS.Radius.lg)
        }
    }

    private func deltaRow(_ row: StatisticsComparisonDeltaRowSnapshot) -> some View {
        VStack(alignment: .leading, spacing: dsMetrics.spacing(10)) {
            HStack(alignment: .top, spacing: dsMetrics.spacing(10)) {
                Circle()
                    .fill(row.color)
                    .frame(width: dsMetrics.spacing(12), height: dsMetrics.spacing(12))
                    .padding(.top, dsMetrics.spacing(5))

                VStack(alignment: .leading, spacing: dsMetrics.spacing(4)) {
                    Text(row.title)
                        .font(
                            dsMetrics.font(
                                15,
                                weight: .regular,
                                category: .body
                            )
                        )
                        .foregroundStyle(DS.ColorToken.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Text(
                        String.localizedStringWithFormat(
                            String(localized: "Current %@ / Previous %@"),
                            row.currentValueText,
                            row.previousValueText
                        )
                    )
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

                VStack(alignment: .trailing, spacing: dsMetrics.spacing(4)) {
                    trendBadge(text: row.deltaText, direction: row.direction)

                    if let percentText = row.percentText {
                        Text(percentText)
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
        }
        .padding(.horizontal, dsMetrics.spacing(DS.Spacing.md))
        .padding(.vertical, dsMetrics.spacing(14))
    }

    private func stateCard(
        message: String,
        showsProgress: Bool
    ) -> some View {
        HStack(spacing: dsMetrics.spacing(12)) {
            if showsProgress {
                ProgressView()
                    .tint(DS.ColorToken.purple)
            } else {
                Circle()
                    .fill(DS.ColorToken.controlFill)
                    .frame(
                        width: dsMetrics.controlSize(30),
                        height: dsMetrics.controlSize(30)
                    )
                    .overlay(
                        Image(systemName: "sparkles")
                            .font(
                                dsMetrics.font(
                                    12,
                                    weight: .semibold,
                                    category: .micro
                                )
                            )
                            .foregroundStyle(DS.ColorToken.textSecondary)
                    )
            }

            Text(message)
                .font(
                    dsMetrics.font(
                        12,
                        weight: .medium,
                        category: .caption
                    )
                )
                .foregroundStyle(DS.ColorToken.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .dsPrimaryCard(padding: DS.Spacing.md, cornerRadius: DS.Radius.md)
    }

    private func periodColumn(
        label: String,
        title: String,
        value: String
    ) -> some View {
        VStack(alignment: .leading, spacing: dsMetrics.spacing(4)) {
            Text(label)
                .font(
                    dsMetrics.font(
                        12,
                        weight: .medium,
                        category: .caption
                    )
                )
                .foregroundStyle(DS.ColorToken.textSecondary)

            Text(title)
                .font(
                    dsMetrics.font(
                        15,
                        weight: .semibold,
                        category: .body
                    )
                )
                .foregroundStyle(DS.ColorToken.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(value)
                .font(
                    dsMetrics.font(
                        18,
                        weight: .bold,
                        category: .title
                    )
                )
                .foregroundStyle(DS.ColorToken.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func trendBadge(
        text: String,
        direction: StatisticsComparisonDirection
    ) -> some View {
        HStack(spacing: dsMetrics.spacing(6)) {
            Image(systemName: direction.symbolName)
                .font(
                    dsMetrics.font(
                        11,
                        weight: .semibold,
                        category: .micro
                    )
                )

            Text(text)
                .font(
                    dsMetrics.font(
                        13,
                        weight: .semibold,
                        category: .micro
                    )
                )
        }
        .foregroundStyle(direction.tintColor)
        .padding(.horizontal, dsMetrics.spacing(10))
        .padding(.vertical, dsMetrics.spacing(7))
        .background(direction.backgroundColor, in: Capsule())
    }

    private func summaryValue(for snapshot: StatisticsComparisonSnapshot) -> String {
        if let totalDeltaText = snapshot.totalDeltaText {
            return totalDeltaText
        }

        if snapshot.isLoading {
            return String(localized: "Preparing comparison...")
        }

        return String(localized: "Not enough data")
    }
}
