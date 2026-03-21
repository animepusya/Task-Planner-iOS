//
//  StatisticsComputationBuilder.swift
//  Task Planner
//
//  Created by Codex on 21.03.2026.
//

import Foundation
import SwiftData

struct StatisticsComputedResult: Sendable {
    let totalMinutes: Int
    let categoryStats: [CategoryStat]
    let taskStats: [TaskStat]

    static let empty = StatisticsComputedResult(
        totalMinutes: 0,
        categoryStats: [],
        taskStats: []
    )
}

struct StatisticsComputationKey: Hashable, Sendable {
    let range: StatisticsRange
    let anchorDate: Date
    let weekStartsOnMonday: Bool
}

final class StatisticsComputationCache {
    private var storage: [StatisticsComputationKey: StatisticsComputedResult] = [:]
    private var accessOrder: [StatisticsComputationKey] = []
    private let maxEntries = 12

    func value(for key: StatisticsComputationKey) -> StatisticsComputedResult? {
        storage[key]
    }

    func insert(_ value: StatisticsComputedResult, for key: StatisticsComputationKey) {
        storage[key] = value
        accessOrder.removeAll { $0 == key }
        accessOrder.append(key)

        while accessOrder.count > maxEntries {
            let oldest = accessOrder.removeFirst()
            storage.removeValue(forKey: oldest)
        }
    }

    func invalidateAll() {
        storage.removeAll(keepingCapacity: true)
        accessOrder.removeAll(keepingCapacity: true)
    }
}

struct StatisticsTaskSeriesTemplateSource: Equatable, Sendable {
    let title: String
    let categoryTitle: String?
    let isAllDay: Bool
    let startMinutes: Int
    let durationSeconds: TimeInterval
    let repeatRule: RepeatRule
    let repeatIntervalDays: Int?
    let colorRaw: String

    init(template: TaskSeriesTemplate) {
        self.title = template.title
        self.categoryTitle = template.categoryTitle
        self.isAllDay = template.isAllDay
        self.startMinutes = template.startMinutes
        self.durationSeconds = template.durationSeconds
        self.repeatRule = template.repeatRule
        self.repeatIntervalDays = template.repeatIntervalDays
        self.colorRaw = template.colorRaw
    }

    init(task: TaskEntity, calendar: Calendar = .current) {
        let startMinutes = TimeMinutes.minutes(from: task.startTime, calendar: calendar)
        let (endOffset, endMinutes) = TimeMinutes.endOffsetAndMinutes(
            start: task.startTime,
            end: task.endTime,
            calendar: calendar
        )
        let totalEnd = max(0, endOffset) * 1440 + max(0, endMinutes)
        let durationMinutes = max(1, totalEnd - max(0, startMinutes))

        self.title = task.title
        self.categoryTitle = task.categoryTitle
        self.isAllDay = task.isAllDay
        self.startMinutes = startMinutes
        self.durationSeconds = TimeInterval(durationMinutes * 60)
        self.repeatRule = task.repeatRule
        self.repeatIntervalDays = task.repeatIntervalDays
        self.colorRaw = task.colorRaw
    }
}

struct StatisticsTaskSeriesSegmentSource: Equatable, Sendable {
    let startDay: Date
    let endDay: Date?
    let template: StatisticsTaskSeriesTemplateSource

    init(segment: TaskSeriesSegment) {
        self.startDay = segment.startDay
        self.endDay = segment.endDay
        self.template = StatisticsTaskSeriesTemplateSource(template: segment.template)
    }
}

struct StatisticsTaskSeriesOverrideSource: Equatable, Sendable {
    let isDeleted: Bool
    let template: StatisticsTaskSeriesTemplateSource?

    init(override: TaskSeriesOverride) {
        self.isDeleted = override.isDeleted
        self.template = override.template.map(StatisticsTaskSeriesTemplateSource.init(template:))
    }
}

struct StatisticsTaskSource: Equatable, Sendable {
    let id: String
    let baseDay: Date
    let seriesEndDay: Date?
    let baseTemplate: StatisticsTaskSeriesTemplateSource
    let segments: [StatisticsTaskSeriesSegmentSource]
    let overridesByDayKey: [String: StatisticsTaskSeriesOverrideSource]

