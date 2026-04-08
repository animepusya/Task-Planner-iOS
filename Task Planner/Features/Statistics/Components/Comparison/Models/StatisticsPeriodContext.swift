//
//  StatisticsPeriodContext.swift
//  Task Planner
//
//  Created by Codex on 08.04.2026.
//

import Foundation

enum StatisticsComparisonMode: String, Sendable {
    case previousEquivalent
}

enum StatisticsPeriodShiftDirection: Equatable {
    case previous
    case next
}

struct StatisticsPeriodContext: Hashable, Sendable {
    let range: StatisticsRange
    let anchorDate: Date
    let weekStartsOnMonday: Bool
    let startDay: Date
    let endDay: Date
    let displayedTitle: String

    nonisolated var computationKey: StatisticsComputationKey {
        StatisticsComputationKey(
            range: range,
            anchorDate: anchorDate,
            weekStartsOnMonday: weekStartsOnMonday
        )
    }
}

enum StatisticsPeriodContextBuilder {
    nonisolated static func make(
        range: StatisticsRange,
        anchorDate: Date,
        weekStartsOnMonday: Bool
    ) -> StatisticsPeriodContext {
        let normalizedAnchor = normalizedAnchorDate(
            for: range,
            anchorDate: anchorDate,
            weekStartsOnMonday: weekStartsOnMonday
        )

        return StatisticsPeriodContext(
            range: range,
            anchorDate: normalizedAnchor,
            weekStartsOnMonday: weekStartsOnMonday,
            startDay: startDay(for: range, anchorDate: normalizedAnchor, weekStartsOnMonday: weekStartsOnMonday),
            endDay: endDay(for: range, anchorDate: normalizedAnchor, weekStartsOnMonday: weekStartsOnMonday),
            displayedTitle: displayedTitle(
                for: range,
                anchorDate: normalizedAnchor,
                weekStartsOnMonday: weekStartsOnMonday
            )
        )
    }

    nonisolated static func normalizedAnchorDate(
        for range: StatisticsRange,
        anchorDate: Date,
        weekStartsOnMonday: Bool
    ) -> Date {
        let calendar = TaskOccurrence.calendar(weekStartsOnMonday: weekStartsOnMonday)

        switch range {
        case .day, .week:
            return calendar.startOfDay(for: anchorDate)

        case .month:
            return calendar.startOfMonth(for: anchorDate)

        case .year:
            let year = calendar.component(.year, from: anchorDate)
            return calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? anchorDate
        }
    }

    nonisolated static func shiftedAnchorDate(
        for range: StatisticsRange,
        anchorDate: Date,
        weekStartsOnMonday: Bool,
        direction: StatisticsPeriodShiftDirection
    ) -> Date {
        let calendar = TaskOccurrence.calendar(weekStartsOnMonday: weekStartsOnMonday)
        let delta = direction == .previous ? -1 : 1

        let shiftedDate: Date
        switch range {
        case .day:
            shiftedDate = calendar.date(byAdding: .day, value: delta, to: anchorDate) ?? anchorDate

        case .week:
            shiftedDate = calendar.date(byAdding: .day, value: delta * 7, to: anchorDate) ?? anchorDate

        case .month:
            let candidate = calendar.date(byAdding: .month, value: delta, to: anchorDate) ?? anchorDate
            shiftedDate = calendar.startOfMonth(for: candidate)

        case .year:
            shiftedDate = calendar.date(byAdding: .year, value: delta, to: anchorDate) ?? anchorDate
        }

        return normalizedAnchorDate(
            for: range,
            anchorDate: shiftedDate,
            weekStartsOnMonday: weekStartsOnMonday
        )
    }

