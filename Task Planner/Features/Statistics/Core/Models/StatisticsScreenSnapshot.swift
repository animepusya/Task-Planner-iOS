//
//  StatisticsScreenSnapshot.swift
//  Task Planner
//
//  Created by Codex on 21.03.2026.
//

import SwiftUI

@MainActor
enum StatisticsPresentationColor {
    static func color(forRawValue rawValue: String) -> Color {
        TaskColor(rawValue: rawValue)?.uiColor ?? DS.ColorToken.textSecondary
    }
}

struct StatisticsDonutCenterData {
    let title: String
    let valueText: String
}

struct StatisticsTotalRowViewData: Identifiable {
    let id: String
    let name: String
    let minutes: Int
    let minutesText: String
    let percentText: String
    let valueText: String
    let color: Color
}

struct StatisticsBreakdownSnapshot {
    let rows: [StatisticsTotalRowViewData]
    let donutSlices: [DonutChartSlice]
    let defaultCenter: StatisticsDonutCenterData
    let emptyMessage: String

    private let centersBySliceID: [String: StatisticsDonutCenterData]

    init(
        rows: [StatisticsTotalRowViewData],
        donutSlices: [DonutChartSlice],
        defaultCenter: StatisticsDonutCenterData,
        emptyMessage: String,
        centersBySliceID: [String: StatisticsDonutCenterData]
    ) {
        self.rows = rows
        self.donutSlices = donutSlices
        self.defaultCenter = defaultCenter
        self.emptyMessage = emptyMessage
        self.centersBySliceID = centersBySliceID
    }

    var isEmpty: Bool { rows.isEmpty }

    func containsSlice(id: String?) -> Bool {
        guard let id else { return false }
        return centersBySliceID[id] != nil
    }

    func centerData(for selectedSliceID: String?) -> StatisticsDonutCenterData {
        guard
            let id = selectedSliceID,
            let center = centersBySliceID[id]
        else {
            return defaultCenter
        }

        return center
    }

    static func empty(totalMinutesText: String) -> StatisticsBreakdownSnapshot {
        StatisticsBreakdownSnapshot(
            rows: [],
            donutSlices: [],
            defaultCenter: StatisticsDonutCenterData(
                title: String(localized: "Total"),
                valueText: totalMinutesText
            ),
            emptyMessage: String(localized: "Add a few tasks to see totals."),
            centersBySliceID: [:]
        )
    }
}

struct StatisticsScreenSnapshot {
    let displayedTitle: String
    let totalMinutes: Int
    let totalMinutesText: String
    let comparison: StatisticsComparisonSnapshot
    let category: StatisticsBreakdownSnapshot
    let task: StatisticsBreakdownSnapshot

    func breakdownSnapshot(for breakdown: StatisticsBreakdown) -> StatisticsBreakdownSnapshot {
        switch breakdown {
        case .category:
            return category
        case .task:
            return task
        }
    }

    static func placeholder(
        currentContext: StatisticsPeriodContext,
        comparedContext: StatisticsPeriodContext,
        comparisonMode: StatisticsComparisonMode
    ) -> StatisticsScreenSnapshot {
        let totalMinutes = 0
        let totalMinutesText = totalMinutes.formattedHoursMinutes()

        return StatisticsScreenSnapshot(
            displayedTitle: currentContext.displayedTitle,
            totalMinutes: totalMinutes,
            totalMinutesText: totalMinutesText,
            comparison: .placeholder(
                currentContext: currentContext,
                comparedContext: comparedContext,
                mode: comparisonMode
            ),
            category: .empty(totalMinutesText: totalMinutesText),
            task: .empty(totalMinutesText: totalMinutesText)
        )
    }
}