    init(task: TaskEntity, calendar: Calendar = .current) {
        let baseDay = calendar.startOfDay(for: task.dayDate)
        let baseTemplate = StatisticsTaskSeriesTemplateSource(task: task, calendar: calendar)

        var segments = task.seriesSegments
            .map(StatisticsTaskSeriesSegmentSource.init(segment:))
            .sorted { $0.startDay < $1.startDay }

        if task.repeatRule != .none && segments.isEmpty {
            segments = [
                StatisticsTaskSeriesSegmentSource(
                    startDay: baseDay,
                    endDay: nil,
                    template: baseTemplate
                )
            ]
        }

        var overridesByDayKey: [String: StatisticsTaskSeriesOverrideSource] = [:]
        overridesByDayKey.reserveCapacity(task.seriesOverrides.count)
        for override in task.seriesOverrides {
            overridesByDayKey[override.dayKey] = StatisticsTaskSeriesOverrideSource(override: override)
        }

        self.id = String(describing: task.persistentModelID)
        self.baseDay = baseDay
        self.seriesEndDay = task.seriesEndDay.map { calendar.startOfDay(for: $0) }
        self.baseTemplate = baseTemplate
        self.segments = segments
        self.overridesByDayKey = overridesByDayKey
    }

    var hasSeriesState: Bool {
        baseTemplate.repeatRule != .none || !segments.isEmpty || !overridesByDayKey.isEmpty
    }
}

private extension StatisticsTaskSeriesSegmentSource {
    init(
        startDay: Date,
        endDay: Date?,
        template: StatisticsTaskSeriesTemplateSource
    ) {
        self.startDay = startDay
        self.endDay = endDay
        self.template = template
    }
}

enum StatisticsComputationBuilder {
    static func build(
        tasks: [StatisticsTaskSource],
        key: StatisticsComputationKey
    ) -> StatisticsComputedResult {
        guard !Task.isCancelled else { return .empty }

        let calendar = TaskOccurrence.calendar(weekStartsOnMonday: key.weekStartsOnMonday)
        let (visibleStart, visibleEnd) = dateRange(
            for: key.range,
            anchorDate: key.anchorDate,
            calendar: calendar
        )
        let searchStart = calendar.date(
            byAdding: .day,
            value: -TaskDayOverlap.maxOccurrenceLookbackDays,
            to: visibleStart
        ) ?? visibleStart.addingTimeInterval(TimeInterval(-TaskDayOverlap.maxOccurrenceLookbackDays * 86_400))
        let searchDays = enumerateDays(from: searchStart, to: visibleEnd, calendar: calendar)

        let candidateTasks = tasks.filter { task in
            guard task.baseDay <= visibleEnd else { return false }

            if let seriesEndDay = task.seriesEndDay {
                return seriesEndDay >= searchStart
            }

            return true
        }

        var perCategory: [String: (totalMinutes: Int, colorMinutes: [String: Int])] = [:]
        var perTask: [String: (title: String, minutes: Int, colorRaw: String)] = [:]
        var totalMinutes = 0

        for task in candidateTasks {
            guard !Task.isCancelled else { return .empty }

            for occurrenceStartDay in searchDays {
                guard !Task.isCancelled else { return .empty }
                guard occursStartOn(task, on: occurrenceStartDay, weekStartsOnMonday: key.weekStartsOnMonday, calendar: calendar) else {
                    continue
                }

                guard let template = template(for: task, startDay: occurrenceStartDay, calendar: calendar) else {
                    continue
                }

                aggregateOccurrence(
                    taskID: task.id,
                    occurrenceStartDay: occurrenceStartDay,
                    template: template,
                    visibleStart: visibleStart,
                    visibleEnd: visibleEnd,
                    calendar: calendar,
                    perCategory: &perCategory,
                    perTask: &perTask,
                    totalMinutes: &totalMinutes
                )
            }
        }

        let categoryStats = perCategory
            .map { categoryName, payload in
                let dominantColorRaw = payload.colorMinutes.max(by: { $0.value < $1.value })?.key ?? ""

                return CategoryStat(
                    name: categoryName,
                    minutes: payload.totalMinutes,
                    colorRaw: dominantColorRaw
                )
            }
            .sorted {
                if $0.minutes != $1.minutes {
                    return $0.minutes > $1.minutes
                }

                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }

        return StatisticsComputedResult(
            totalMinutes: totalMinutes,
            categoryStats: categoryStats,
            taskStats: makeTopTasks(from: perTask)
        )
    }

