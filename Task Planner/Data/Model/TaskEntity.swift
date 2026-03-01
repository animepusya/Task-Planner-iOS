//
//  TaskEntity.swift
//  Task Planner
//
//  Created by Руслан Меланин on 09.02.2026.
//

import Foundation
import SwiftData

@Model
final class TaskEntity {
    var title: String
    var notes: String?
    var dayDate: Date
    var startTime: Date
    var endTime: Date
    var isAllDay: Bool
    var repeatRuleRaw: String
    var repeatIntervalDays: Int?
    var statusRaw: String
    var colorRaw: String
    var categoryTitle: String?
    var photoThumbData: Data?
    var completedDayKeysRaw: String
    var appleEventIdentifier: String?

    init(
        title: String,
        notes: String? = nil,
        dayDate: Date,
        startTime: Date,
        endTime: Date,
        isAllDay: Bool = false,
        repeatRule: RepeatRule = .none,
        repeatIntervalDays: Int? = nil,
        status: TaskStatus = .todo,
        color: TaskColor = .purple,
        categoryTitle: String? = nil
    ) {
        self.title = title
        self.notes = notes
        self.dayDate = dayDate
        self.startTime = startTime
        self.endTime = endTime
        self.isAllDay = isAllDay
        self.repeatRuleRaw = repeatRule.rawValue
        self.repeatIntervalDays = repeatIntervalDays
        self.statusRaw = status.rawValue
        self.colorRaw = color.rawValue
        self.categoryTitle = categoryTitle
        self.photoThumbData = nil
        self.completedDayKeysRaw = "[]"
        self.appleEventIdentifier = nil
    }

    var repeatRule: RepeatRule {
        get { RepeatRule(rawValue: repeatRuleRaw) ?? .none }
        set { repeatRuleRaw = newValue.rawValue }
    }

    var status: TaskStatus {
        get { TaskStatus(rawValue: statusRaw) ?? .todo }
        set { statusRaw = newValue.rawValue }
    }

    var color: TaskColor {
        get { TaskColor(rawValue: colorRaw) ?? .purple }
        set { colorRaw = newValue.rawValue }
    }
}

// MARK: - Per-day completion helpers (visual-only)
extension TaskEntity {

    private static let dayKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let start = calendar.startOfDay(for: date)
        let utc = Date(timeIntervalSince1970: start.timeIntervalSince1970)
        return dayKeyFormatter.string(from: utc)
    }

    private var completedDayKeys: Set<String> {
        get {
            guard let data = completedDayKeysRaw.data(using: .utf8) else { return [] }
            do {
                let arr = try JSONDecoder().decode([String].self, from: data)
                return Set(arr)
            } catch {
                return []
            }
        }
        set {
            let arr = Array(newValue).sorted()
            do {
                let data = try JSONEncoder().encode(arr)
                completedDayKeysRaw = String(data: data, encoding: .utf8) ?? "[]"
            } catch {
                completedDayKeysRaw = "[]"
            }
        }
    }

    func isCompleted(on day: Date, calendar: Calendar = .current) -> Bool {
        let key = Self.dayKey(for: day, calendar: calendar)
        return completedDayKeys.contains(key)
    }

    func toggleCompleted(on day: Date, calendar: Calendar = .current) {
        let key = Self.dayKey(for: day, calendar: calendar)
        var set = completedDayKeys
        if set.contains(key) { set.remove(key) } else { set.insert(key) }
        completedDayKeys = set
    }
    
    func normalizeRepeatFields() {
        if repeatRule != .everyNDays {
            repeatIntervalDays = nil
        } else {
            let v = repeatIntervalDays ?? 1
            repeatIntervalDays = max(1, v)
        }
    }
}
