//
//  StatisticsComparisonBuilder.swift
//  Task Planner
//
//  Created by Codex on 08.04.2026.
//

import SwiftUI

enum StatisticsComparisonBuilder {
    nonisolated static func build(
        currentResult: StatisticsComputedResult,
        previousResult: StatisticsComputedResult,
        currentContext: StatisticsPeriodContext,
        comparedContext: StatisticsPeriodContext,
        mode: StatisticsComparisonMode = .previousEquivalent
    ) -> StatisticsComparisonSnapshot {
        let currentTotalText = currentResult.totalMinutes.formattedHoursMinutes()
        let previousTotalText = previousResult.totalMinutes.formattedHoursMinutes()
        let subtitle = StatisticsPeriodContextBuilder.comparisonSubtitle(
            for: currentContext.range,
            mode: mode
        )

        guard previousResult.totalMinutes > 0 else {
            let reference = StatisticsPeriodContextBuilder.comparisonReferenceText(
                for: currentContext.range,
                mode: mode
            )
            let message = String.localizedStringWithFormat(
                String(localized: "Add tracked time in the %@ to compare periods."),
                reference
            )

            return StatisticsComparisonSnapshot(
                title: String(localized: "Comparison"),
                subtitle: subtitle,
                mode: mode,
                availability: .insufficientData,
                message: message,
                currentPeriodTitle: currentContext.displayedTitle,
                previousPeriodTitle: comparedContext.displayedTitle,
                totalDeltaText: nil,
                totalDeltaCaption: nil,
                currentTotalText: currentTotalText,
                previousTotalText: previousTotalText,
                metrics: [
                    StatisticsComparisonMetricSnapshot(
                        id: "delta",
                        title: String(localized: "Total change"),
                        valueText: String(localized: "Not enough data"),
                        subtitle: message,
                        direction: .neutral,
                        showsTrendIndicator: true
                    ),
                    StatisticsComparisonMetricSnapshot(
                        id: "current",
                        title: String(localized: "Current total"),
                        valueText: currentTotalText,
                        subtitle: currentContext.displayedTitle,
                        direction: .neutral,
                        showsTrendIndicator: false
                    ),
                    StatisticsComparisonMetricSnapshot(
                        id: "previous",
                        title: String(localized: "Previous total"),
                        valueText: previousTotalText,
                        subtitle: comparedContext.displayedTitle,
                        direction: .neutral,
                        showsTrendIndicator: false
                    )
                ],
                categoryRows: [],
                taskRows: [],
                growthInsight: nil,
                dropInsight: nil
            )
        }

        let totalDeltaMinutes = currentResult.totalMinutes - previousResult.totalMinutes
        let totalDeltaText = percentText(
            currentMinutes: currentResult.totalMinutes,
            previousMinutes: previousResult.totalMinutes
        ) ?? "0%"
        let totalDeltaCaption = String.localizedStringWithFormat(
            String(localized: "%@ now vs %@ before"),
            currentTotalText,
            previousTotalText
        )

        let categoryRows = buildCategoryRows(
            current: currentResult.categoryStats,
            previous: previousResult.categoryStats
        )
        let taskRows = buildTaskRows(
            current: currentResult.taskStats,
            previous: previousResult.taskStats
        )

        return StatisticsComparisonSnapshot(
            title: String(localized: "Comparison"),
            subtitle: subtitle,
            mode: mode,
            availability: .ready,
            message: nil,
            currentPeriodTitle: currentContext.displayedTitle,
            previousPeriodTitle: comparedContext.displayedTitle,
            totalDeltaText: totalDeltaText,
            totalDeltaCaption: totalDeltaCaption,
            currentTotalText: currentTotalText,
            previousTotalText: previousTotalText,
            metrics: [
                StatisticsComparisonMetricSnapshot(
                    id: "delta",
                    title: String(localized: "Total change"),
                    valueText: totalDeltaText,
                    subtitle: totalDeltaCaption,
                    direction: direction(for: totalDeltaMinutes),
                    showsTrendIndicator: true
                ),
                StatisticsComparisonMetricSnapshot(
                    id: "current",
                    title: String(localized: "Current total"),
                    valueText: currentTotalText,
                    subtitle: currentContext.displayedTitle,
                    direction: .neutral,
                    showsTrendIndicator: false
                ),
                StatisticsComparisonMetricSnapshot(
                    id: "previous",
                    title: String(localized: "Previous total"),
                    valueText: previousTotalText,
                    subtitle: comparedContext.displayedTitle,
                    direction: .neutral,
                    showsTrendIndicator: false
                )
            ],
            categoryRows: categoryRows,
            taskRows: taskRows,
            growthInsight: growthInsight(from: categoryRows),
            dropInsight: dropInsight(from: categoryRows)
        )
    }

    nonisolated private static func buildCategoryRows(
        current: [CategoryStat],
        previous: [CategoryStat]
    ) -> [StatisticsComparisonDeltaRowSnapshot] {
        buildRows(
            current: current.map {
                DeltaSource(
                    id: $0.id,
                    title: $0.name,
                    minutes: $0.minutes,
                    colorRaw: $0.colorRaw
                )
            },
            previous: previous.map {
                DeltaSource(
                    id: $0.id,
                    title: $0.name,
                    minutes: $0.minutes,
                    colorRaw: $0.colorRaw
                )
            }
        )
    }