    private static func aggregateOccurrence(
        taskID: String,
        occurrenceStartDay: Date,
        template: StatisticsTaskSeriesTemplateSource,
        visibleStart: Date,
        visibleEnd: Date,
        calendar: Calendar,
        perCategory: inout [String: (totalMinutes: Int, colorMinutes: [String: Int])],
        perTask: inout [String: (title: String, minutes: Int, colorRaw: String)],
        totalMinutes: inout Int
    ) {
        guard template.isAllDay == false else { return }

        let occurrenceStart = TimeMinutes.date(
            on: occurrenceStartDay,
            minutes: template.startMinutes,
            calendar: calendar
        )
        let occurrenceEnd = occurrenceStart.addingTimeInterval(template.durationSeconds)
        let dayAfterVisibleEnd = calendar.date(byAdding: .day, value: 1, to: visibleEnd)
            ?? visibleEnd.addingTimeInterval(86_400)

        guard occurrenceEnd > visibleStart else { return }
        guard occurrenceStart < dayAfterVisibleEnd else { return }

        let lastOccurrenceMoment = occurrenceEnd.addingTimeInterval(-1)
        let firstDay = max(visibleStart, calendar.startOfDay(for: occurrenceStart))
        let lastDay = min(visibleEnd, calendar.startOfDay(for: lastOccurrenceMoment))

        guard firstDay <= lastDay else { return }

        for dayStart in enumerateDays(from: firstDay, to: lastDay, calendar: calendar) {
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(86_400)
            let overlapStart = max(occurrenceStart, dayStart)
            let overlapEnd = min(occurrenceEnd, dayEnd)

            let minutes = minutes(from: overlapStart, to: overlapEnd)
            guard minutes > 0 else { continue }

            totalMinutes += minutes

            let categoryName = normalizedCategoryTitle(template.categoryTitle)
            let colorRaw = template.colorRaw

            if var existingCategory = perCategory[categoryName] {
                existingCategory.totalMinutes += minutes
                existingCategory.colorMinutes[colorRaw, default: 0] += minutes
                perCategory[categoryName] = existingCategory
            } else {
                perCategory[categoryName] = (
                    totalMinutes: minutes,
                    colorMinutes: [colorRaw: minutes]
                )
            }

            let taskTitle = normalizedTaskTitle(template.title)

            if var existingTask = perTask[taskID] {
                existingTask.minutes += minutes
                existingTask.title = taskTitle
                existingTask.colorRaw = colorRaw
                perTask[taskID] = existingTask
            } else {
                perTask[taskID] = (
                    title: taskTitle,
                    minutes: minutes,
                    colorRaw: colorRaw
                )
            }
        }
    }

    private static func template(
        for task: StatisticsTaskSource,
        startDay: Date,
        calendar: Calendar
    ) -> StatisticsTaskSeriesTemplateSource? {
        let normalizedDay = calendar.startOfDay(for: startDay)
        let dayKey = DayKey.format(normalizedDay, calendar: calendar)

        if let override = task.overridesByDayKey[dayKey] {
            if override.isDeleted { return nil }
            if let template = override.template { return template }
        }

        if let segment = task.segments.last(where: { segment in
            guard normalizedDay >= segment.startDay else { return false }

            if let endDay = segment.endDay {
                return normalizedDay <= endDay
            }

            return true
        }) {
            return segment.template
        }

        guard task.hasSeriesState == false else { return nil }
        return task.baseTemplate
    }

