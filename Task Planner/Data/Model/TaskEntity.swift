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
    var reminderEnabled: Bool
    var reminderOffsetMinutes: Int
    var reminderAllDayTimeMinutes: Int?
    var suppressedReminderKeysRaw: String?
    var seriesSegmentsRaw: String?
    var seriesOverridesRaw: String?
    var seriesEndDay: Date?

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
        categoryTitle: String? = nil,
        reminderEnabled: Bool = false,
        reminderOffsetMinutes: Int = 10,
        reminderAllDayTimeMinutes: Int? = nil
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
        self.reminderEnabled = reminderEnabled
        self.reminderOffsetMinutes = reminderOffsetMinutes
        self.reminderAllDayTimeMinutes = reminderAllDayTimeMinutes
        self.suppressedReminderKeysRaw = nil
        self.seriesSegmentsRaw = nil
        self.seriesOverridesRaw = nil
        self.seriesEndDay = nil
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
    var plannerTaskKey: String {
        String(describing: persistentModelID)
    }

    nonisolated static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let d = calendar.startOfDay(for: date)
        let c = calendar.dateComponents([.year, .month, .day], from: d)
        let y = c.year ?? 0
        let m = c.month ?? 1
        let day = c.day ?? 1
        return String(format: "%04d-%02d-%02d", y, m, day)
    }

    private static func encodeStringArray(_ arr: [String]) -> String {
        do {
            let data = try JSONEncoder().encode(arr)
            return String(data: data, encoding: .utf8) ?? "[]"
        } catch {
            return "[]"
        }
    }

    private static func decodeStringArray(_ raw: String) -> [String] {
        guard let data = raw.data(using: .utf8) else { return [] }
        do {
            return try JSONDecoder().decode([String].self, from: data)
        } catch {
            return []
        }
    }

    private var completedDayKeys: Set<String> {
        get { Set(Self.decodeStringArray(completedDayKeysRaw)) }
        set { completedDayKeysRaw = Self.encodeStringArray(Array(newValue).sorted()) }
    }

    var completedDayKeysSet: Set<String> {
        completedDayKeys
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

// MARK: - Reminder suppression (per-occurrence)
extension TaskEntity {

    var suppressedReminderKeys: Set<String> {
        get {
            guard let raw = suppressedReminderKeysRaw else { return [] }
            return Set(Self.decodeStringArray(raw))
        }
        set {
            suppressedReminderKeysRaw = Self.encodeStringArray(Array(newValue).sorted())
        }
    }

    func isReminderSuppressed(for key: String) -> Bool {
        suppressedReminderKeys.contains(key)
    }

    func suppressReminder(for key: String) {
        var set = suppressedReminderKeys
        set.insert(key)
        suppressedReminderKeys = set
    }

    func unsuppressReminder(for key: String) {
        var set = suppressedReminderKeys
        set.remove(key)
        suppressedReminderKeys = set
    }

    func removeSuppressedReminders(onOrAfter day: Date, calendar: Calendar = .current) {
        let threshold = calendar.startOfDay(for: day)
        let filtered = suppressedReminderKeys.filter { key in
            DayKey.parse(key, calendar: calendar) < threshold
        }
        suppressedReminderKeys = filtered
    }
}

// MARK: - Series segmentation JSON helpers
extension TaskEntity {

    private static let seriesEncoder = JSONEncoder()
    private static let seriesDecoder = JSONDecoder()

    var seriesSegments: [TaskSeriesSegment] {
        get {
            guard let raw = seriesSegmentsRaw, let data = raw.data(using: .utf8) else { return [] }
            do { return try Self.seriesDecoder.decode([TaskSeriesSegment].self, from: data) } catch { return [] }
        }
        set {
            let sorted = newValue.sorted { $0.startDay < $1.startDay }
            do {
                let data = try Self.seriesEncoder.encode(sorted)
                seriesSegmentsRaw = String(data: data, encoding: .utf8) ?? "[]"
            } catch {
                seriesSegmentsRaw = "[]"
            }
        }
    }

    var seriesOverrides: [TaskSeriesOverride] {
        get {
            guard let raw = seriesOverridesRaw, let data = raw.data(using: .utf8) else { return [] }
            do { return try Self.seriesDecoder.decode([TaskSeriesOverride].self, from: data) } catch { return [] }
        }
        set {
            let sorted = newValue.sorted { $0.dayKey < $1.dayKey }
            do {
                let data = try Self.seriesEncoder.encode(sorted)
                seriesOverridesRaw = String(data: data, encoding: .utf8) ?? "[]"
            } catch {
                seriesOverridesRaw = "[]"
            }
        }
    }
}