    nonisolated static func comparisonContext(
        for context: StatisticsPeriodContext,
        mode: StatisticsComparisonMode
    ) -> StatisticsPeriodContext {
        switch mode {
        case .previousEquivalent:
            return make(
                range: context.range,
                anchorDate: shiftedAnchorDate(
                    for: context.range,
                    anchorDate: context.anchorDate,
                    weekStartsOnMonday: context.weekStartsOnMonday,
                    direction: .previous
                ),
                weekStartsOnMonday: context.weekStartsOnMonday
            )
        }
    }

    nonisolated static func comparisonSubtitle(
        for range: StatisticsRange,
        mode: StatisticsComparisonMode
    ) -> String {
        switch mode {
        case .previousEquivalent:
            switch range {
            case .day:
                return String(localized: "vs previous day")
            case .week:
                return String(localized: "vs previous week")
            case .month:
                return String(localized: "vs previous month")
            case .year:
                return String(localized: "vs previous year")
            }
        }
    }

    nonisolated static func comparisonReferenceText(
        for range: StatisticsRange,
        mode: StatisticsComparisonMode
    ) -> String {
        switch mode {
        case .previousEquivalent:
            switch range {
            case .day:
                return String(localized: "previous day")
            case .week:
                return String(localized: "previous week")
            case .month:
                return String(localized: "previous month")
            case .year:
                return String(localized: "previous year")
            }
        }
    }

    nonisolated private static func startDay(
        for range: StatisticsRange,
        anchorDate: Date,
        weekStartsOnMonday: Bool
    ) -> Date {
        let calendar = TaskOccurrence.calendar(weekStartsOnMonday: weekStartsOnMonday)

        switch range {
        case .day:
            return calendar.startOfDay(for: anchorDate)

        case .week:
            return calendar.date(
                from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: anchorDate)
            ) ?? calendar.startOfDay(for: anchorDate)

        case .month:
            return calendar.startOfMonth(for: anchorDate)

        case .year:
            let components = calendar.dateComponents([.year], from: anchorDate)
            return calendar.date(from: components) ?? calendar.startOfDay(for: anchorDate)
        }
    }

    nonisolated private static func endDay(
        for range: StatisticsRange,
        anchorDate: Date,
        weekStartsOnMonday: Bool
    ) -> Date {
        let calendar = TaskOccurrence.calendar(weekStartsOnMonday: weekStartsOnMonday)
        let start = startDay(
            for: range,
            anchorDate: anchorDate,
            weekStartsOnMonday: weekStartsOnMonday
        )

        switch range {
        case .day:
            return start

        case .week:
            return calendar.date(byAdding: .day, value: 6, to: start) ?? start

        case .month:
            return calendar.endOfMonth(for: anchorDate)

        case .year:
            return calendar.date(byAdding: DateComponents(year: 1, day: -1), to: start) ?? start
        }
    }

    nonisolated private static func displayedTitle(
        for range: StatisticsRange,
        anchorDate: Date,
        weekStartsOnMonday: Bool
    ) -> String {
        let calendar = TaskOccurrence.calendar(weekStartsOnMonday: weekStartsOnMonday)

        switch range {
        case .day:
            return anchorDate.dayTitle(using: calendar)

        case .week:
            let weekStart = startDay(
                for: .week,
                anchorDate: anchorDate,
                weekStartsOnMonday: weekStartsOnMonday
            )
            let weekEnd = endDay(
                for: .week,
                anchorDate: anchorDate,
                weekStartsOnMonday: weekStartsOnMonday
            )

            let formatter = DateFormatter()
            formatter.calendar = calendar
            formatter.locale = .current
            formatter.dateFormat = "d MMM"

            return String.localizedStringWithFormat(
                String(localized: "%@ – %@"),
                formatter.string(from: weekStart),
                formatter.string(from: weekEnd)
            )

        case .month:
            return anchorDate.monthTitle(using: calendar)

        case .year:
            let formatter = DateFormatter()
            formatter.calendar = calendar
            formatter.locale = .current
            formatter.dateFormat = "yyyy"
            return formatter.string(from: anchorDate)
        }
    }
}
