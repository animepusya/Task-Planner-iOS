//
//  WidgetSnapshotModels.swift
//  Task Planner
//
//  Created by Руслан Меланин on 13.03.2026.
//

import Foundation

nonisolated struct PlannerWidgetSnapshot: Codable, Equatable, Sendable {
    let generatedAt: Date
    let days: [PlannerWidgetDaySnapshot]

    func day(for key: String) -> PlannerWidgetDaySnapshot? {
        days.first(where: { $0.dayKey == key })
    }

    func rollingWindow(from date: Date, count: Int, calendar: Calendar = .current) -> [PlannerWidgetDaySnapshot] {
        let start = calendar.startOfDay(for: date)

        return (0..<count).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            let key = WidgetDayKey.make(from: day, calendar: calendar)
            return self.day(for: key)
        }
    }

    static func empty(referenceDate: Date = .now, range: Int = 30, calendar: Calendar = .current) -> PlannerWidgetSnapshot {
        PlannerWidgetSnapshotFactory(calendar: calendar)
            .makeEmptySnapshot(referenceDate: referenceDate, range: range)
    }
}

nonisolated struct PlannerWidgetDaySnapshot: Codable, Equatable, Identifiable, Sendable {
    var id: String { dayKey }

    let dayKey: String
    let date: Date
    let titleText: String
    let weekdayShortText: String
    let dayNumberText: String
    let tasks: [PlannerWidgetTaskSnapshot]
}

nonisolated struct PlannerWidgetTaskSnapshot: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let timeText: String
    let isCompleted: Bool
    let colorRaw: String
}

nonisolated struct PlannerWidgetSnapshotFactory {
    private let calendar: Calendar
    private let locale: Locale
    private let headerFormatter: DateFormatter
    private let weekdayFormatter: DateFormatter
    private let dayNumberFormatter: DateFormatter

    init(calendar: Calendar, locale: Locale = .current) {
        self.calendar = calendar
        self.locale = locale
        self.headerFormatter = Self.makeFormatter(template: "d MMMM", calendar: calendar, locale: locale)
        self.weekdayFormatter = Self.makeFormatter(template: "EEE", calendar: calendar, locale: locale)
        self.dayNumberFormatter = Self.makeFormatter(template: "d", calendar: calendar, locale: locale)
    }

    func makeEmptySnapshot(referenceDate: Date = .now, range: Int = 30) -> PlannerWidgetSnapshot {
        let start = calendar.startOfDay(for: referenceDate)
        let days = (0..<range).compactMap { offset -> PlannerWidgetDaySnapshot? in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            return makeDaySnapshot(for: date, tasks: [])
        }

        return .init(generatedAt: .now, days: days)
    }

    func makeDaySnapshot(for date: Date, tasks: [PlannerWidgetTaskSnapshot]) -> PlannerWidgetDaySnapshot {
        let normalizedDate = calendar.startOfDay(for: date)

        return PlannerWidgetDaySnapshot(
            dayKey: WidgetDayKey.make(from: normalizedDate, calendar: calendar),
            date: normalizedDate,
            titleText: headerFormatter.string(from: normalizedDate),
            weekdayShortText: weekdayFormatter.string(from: normalizedDate).uppercased(with: locale),
            dayNumberText: dayNumberFormatter.string(from: normalizedDate),
            tasks: tasks
        )
    }

    private static func makeFormatter(template: String, calendar: Calendar, locale: Locale) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter
    }
}
