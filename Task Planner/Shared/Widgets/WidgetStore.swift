//
//  WidgetStore.swift
//  Task Planner
//
//  Created by Руслан Меланин on 13.03.2026.
//

import Foundation

enum WidgetStore {
    private static var userDefaults: UserDefaults? {
        UserDefaults(suiteName: WidgetShared.appGroupId)
    }

    private static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: WidgetShared.appGroupId)?
            .appendingPathComponent(WidgetShared.StorageKey.snapshotFileName)
    }

    static func loadSnapshot() -> PlannerWidgetSnapshot {
        guard let url = fileURL,
              let data = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder().decode(PlannerWidgetSnapshot.self, from: data) else {
            return .empty()
        }

        return snapshot
    }

    static func saveSnapshot(_ snapshot: PlannerWidgetSnapshot) throws {
        guard let url = fileURL else {
            throw CocoaError(.fileNoSuchFile)
        }

        let data = try JSONEncoder().encode(snapshot)
        try data.write(to: url, options: .atomic)
    }

    static func selectedDayKey(fallbackTo date: Date = .now, calendar: Calendar = .current) -> String {
        if let stored = userDefaults?.string(forKey: WidgetShared.StorageKey.selectedDayKey) {
            return stored
        }
        return WidgetDayKey.make(from: date, calendar: calendar)
    }

    static func setSelectedDayKey(_ key: String) {
        userDefaults?.set(key, forKey: WidgetShared.StorageKey.selectedDayKey)
    }
}
