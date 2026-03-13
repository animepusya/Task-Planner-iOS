//
//  WidgetSnapshotModels.swift
//  Task Planner
//
//  Created by Руслан Меланин on 13.03.2026.
//

import Foundation

struct PlannerWidgetSnapshot: Codable, Equatable {
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
        let start = calendar.startOfDay(for: referenceDate)
        let days = (0..<range).compactMap { offset -> PlannerWidgetDaySnapshot? in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            let key = WidgetDayKey.make(from: date, calendar: calendar)

            return PlannerWidgetDaySnapshot(
                dayKey: key,
                date: date,
                titleText: Self.headerFormatter.string(from: date),
                weekdayShortText: Self.weekdayFormatter.string(from: date).uppercased(),
                dayNumberText: Self.dayNumberFormatter.string(from: date),
                tasks: []
            )
        }

        return .init(generatedAt: .now, days: days)
    }

    private static let headerFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = .current
        f.setLocalizedDateFormatFromTemplate("d MMMM")
        return f
    }()

    private static let weekdayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = .current
        f.setLocalizedDateFormatFromTemplate("EEE")
        return f
    }()

    private static let dayNumberFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = .current
        f.setLocalizedDateFormatFromTemplate("d")
        return f
    }()
}

struct PlannerWidgetDaySnapshot: Codable, Equatable, Identifiable {
    var id: String { dayKey }

    let dayKey: String
    let date: Date
    let titleText: String
    let weekdayShortText: String
    let dayNumberText: String
    let tasks: [PlannerWidgetTaskSnapshot]
}

struct PlannerWidgetTaskSnapshot: Codable, Equatable, Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let timeText: String
    let isCompleted: Bool
    let colorRaw: String
}