    nonisolated private static func buildTaskRows(
        current: [TaskStat],
        previous: [TaskStat]
    ) -> [StatisticsComparisonDeltaRowSnapshot] {
        buildRows(
            current: current.map {
                DeltaSource(
                    id: $0.id,
                    title: $0.title,
                    minutes: $0.minutes,
                    colorRaw: $0.colorRaw
                )
            },
            previous: previous.map {
                DeltaSource(
                    id: $0.id,
                    title: $0.title,
                    minutes: $0.minutes,
                    colorRaw: $0.colorRaw
                )
            }
        )
    }

    nonisolated private static func buildRows(
        current: [DeltaSource],
        previous: [DeltaSource]
    ) -> [StatisticsComparisonDeltaRowSnapshot] {
        var merged: [String: MergedDeltaSource] = [:]
        merged.reserveCapacity(current.count + previous.count)

        for item in previous {
            merged[item.id] = MergedDeltaSource(
                id: item.id,
                title: item.title,
                currentMinutes: 0,
                previousMinutes: item.minutes,
                colorRaw: item.colorRaw
            )
        }

        for item in current {
            if var existing = merged[item.id] {
                existing.title = item.title
                existing.currentMinutes = item.minutes
                if existing.colorRaw.isEmpty {
                    existing.colorRaw = item.colorRaw
                } else if item.minutes >= existing.previousMinutes {
                    existing.colorRaw = item.colorRaw
                }
                merged[item.id] = existing
            } else {
                merged[item.id] = MergedDeltaSource(
                    id: item.id,
                    title: item.title,
                    currentMinutes: item.minutes,
                    previousMinutes: 0,
                    colorRaw: item.colorRaw
                )
            }
        }

        return merged.values
            .compactMap { item in
                let deltaMinutes = item.currentMinutes - item.previousMinutes
                guard deltaMinutes != 0 else { return nil }

                return StatisticsComparisonDeltaRowSnapshot(
                    id: item.id,
                    title: item.title,
                    deltaMinutes: deltaMinutes,
                    currentMinutes: item.currentMinutes,
                    previousMinutes: item.previousMinutes,
                    deltaText: deltaMinutes.formattedSignedHoursMinutes(),
                    percentText: percentText(
                        currentMinutes: item.currentMinutes,
                        previousMinutes: item.previousMinutes
                    ),
                    currentValueText: item.currentMinutes.formattedHoursMinutes(),
                    previousValueText: item.previousMinutes.formattedHoursMinutes(),
                    direction: direction(for: deltaMinutes),
                    color: StatisticsPresentationColor.color(forRawValue: item.colorRaw)
                )
            }
            .sorted(by: rowSort)
    }

    nonisolated private static func growthInsight(
        from rows: [StatisticsComparisonDeltaRowSnapshot]
    ) -> StatisticsComparisonPreviewInsightSnapshot {
        if let row = rows
            .filter({ $0.deltaMinutes > 0 })
            .max(by: { $0.deltaMinutes < $1.deltaMinutes }) {
            return StatisticsComparisonPreviewInsightSnapshot(
                id: "growth",
                label: String(localized: "Biggest growth"),
                contentText: "\(row.title) \(row.deltaText)",
                direction: .increase
            )
        }

        return StatisticsComparisonPreviewInsightSnapshot(
            id: "growth",
            label: String(localized: "Biggest growth"),
            contentText: String(localized: "No growth yet"),
            direction: .neutral
        )
    }

    nonisolated private static func dropInsight(
        from rows: [StatisticsComparisonDeltaRowSnapshot]
    ) -> StatisticsComparisonPreviewInsightSnapshot {
        if let row = rows
            .filter({ $0.deltaMinutes < 0 })
            .min(by: { $0.deltaMinutes < $1.deltaMinutes }) {
            return StatisticsComparisonPreviewInsightSnapshot(
                id: "drop",
                label: String(localized: "Biggest drop"),
                contentText: "\(row.title) \(row.deltaText)",
                direction: .decrease
            )
        }

        return StatisticsComparisonPreviewInsightSnapshot(
            id: "drop",
            label: String(localized: "Biggest drop"),
            contentText: String(localized: "No drop yet"),
            direction: .neutral
        )
    }

    nonisolated private static func rowSort(
        lhs: StatisticsComparisonDeltaRowSnapshot,
        rhs: StatisticsComparisonDeltaRowSnapshot
    ) -> Bool {
        let lhsImpact = abs(lhs.deltaMinutes)
        let rhsImpact = abs(rhs.deltaMinutes)

        if lhsImpact != rhsImpact {
            return lhsImpact > rhsImpact
        }

        if lhs.currentMinutes != rhs.currentMinutes {
            return lhs.currentMinutes > rhs.currentMinutes
        }

        return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
    }

    nonisolated private static func direction(for deltaMinutes: Int) -> StatisticsComparisonDirection {
        if deltaMinutes > 0 {
            return .increase
        }

        if deltaMinutes < 0 {
            return .decrease
        }

        return .neutral
    }

    nonisolated private static func percentText(
        currentMinutes: Int,
        previousMinutes: Int
    ) -> String? {
        guard previousMinutes > 0 else { return nil }
        let ratio = Double(currentMinutes - previousMinutes) / Double(previousMinutes)
        let roundedPercent = Int((ratio * 100.0).rounded())

        if roundedPercent > 0 {
            return "+\(roundedPercent)%"
        }

        return "\(roundedPercent)%"
    }
}

private struct DeltaSource {
    let id: String
    let title: String
    let minutes: Int
    let colorRaw: String
}

private struct MergedDeltaSource {
    let id: String
    var title: String
    var currentMinutes: Int
    var previousMinutes: Int
    var colorRaw: String
}