    private static func occursStartOn(
        _ task: StatisticsTaskSource,
        on date: Date,
        weekStartsOnMonday: Bool,
        calendar: Calendar
    ) -> Bool {
        let targetDay = calendar.startOfDay(for: date)
        let dayKey = DayKey.format(targetDay, calendar: calendar)

        if let override = task.overridesByDayKey[dayKey] {
            if override.isDeleted { return false }
            if override.template != nil { return true }
        }

        if let seriesEndDay = task.seriesEndDay, targetDay > seriesEndDay {
            return false
        }

        if task.hasSeriesState == false {
            return calendar.isDate(targetDay, inSameDayAs: task.baseDay)
        }

        guard let template = template(for: task, startDay: targetDay, calendar: calendar) else {
            return false
        }

        let rule = template.repeatRule
        let anchor = activeSegmentStartDay(for: task, day: targetDay)

        if rule == .none {
            guard let anchor else { return false }
            return calendar.isDate(targetDay, inSameDayAs: anchor)
        }

        guard let anchor else { return false }

        return TaskOccurrence.occursStartOnBase(
            rule: rule,
            intervalDays: template.repeatIntervalDays,
            baseDay: anchor,
            targetDay: targetDay,
            calendar: calendar,
            weekStartsOnMonday: weekStartsOnMonday
        )
    }

    private static func activeSegmentStartDay(
        for task: StatisticsTaskSource,
        day: Date
    ) -> Date? {
        let normalizedDay = day

        guard let segment = task.segments.last(where: { segment in
            guard normalizedDay >= segment.startDay else { return false }

            if let endDay = segment.endDay {
                return normalizedDay <= endDay
            }

            return true
        }) else {
            return nil
        }

        return segment.startDay
    }

    private static func enumerateDays(
        from start: Date,
        to end: Date,
        calendar: Calendar
    ) -> [Date] {
        let normalizedStart = calendar.startOfDay(for: start)
        let normalizedEnd = calendar.startOfDay(for: end)
        guard normalizedStart <= normalizedEnd else { return [] }

        var result: [Date] = []
        result.reserveCapacity((calendar.dateComponents([.day], from: normalizedStart, to: normalizedEnd).day ?? 0) + 1)

        var cursor = normalizedStart
        while cursor <= normalizedEnd {
            result.append(cursor)
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? cursor.addingTimeInterval(86_400)
        }

        return result
    }

    private static func dateRange(
        for range: StatisticsRange,
        anchorDate: Date,
        calendar: Calendar
    ) -> (Date, Date) {
        switch range {
        case .day:
            let day = calendar.startOfDay(for: anchorDate)
            return (day, day)

        case .week:
            let weekStart = calendar.date(
                from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: anchorDate)
            ) ?? calendar.startOfDay(for: anchorDate)
            let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
            return (calendar.startOfDay(for: weekStart), calendar.startOfDay(for: weekEnd))

        case .month:
            let start = calendar.startOfMonth(for: anchorDate)
            let end = calendar.endOfMonth(for: anchorDate)
            return (calendar.startOfDay(for: start), calendar.startOfDay(for: end))

        case .year:
            let components = calendar.dateComponents([.year], from: anchorDate)
            let start = calendar.date(from: components) ?? calendar.startOfDay(for: anchorDate)
            let end = calendar.date(byAdding: DateComponents(year: 1, day: -1), to: start) ?? start
            return (calendar.startOfDay(for: start), calendar.startOfDay(for: end))
        }
    }

    private static func minutes(from start: Date, to end: Date) -> Int {
        let delta = end.timeIntervalSince(start)
        guard delta > 0 else { return 0 }
        return Int((delta / 60.0).rounded(.toNearestOrAwayFromZero))
    }

    private static func makeTopTasks(
        from perTask: [String: (title: String, minutes: Int, colorRaw: String)]
    ) -> [TaskStat] {
        let sorted = perTask
            .map { TaskStat(id: $0.key, title: $0.value.title, minutes: $0.value.minutes, colorRaw: $0.value.colorRaw) }
            .sorted {
                if $0.minutes != $1.minutes {
                    return $0.minutes > $1.minutes
                }

                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }

        let topLimit = 10
        guard sorted.count > topLimit else { return sorted }

        let top = Array(sorted.prefix(topLimit))
        let rest = sorted.dropFirst(topLimit)
        let otherMinutes = rest.reduce(0) { $0 + $1.minutes }

        guard otherMinutes > 0 else { return top }

        let other = TaskStat(id: "other", title: "Other", minutes: otherMinutes, colorRaw: "")
        return top + [other]
    }

    private static func normalizedCategoryTitle(_ raw: String?) -> String {
        let trimmed = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Work" : trimmed
    }

    private static func normalizedTaskTitle(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled" : trimmed
    }
}
