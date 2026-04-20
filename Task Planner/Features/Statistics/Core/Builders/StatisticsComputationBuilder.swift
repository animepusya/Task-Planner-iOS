//
//  StatisticsComputationBuilder.swift
//  Task Planner
//
//  Created by Codex on 21.03.2026.
//

import Foundation
import SwiftData

nonisolated struct StatisticsComputedResult: Sendable {
    let totalMinutes: Int
    let categoryStats: [CategoryStat]
    let taskStats: [TaskStat]

    static let empty = StatisticsComputedResult(
        totalMinutes: 0,
        categoryStats: [],
        taskStats: []
    )
}

nonisolated struct StatisticsComputationKey: Hashable, Sendable {
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

nonisolated struct StatisticsTaskSeriesTemplateSource: Equatable, Sendable {
    let title: String
    let categoryTitle: String?
    let isAllDay: Bool
    let startMinutes: Int
    let durationSeconds: TimeInterval
    let overlapLookbackDays: Int
    let repeatRule: RepeatRule
    let repeatIntervalDays: Int?
    let colorRaw: String

    @MainActor
    init(template: TaskSeriesTemplate) {
        self.title = template.title
        self.categoryTitle = template.categoryTitle
        self.isAllDay = template.isAllDay
        self.startMinutes = template.startMinutes
        self.durationSeconds = template.durationSeconds
        self.overlapLookbackDays = template.overlapLookbackDays
        self.repeatRule = template.repeatRule
        self.repeatIntervalDays = template.repeatIntervalDays
        self.colorRaw = template.colorRaw
    }

    @MainActor
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
        self.overlapLookbackDays = max(0, endOffset)
        self.repeatRule = task.repeatRule
        self.repeatIntervalDays = task.repeatIntervalDays
        self.colorRaw = task.colorRaw
    }

    func occurrenceInterval(startDay: Date, calendar: Calendar) -> DateInterval {
        let occurrenceStart = TimeMinutes.date(
            on: calendar.startOfDay(for: startDay),
            minutes: startMinutes,
            calendar: calendar
        )

        return DateInterval(
            start: occurrenceStart,
            end: occurrenceStart.addingTimeInterval(durationSeconds)
        )
    }
}

nonisolated struct StatisticsTaskSeriesSegmentSource: Equatable, Sendable {
    let startDay: Date
    let endDay: Date?
    let template: StatisticsTaskSeriesTemplateSource

    @MainActor
    init(segment: TaskSeriesSegment) {
        self.startDay = segment.startDay
        self.endDay = segment.endDay
        self.template = StatisticsTaskSeriesTemplateSource(template: segment.template)
    }
}

nonisolated struct StatisticsTaskSeriesOverrideSource: Equatable, Sendable {
    let isDeleted: Bool
    let template: StatisticsTaskSeriesTemplateSource?

    @MainActor
    init(override: TaskSeriesOverride) {
        self.isDeleted = override.isDeleted
        self.template = override.template.map(StatisticsTaskSeriesTemplateSource.init(template:))
    }
}

