//
//  TaskEntity+PlannerSource.swift
//  Task Planner
//
//  Created by Codex on 15.04.2026.
//

import Foundation

extension TaskEntity {
    @MainActor
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
