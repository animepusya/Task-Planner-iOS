//
//  WidgetShared.swift
//  Task Planner
//
//  Created by Руслан Меланин on 13.03.2026.
//

import Foundation

enum WidgetShared {
    static let appGroupId = "group.com.melani.taskplanner"

    enum WidgetKind {
        static let plannerHome = "TaskPlannerHomeWidget"
    }

    enum StorageKey {
        static let selectedDayKey = "widget.selectedDayKey"
        static let appThemeKey = "widget.appThemeKey"
        static let snapshotFileName = "planner-widget-snapshot.json"
    }

    enum DeepLinkHost {
        static let widget = "widget"
    }

    enum DeepLinkAction: String {
        case planner
        case createTask
    }
}

enum WidgetDayKey {
    static func make(from date: Date, calendar: Calendar = .current) -> String {
        let start = calendar.startOfDay(for: date)
        let comps = calendar.dateComponents([.year, .month, .day], from: start)
        let y = comps.year ?? 0
        let m = comps.month ?? 1
        let d = comps.day ?? 1
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    static func date(from key: String, calendar: Calendar = .current) -> Date? {
        let parts = key.split(separator: "-").map(String.init)
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]) else {
            return nil
        }

        var comps = DateComponents()
        comps.calendar = calendar
        comps.year = year
        comps.month = month
        comps.day = day
        return calendar.startOfDay(for: comps.date ?? .now)
    }
}

enum WidgetRoute: Equatable {
    case planner(day: Date)
    case createTask(day: Date)

    init?(url: URL, calendar: Calendar = .current) {
        guard url.scheme == "taskplanner",
              url.host == WidgetShared.DeepLinkHost.widget else {
            return nil
        }

        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let actionRaw = comps?.queryItems?.first(where: { $0.name == "action" })?.value
        let dayKey = comps?.queryItems?.first(where: { $0.name == "day" })?.value
        let day = dayKey.flatMap { WidgetDayKey.date(from: $0, calendar: calendar) } ?? calendar.startOfDay(for: .now)

        guard let actionRaw,
              let action = WidgetShared.DeepLinkAction(rawValue: actionRaw) else {
            return nil
        }

        switch action {
        case .planner:
            self = .planner(day: day)
        case .createTask:
            self = .createTask(day: day)
        }
    }

    var url: URL {
        let dayKey: String
        switch self {
        case .planner(let day), .createTask(let day):
            dayKey = WidgetDayKey.make(from: day)
        }

        let action: WidgetShared.DeepLinkAction
        switch self {
        case .planner:
            action = .planner
        case .createTask:
            action = .createTask
        }

        var comps = URLComponents()
        comps.scheme = "taskplanner"
        comps.host = WidgetShared.DeepLinkHost.widget
        comps.queryItems = [
            .init(name: "action", value: action.rawValue),
            .init(name: "day", value: dayKey)
        ]

        return comps.url!
    }
}