nonisolated struct StatisticsTaskSource: Equatable, Sendable {
    let id: String
    let baseDay: Date
    let seriesEndDay: Date?
    let baseTemplate: StatisticsTaskSeriesTemplateSource
    let segments: [StatisticsTaskSeriesSegmentSource]
    let overridesByDayKey: [String: StatisticsTaskSeriesOverrideSource]

    @MainActor
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

    func hasRelevantStarts(
        between searchStart: Date,
        and searchEnd: Date,
        calendar: Calendar = .current
    ) -> Bool {
        let visibleStart = calendar.startOfDay(for: searchStart)
        let visibleEnd = calendar.startOfDay(for: searchEnd)
        let dayAfterVisibleEnd = calendar.date(byAdding: .day, value: 1, to: visibleEnd)
            ?? visibleEnd.addingTimeInterval(86_400)

        func intersectsVisibleRange(startDay: Date, template: StatisticsTaskSeriesTemplateSource) -> Bool {
            let interval = template.occurrenceInterval(startDay: startDay, calendar: calendar)
            return interval.end > visibleStart && interval.start < dayAfterVisibleEnd
        }

        for (dayKey, overrideValue) in overridesByDayKey {
            let overrideDay = calendar.startOfDay(for: DayKey.parse(dayKey, calendar: calendar))
            guard overrideDay <= visibleEnd else { continue }
            guard overrideValue.isDeleted == false, let template = overrideValue.template else { continue }

            if intersectsVisibleRange(startDay: overrideDay, template: template) {
                return true
            }
        }

        if segments.isEmpty {
            guard overridesByDayKey[DayKey.format(baseDay, calendar: calendar)]?.isDeleted != true else {
                return false
            }
            return intersectsVisibleRange(startDay: baseDay, template: baseTemplate)
        }

        for segment in segments {
            let segmentStart = calendar.startOfDay(for: segment.startDay)
            guard segmentStart <= visibleEnd else { break }

            var candidates: [Date] = [visibleEnd]

            if let segmentEnd = segment.endDay {
                candidates.append(calendar.startOfDay(for: segmentEnd))
            }

            if let normalizedSeriesEnd = seriesEndDay {
                candidates.append(calendar.startOfDay(for: normalizedSeriesEnd))
            }

            let effectiveEnd = candidates.min() ?? visibleEnd
            let lookbackStart = calendar.date(
                byAdding: .day,
                value: -segment.template.overlapLookbackDays,
                to: visibleStart
            ) ?? visibleStart.addingTimeInterval(TimeInterval(-segment.template.overlapLookbackDays * 86_400))

            if effectiveEnd >= max(segmentStart, lookbackStart) {
                return true
            }
        }

        return false
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
    nonisolated static func build(
        tasks: [StatisticsTaskSource],
        key: StatisticsComputationKey
    ) -> StatisticsComputedResult {
        guard !Task.isCancelled else { return .empty }

        let calendar = TaskOccurrence.calendar(weekStartsOnMonday: key.weekStartsOnMonday)
        let context = StatisticsPeriodContextBuilder.make(
            range: key.range,
            anchorDate: key.anchorDate,
            weekStartsOnMonday: key.weekStartsOnMonday
        )
        let visibleStart = context.startDay
        let visibleEnd = context.endDay
        let candidateTasks = tasks.filter {
            $0.hasRelevantStarts(between: visibleStart, and: visibleEnd, calendar: calendar)
        }

        var perCategory: [String: (totalMinutes: Int, colorMinutes: [String: Int])] = [:]
        var perTask: [String: (title: String, minutes: Int, colorRaw: String)] = [:]
        var totalMinutes = 0

        for task in candidateTasks {
            guard !Task.isCancelled else { return .empty }
            aggregateTaskOccurrences(
                for: task,
                visibleStart: visibleStart,
                visibleEnd: visibleEnd,
                calendar: calendar,
                weekStartsOnMonday: key.weekStartsOnMonday,
                perCategory: &perCategory,
                perTask: &perTask,
                totalMinutes: &totalMinutes
            )
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

    nonisolated private static func aggregateOccurrence(
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

    nonisolated private static func aggregateTaskOccurrences(
        for task: StatisticsTaskSource,
        visibleStart: Date,
        visibleEnd: Date,
        calendar: Calendar,
        weekStartsOnMonday: Bool,
        perCategory: inout [String: (totalMinutes: Int, colorMinutes: [String: Int])],
        perTask: inout [String: (title: String, minutes: Int, colorRaw: String)],
        totalMinutes: inout Int
    ) {
        let overrideDaysInRange = task.overridesByDayKey.keys
            .compactMap { dayKey -> Date? in
                let day = calendar.startOfDay(for: DayKey.parse(dayKey, calendar: calendar))
                return day <= visibleEnd ? day : nil
            }
            .sorted()

        var baseSuppressedDays = Set<Date>()
        baseSuppressedDays.reserveCapacity(overrideDaysInRange.count)

        for day in overrideDaysInRange {
            let dayKey = DayKey.format(day, calendar: calendar)
            guard let override = task.overridesByDayKey[dayKey] else { continue }

            if override.isDeleted || override.template != nil {
                baseSuppressedDays.insert(day)
            }

            guard override.isDeleted == false, let template = override.template else { continue }
            guard statisticsOccurrenceIntersectsVisibleRange(
                occurrenceStartDay: day,
                template: template,
                visibleStart: visibleStart,
                visibleEnd: visibleEnd,
                calendar: calendar
            ) else {
                continue
            }

            aggregateOccurrence(
                taskID: task.id,
                occurrenceStartDay: day,
                template: template,
                visibleStart: visibleStart,
                visibleEnd: visibleEnd,
                calendar: calendar,
                perCategory: &perCategory,
                perTask: &perTask,
                totalMinutes: &totalMinutes
            )
        }

        if task.segments.isEmpty {
            guard baseSuppressedDays.contains(task.baseDay) == false else { return }
            guard statisticsOccurrenceIntersectsVisibleRange(
                occurrenceStartDay: task.baseDay,
                template: task.baseTemplate,
                visibleStart: visibleStart,
                visibleEnd: visibleEnd,
                calendar: calendar
            ) else {
                return
            }

            aggregateOccurrence(
                taskID: task.id,
                occurrenceStartDay: task.baseDay,
                template: task.baseTemplate,
                visibleStart: visibleStart,
                visibleEnd: visibleEnd,
                calendar: calendar,
                perCategory: &perCategory,
                perTask: &perTask,
                totalMinutes: &totalMinutes
            )
            return
        }

        for segment in task.segments {
            let segmentStart = calendar.startOfDay(for: segment.startDay)
            guard segmentStart <= visibleEnd else { break }

            let segmentEnd = effectiveSegmentEnd(
                for: segment,
                task: task,
                searchEnd: visibleEnd,
                calendar: calendar
            )
            guard let segmentEnd, segmentEnd >= segmentStart else { continue }

            let lookbackStart = calendar.date(
                byAdding: .day,
                value: -segment.template.overlapLookbackDays,
                to: visibleStart
            ) ?? visibleStart.addingTimeInterval(TimeInterval(-segment.template.overlapLookbackDays * 86_400))

            let rangeStart = max(segmentStart, lookbackStart)
            let rangeEnd = min(segmentEnd, visibleEnd)
            guard rangeStart <= rangeEnd else { continue }

            aggregateStartDays(
                for: task,
                template: segment.template,
                rangeStart: rangeStart,
                rangeEnd: rangeEnd,
                anchorDay: segmentStart,
                suppressedDays: baseSuppressedDays,
                calendar: calendar,
                weekStartsOnMonday: weekStartsOnMonday,
                visibleStart: visibleStart,
                visibleEnd: visibleEnd,
                perCategory: &perCategory,
                perTask: &perTask,
                totalMinutes: &totalMinutes
            )
        }
    }

    nonisolated private static func effectiveSegmentEnd(
        for segment: StatisticsTaskSeriesSegmentSource,
        task: StatisticsTaskSource,
        searchEnd: Date,
        calendar: Calendar
    ) -> Date? {
        var candidates: [Date] = [searchEnd]

        if let segmentEnd = segment.endDay {
            candidates.append(calendar.startOfDay(for: segmentEnd))
        }

        if let seriesEndDay = task.seriesEndDay {
            candidates.append(calendar.startOfDay(for: seriesEndDay))
        }

        return candidates.min()
    }

    nonisolated private static func statisticsOccurrenceIntersectsVisibleRange(
        occurrenceStartDay: Date,
        template: StatisticsTaskSeriesTemplateSource,
        visibleStart: Date,
        visibleEnd: Date,
        calendar: Calendar
    ) -> Bool {
        let interval = template.occurrenceInterval(startDay: occurrenceStartDay, calendar: calendar)
        let dayAfterVisibleEnd = calendar.date(byAdding: .day, value: 1, to: visibleEnd)
            ?? visibleEnd.addingTimeInterval(86_400)

        return interval.end > visibleStart && interval.start < dayAfterVisibleEnd
    }

    nonisolated private static func aggregateStartDays(
        for task: StatisticsTaskSource,
        template: StatisticsTaskSeriesTemplateSource,
        rangeStart: Date,
        rangeEnd: Date,
        anchorDay: Date,
        suppressedDays: Set<Date>,
        calendar: Calendar,
        weekStartsOnMonday: Bool,
        visibleStart: Date,
        visibleEnd: Date,
        perCategory: inout [String: (totalMinutes: Int, colorMinutes: [String: Int])],
        perTask: inout [String: (title: String, minutes: Int, colorRaw: String)],
        totalMinutes: inout Int
    ) {
        func emit(_ day: Date) {
            let normalizedDay = calendar.startOfDay(for: day)
            guard normalizedDay >= rangeStart, normalizedDay <= rangeEnd else { return }
            guard suppressedDays.contains(normalizedDay) == false else { return }

            aggregateOccurrence(
                taskID: task.id,
                occurrenceStartDay: normalizedDay,
                template: template,
                visibleStart: visibleStart,
                visibleEnd: visibleEnd,
                calendar: calendar,
                perCategory: &perCategory,
                perTask: &perTask,
                totalMinutes: &totalMinutes
            )
        }

        switch template.repeatRule {
        case .none:
            emit(anchorDay)

        case .daily:
            for day in enumerateDays(from: rangeStart, to: rangeEnd, calendar: calendar) {
                emit(day)
            }

        case .weekdays, .weekends:
            for day in enumerateDays(from: rangeStart, to: rangeEnd, calendar: calendar) {
                if calendar.isDate(day, inSameDayAs: anchorDay) {
                    emit(day)
                    continue
                }

                let matchesRule: Bool = {
                    switch template.repeatRule {
                    case .weekdays:
                        return Workweek.isWeekday(day, calendar: calendar, weekStartsOnMonday: weekStartsOnMonday)
                    case .weekends:
                        return Workweek.isWeekend(day, calendar: calendar, weekStartsOnMonday: weekStartsOnMonday)
                    default:
                        return false
                    }
                }()

                if matchesRule {
                    emit(day)
                }
            }

        case .weekly:
            let dayDelta = max(0, calendar.dateComponents([.day], from: anchorDay, to: rangeStart).day ?? 0)
            let remainder = dayDelta % 7
            let offset = remainder == 0 ? 0 : (7 - remainder)
            let first = calendar.date(byAdding: .day, value: offset, to: rangeStart) ?? rangeStart

            for day in strideDays(from: first, through: rangeEnd, step: 7, calendar: calendar) {
                emit(day)
            }

        case .monthly:
            let anchorDayNumber = calendar.component(.day, from: anchorDay)
            var monthCursor = calendar.startOfMonth(for: rangeStart)
            let endMonth = calendar.startOfMonth(for: rangeEnd)

            while monthCursor <= endMonth {
                let components = calendar.dateComponents([.year, .month], from: monthCursor)
                var candidateComponents = DateComponents()
                candidateComponents.calendar = calendar
                candidateComponents.timeZone = calendar.timeZone
                candidateComponents.year = components.year
                candidateComponents.month = components.month
                candidateComponents.day = anchorDayNumber

                if let candidate = calendar.date(from: candidateComponents) {
                    emit(candidate)
                }

                guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthCursor),
                      nextMonth > monthCursor else {
                    break
                }
                monthCursor = nextMonth
            }

        case .everyNDays:
            let interval = max(1, template.repeatIntervalDays ?? 1)
            let daysFromAnchor = max(0, calendar.dateComponents([.day], from: anchorDay, to: rangeStart).day ?? 0)
            let firstStep = daysFromAnchor == 0 ? 0 : ((daysFromAnchor + interval - 1) / interval) * interval
            let first = calendar.date(byAdding: .day, value: firstStep, to: anchorDay) ?? anchorDay

            for day in strideDays(from: first, through: rangeEnd, step: interval, calendar: calendar) {
                emit(day)
            }
        }
    }

    nonisolated private static func template(
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

    nonisolated private static func occursStartOn(
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

    nonisolated private static func activeSegmentStartDay(
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

    nonisolated private static func strideDays(
        from start: Date,
        through end: Date,
        step: Int,
        calendar: Calendar
    ) -> [Date] {
        guard start <= end else { return [] }

        var days: [Date] = []
        var cursor = calendar.startOfDay(for: start)

        while cursor <= end {
            days.append(cursor)
            cursor = calendar.date(byAdding: .day, value: step, to: cursor)
                ?? cursor.addingTimeInterval(TimeInterval(step * 86_400))
        }

        return days
    }

    nonisolated private static func enumerateDays(
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

    nonisolated private static func minutes(from start: Date, to end: Date) -> Int {
        let delta = end.timeIntervalSince(start)
        guard delta.isFinite, delta > 0 else { return 0 }

        let roundedMinutes = (delta / 60.0).rounded(.toNearestOrAwayFromZero)
        guard roundedMinutes.isFinite else { return 0 }

        return Int(roundedMinutes)
    }

    nonisolated private static func makeTopTasks(
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

        let other = TaskStat(
            id: "other",
            title: String(localized: "Other"),
            minutes: otherMinutes,
            colorRaw: ""
        )
        return top + [other]
    }

    nonisolated private static func normalizedCategoryTitle(_ raw: String?) -> String {
        CategorySystem.localizedDisplayTitle(for: raw)
    }

    nonisolated private static func normalizedTaskTitle(_ raw: String) -> String {
        LocalizedDisplayText.taskTitle(raw)
    }
}
