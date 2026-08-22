//
//  TaskCreationSourceResolver.swift
//  Task Planner
//
//  Created by Codex on 20.08.2026.
//

import Foundation
import SwiftData

enum TaskCreationSourceResolver {
    @MainActor
    static func candidate(
        from task: TaskEntity,
        referenceDay: Date,
        calendar: Calendar = .current
    ) -> TaskCreationSourceCandidate {
        let normalizedReferenceDay = calendar.startOfDay(for: referenceDay)
        let snapshot = snapshot(
            from: task,
            referenceDay: normalizedReferenceDay,
            calendar: calendar
        )

        let normalizedSourceDay = calendar.startOfDay(for: task.dayDate)
        let endDay = task.seriesEndDay.map { calendar.startOfDay(for: $0) }
        let isEnded = endDay.map { $0 < normalizedReferenceDay }
            ?? (snapshot.repeatRule == .none && normalizedSourceDay < normalizedReferenceDay)

        return TaskCreationSourceCandidate(
            snapshot: snapshot,
            sourceDay: normalizedSourceDay,
            referenceDay: normalizedReferenceDay,
            isEnded: isEnded
        )
    }

    @MainActor
    static func snapshot(
        from task: TaskEntity,
        referenceDay: Date,
        calendar: Calendar = .current
    ) -> TaskCreationSourceSnapshot {
        let template = effectiveTemplate(
            from: task,
            referenceDay: referenceDay,
            calendar: calendar
        )
        let statisticsIdentity = TaskStatisticsIdentity(task: task)

        return TaskCreationSourceSnapshot(
            sourceID: task.persistentModelID,
            title: template.title,
            notes: template.notes,
            isAllDay: template.isAllDay,
            startMinutes: template.startMinutes,
            endMinutes: template.endMinutes,
            endDayOffset: max(0, template.endDayOffset),
            repeatRule: template.repeatRule,
            repeatIntervalDays: template.repeatIntervalDays,
            colorRaw: template.colorRaw,
            categoryTitle: template.categoryTitle,
            photoThumbData: template.photoThumbData,
            reminderEnabled: template.reminderEnabled,
            reminderOffsetMinutes: template.reminderOffsetMinutes,
            reminderAllDayTimeMinutes: template.reminderAllDayTimeMinutes,
            statisticsIdentityID: statisticsIdentity?.id,
            statisticsIdentityTitle: statisticsIdentity?.title
        )
    }

    @MainActor
    private static func effectiveTemplate(
        from task: TaskEntity,
        referenceDay: Date,
        calendar: Calendar
    ) -> TaskSeriesTemplate {
        let normalizedReferenceDay = calendar.startOfDay(for: referenceDay)
        let segments = task.seriesSegments.sorted { $0.startDay < $1.startDay }

        if let activeSegment = segments.last(where: { segment in
            let startDay = calendar.startOfDay(for: segment.startDay)
            guard normalizedReferenceDay >= startDay else { return false }

            if let endDay = segment.endDay {
                return normalizedReferenceDay <= calendar.startOfDay(for: endDay)
            }

            return true
        }) {
            return activeSegment.template
        }

        if let latestPastSegment = segments.last(where: {
            calendar.startOfDay(for: $0.startDay) <= normalizedReferenceDay
        }) {
            return latestPastSegment.template
        }

        return TaskSeriesEngine.templateFromTask(
            task,
            dayStart: calendar.startOfDay(for: task.dayDate),
            calendar: calendar
        )
    }
}
