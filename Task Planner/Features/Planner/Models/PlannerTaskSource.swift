//
//  PlannerTaskSource.swift
//  Task Planner
//
//  Created by Codex on 23.03.2026.
//

import Foundation
import SwiftUI

struct PlannerTaskSeriesOverrideValue: Sendable {
    let isDeleted: Bool
    let template: TaskSeriesTemplate?
}

struct PlannerTaskSource: Sendable {
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

struct PlannerExternalEventSource: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let calendarTitle: String
    let mappedColor: TaskColor
    let location: String?
}

extension TaskEntity {
    func plannerSource(calendar: Calendar = .current) -> PlannerTaskSource {
        let normalizedBaseDay = calendar.startOfDay(for: dayDate)
        let baseTemplate = TaskSeriesEngine.templateFromTask(self, dayStart: normalizedBaseDay, calendar: calendar)

        var effectiveSegments = seriesSegments.sorted { $0.startDay < $1.startDay }
        if repeatRule != .none && effectiveSegments.isEmpty {
            effectiveSegments = [
                TaskSeriesSegment(
                    id: UUID(),
                    startDayKey: DayKey.format(normalizedBaseDay, calendar: calendar),
                    endDayKey: nil,
                    template: baseTemplate
                )
            ]
        }

        var overrideByDay: [Date: PlannerTaskSeriesOverrideValue] = [:]
        overrideByDay.reserveCapacity(seriesOverrides.count)

        for override in seriesOverrides {
            let day = calendar.startOfDay(for: DayKey.parse(override.dayKey, calendar: calendar))
            overrideByDay[day] = PlannerTaskSeriesOverrideValue(
                isDeleted: override.isDeleted,
                template: override.template
            )
        }

        return PlannerTaskSource(
            taskKey: plannerTaskKey,
            baseDay: normalizedBaseDay,
            ownerRepeatRule: repeatRule,
            baseTemplate: baseTemplate,
            completedDayKeys: completedDayKeysSet,
            seriesSegments: effectiveSegments,
            overrideByDay: overrideByDay,
            seriesEndDay: seriesEndDay.map { calendar.startOfDay(for: $0) }
        )
    }
}

extension ExternalCalendarEvent {
    func plannerSource() -> PlannerExternalEventSource {
        PlannerExternalEventSource(
            id: id,
            title: title,
            startDate: startDate,
            endDate: endDate,
            isAllDay: isAllDay,
            calendarTitle: calendarTitle,
            mappedColor: TaskColor.closest(to: calendarColor),
            location: location
        )
    }
}
