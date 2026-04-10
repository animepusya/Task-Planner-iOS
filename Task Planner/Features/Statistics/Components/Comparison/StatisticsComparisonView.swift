//
//  StatisticsComparisonView.swift
//  Task Planner
//
//  Created by Codex on 08.04.2026.
//

import SwiftUI

struct StatisticsComparisonView: View {
    @ObservedObject var viewModel: StatisticsViewModel

    var body: some View {
        let snapshot = viewModel.snapshot.comparison

        ZStack {
            AppBackgroundView(
                gradient: DS.GradientToken.pinkPurpleSoft,
                gradientOpacity: 0.55,
                blurRadius: 22
            )

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
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
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.xl)
            }
        }
        .navigationTitle(snapshot.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func summaryCard(_ snapshot: StatisticsComparisonSnapshot) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(alignment: .top, spacing: DS.Spacing.md) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(snapshot.subtitle)
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.ColorToken.textSecondary)

                    Text(summaryValue(for: snapshot))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(DS.ColorToken.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)

                    if let caption = snapshot.totalDeltaCaption {
                        Text(caption)
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.ColorToken.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 12)

                if let totalDeltaText = snapshot.totalDeltaText {
                    trendBadge(
                        text: totalDeltaText,
                        direction: snapshot.totalDeltaDirection
                    )
                }
            }

            Divider().opacity(0.15)

            HStack(alignment: .top, spacing: DS.Spacing.md) {
                periodColumn(
                    label: String(localized: "Current period"),
                    title: snapshot.currentPeriodTitle,
                    value: snapshot.currentTotalText
                )

                Divider()
                    .frame(height: 54)
                    .opacity(0.12)

                periodColumn(
                    label: String(localized: "Previous period"),
                    title: snapshot.previousPeriodTitle,
                    value: snapshot.previousTotalText
                )
            }
        }
        .dsCard(padding: DS.Spacing.lg, cornerRadius: DS.Radius.lg)
    }

    private func deltaSection(
        title: String,
        rows: [StatisticsComparisonDeltaRowSnapshot]
    ) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(title)
                .font(DS.Typography.sectionTitle)
                .foregroundStyle(DS.ColorToken.textPrimary)

            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    deltaRow(row)

                    if index < rows.count - 1 {
                        Divider()
                            .padding(.leading, DS.Spacing.md)
                    }
                }
            }
            .dsCard(padding: 0, cornerRadius: DS.Radius.lg) {
                DS.Surface.card
            }
        }
    }

    private func deltaRow(_ row: StatisticsComparisonDeltaRowSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Circle()
                    .fill(row.color)
                    .frame(width: 12, height: 12)
                    .padding(.top, 5)

                VStack(alignment: .leading, spacing: 4) {
                    Text(row.title)
                        .font(DS.Typography.body)
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
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.ColorToken.textSecondary)
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 4) {
                    trendBadge(text: row.deltaText, direction: row.direction)

                    if let percentText = row.percentText {
                        Text(percentText)
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.ColorToken.textSecondary)
                    }
                }
            }
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, 14)
    }

    private func stateCard(
        message: String,
        showsProgress: Bool
    ) -> some View {
        HStack(spacing: 12) {
            if showsProgress {
                ProgressView()
                    .tint(DS.ColorToken.purple)
            } else {
                Circle()
                    .fill(DS.ColorToken.controlFill)
                    .frame(width: 30, height: 30)
                    .overlay(
                        Image(systemName: "sparkles")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(DS.ColorToken.textSecondary)
                    )
            }

            Text(message)
                .font(DS.Typography.caption)
                .foregroundStyle(DS.ColorToken.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .dsCard(padding: DS.Spacing.md, cornerRadius: DS.Radius.md) {
            DS.Surface.chrome
        }
    }

    private func periodColumn(
        label: String,
        title: String,
        value: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(DS.Typography.caption)
                .foregroundStyle(DS.ColorToken.textSecondary)

            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(DS.ColorToken.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(DS.ColorToken.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func trendBadge(
        text: String,
        direction: StatisticsComparisonDirection
    ) -> some View {
        HStack(spacing: 6) {
            Image(systemName: direction.symbolName)
                .font(.system(size: 11, weight: .semibold))

            Text(text)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(direction.tintColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
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
