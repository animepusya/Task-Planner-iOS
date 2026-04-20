//
//  PlannerTaskSource.swift
//  Task Planner
//
//  Created by Codex on 23.03.2026.
//

import Foundation

nonisolated struct PlannerTaskSeriesOverrideValue: Equatable, Sendable {
    let isDeleted: Bool
    let template: TaskSeriesTemplate?
}

nonisolated struct PlannerTaskSource: Equatable, Sendable {
    let taskKey: String
    let baseDay: Date
    let ownerRepeatRule: RepeatRule
    let baseTemplate: TaskSeriesTemplate
    let completedDayKeys: Set<String>
    let seriesSegments: [TaskSeriesSegment]
    let overrideByDay: [Date: PlannerTaskSeriesOverrideValue]
    let seriesEndDay: Date?

    var isRepeatingTask: Bool {
        ownerRepeatRule != .none
    }

    func isCompleted(on day: Date, calendar: Calendar = .current) -> Bool {
        completedDayKeys.contains(TaskEntity.dayKey(for: day, calendar: calendar))
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

        func intersectsVisibleRange(startDay: Date, template: TaskSeriesTemplate) -> Bool {
            let interval = template.occurrenceInterval(startDay: startDay, calendar: calendar)
            return interval.end > visibleStart && interval.start < dayAfterVisibleEnd
        }

        for (overrideDay, overrideValue) in overrideByDay {
            guard overrideDay <= visibleEnd else { continue }
            guard overrideValue.isDeleted == false, let template = overrideValue.template else { continue }

            if intersectsVisibleRange(startDay: overrideDay, template: template) {
                return true
            }
        }

        if seriesSegments.isEmpty {
            guard ownerRepeatRule == .none else { return false }
            guard overrideByDay[baseDay]?.isDeleted != true else { return false }
            return intersectsVisibleRange(startDay: baseDay, template: baseTemplate)
        }

        for segment in seriesSegments {
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

    func withCompletedDayKeys(_ keys: Set<String>) -> PlannerTaskSource {
        PlannerTaskSource(
            taskKey: taskKey,
            baseDay: baseDay,
            ownerRepeatRule: ownerRepeatRule,
            baseTemplate: baseTemplate,
            completedDayKeys: keys,
            seriesSegments: seriesSegments,
            overrideByDay: overrideByDay,
            seriesEndDay: seriesEndDay
        )
    }
}

nonisolated struct PlannerExternalEventSource: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let calendarTitle: String
    let mappedColor: TaskColor
    let location: String?
}
