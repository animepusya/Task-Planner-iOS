//
//  StatisticsComparisonSnapshot.swift
//  Task Planner
//
//  Created by Codex on 08.04.2026.
//

import SwiftUI

enum StatisticsComparisonAvailability: Sendable, Equatable {
    case loading
    case insufficientData
    case ready
}

enum StatisticsComparisonDirection: Sendable, Equatable {
    case increase
    case decrease
    case neutral
}

extension StatisticsComparisonDirection {
    var symbolName: String {
        switch self {
        case .increase:
            return "arrow.up.right"
        case .decrease:
            return "arrow.down.right"
        case .neutral:
            return "minus"
        }
    }

    var tintColor: Color {
        switch self {
        case .increase:
            return DS.ColorToken.purple
        case .decrease:
            return Color(red: 0.83, green: 0.34, blue: 0.37)
        case .neutral:
            return DS.ColorToken.textSecondary
        }
    }

    var backgroundColor: Color {
        switch self {
        case .neutral:
            return DS.ColorToken.controlFill
        case .increase, .decrease:
            return tintColor.opacity(0.12)
        }
    }
}

struct StatisticsComparisonPreviewInsightSnapshot: Identifiable {
    let id: String
    let label: String
    let contentText: String
    let direction: StatisticsComparisonDirection
}

struct StatisticsComparisonMetricSnapshot: Identifiable {
    let id: String
    let title: String
    let valueText: String
    let subtitle: String?
    let direction: StatisticsComparisonDirection
    let showsTrendIndicator: Bool
}

struct StatisticsComparisonDeltaRowSnapshot: Identifiable {
    let id: String
    let title: String
    let deltaMinutes: Int
    let currentMinutes: Int
    let previousMinutes: Int
    let deltaText: String
    let percentText: String?
    let currentValueText: String
    let previousValueText: String
    let direction: StatisticsComparisonDirection
    let color: Color
}

struct StatisticsComparisonSnapshot {
    let title: String
    let subtitle: String
    let mode: StatisticsComparisonMode
    let availability: StatisticsComparisonAvailability
    let message: String?
    let currentPeriodTitle: String
    let previousPeriodTitle: String
    let totalDeltaText: String?
    let totalDeltaCaption: String?
    let currentTotalText: String
    let previousTotalText: String
    let metrics: [StatisticsComparisonMetricSnapshot]
    let categoryRows: [StatisticsComparisonDeltaRowSnapshot]
    let taskRows: [StatisticsComparisonDeltaRowSnapshot]
    let growthInsight: StatisticsComparisonPreviewInsightSnapshot?
    let dropInsight: StatisticsComparisonPreviewInsightSnapshot?

    var isLoading: Bool {
        availability == .loading
    }

    var showsEmptyState: Bool {
        availability == .insufficientData
    }

    static func placeholder(
        currentContext: StatisticsPeriodContext,
        comparedContext: StatisticsPeriodContext,
        mode: StatisticsComparisonMode
    ) -> StatisticsComparisonSnapshot {
        StatisticsComparisonSnapshot(
            title: String(localized: "Comparison"),
            subtitle: StatisticsPeriodContextBuilder.comparisonSubtitle(
                for: currentContext.range,
                mode: mode
            ),
            mode: mode,
            availability: .loading,
            message: String(localized: "Preparing comparison..."),
            currentPeriodTitle: currentContext.displayedTitle,
            previousPeriodTitle: comparedContext.displayedTitle,
            totalDeltaText: nil,
            totalDeltaCaption: nil,
            currentTotalText: 0.formattedHoursMinutes(),
            previousTotalText: 0.formattedHoursMinutes(),
            metrics: [],
            categoryRows: [],
            taskRows: [],
            growthInsight: nil,
            dropInsight: nil
        )
    }
}
