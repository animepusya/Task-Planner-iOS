//
//  TaskSeriesService.swift
//  Task Planner
//
//  Created by Руслан Меланин on 06.03.2026.
//

import Foundation
import SwiftData

@MainActor
final class TaskSeriesService {

    enum Scope {
        case onlyThisDay
        case allFutureDays
    }

    struct EditChanges: Equatable {
        let startDay: Date
        let template: TaskSeriesTemplate
    }

    struct BaseRecurringIdentityChanges: Equatable {
        let title: String
        let repeatRuleRaw: String
        let repeatIntervalDays: Int?
        let colorRaw: String
        let categoryTitle: String

        var repeatRule: RepeatRule {
            RepeatRule(rawValue: repeatRuleRaw) ?? .none
        }
    }

    private struct PreservedPastOccurrence {
        let day: Date
        let template: TaskSeriesTemplate
    }

    private let taskRepository: TaskRepository

    init(taskRepository: TaskRepository) {
        self.taskRepository = taskRepository
    }

    // MARK: - Public API

    func applyEdit(
        taskId: PersistentIdentifier,
        occurrenceStartDay: Date,
        scope: Scope,
        changes: EditChanges
    ) throws {
        guard let task = try taskRepository.fetch(by: taskId) else { return }

        let cal = Calendar.current
        let sourceDay = cal.startOfDay(for: occurrenceStartDay)
        let targetDay = cal.startOfDay(for: changes.startDay)

        TaskSeriesEngine.ensureBaseSegmentIfNeeded(for: task, calendar: cal)

        switch scope {
        case .onlyThisDay:
            applyOnlyThisDayEdit(
                task: task,
                sourceDay: sourceDay,
                targetDay: targetDay,
                template: changes.template,
                calendar: cal
            )
            syncOwnerFieldsToCurrentOwnerIfNeeded(task: task, calendar: cal)
            try taskRepository.save()

        case .allFutureDays:
            splitAndApplyAllFuture(
                task: task,
                from: sourceDay,
                newStartDay: targetDay,
                newTemplate: changes.template,
                calendar: cal
            )
            syncOwnerFieldsToCurrentOwnerIfNeeded(task: task, calendar: cal)
            try taskRepository.save()
        }
    }

    func applyDelete(
        taskId: PersistentIdentifier,
        occurrenceStartDay: Date,
        scope: Scope
    ) throws {
        guard let task = try taskRepository.fetch(by: taskId) else { return }

        let cal = Calendar.current
        let day = cal.startOfDay(for: occurrenceStartDay)

        TaskSeriesEngine.ensureBaseSegmentIfNeeded(for: task, calendar: cal)

        switch scope {
        case .onlyThisDay:
            if isOwnerDay(task: task, day: day, calendar: cal) {
                let transferred = transferOwnershipAfterDeletingOwnerDay(
                    task: task,
                    deletedOwnerDay: day,
                    calendar: cal
                )
                if transferred == false {
                    try taskRepository.delete(task)
                    return
                }
            }

            markDeletedOverride(task: task, day: day)
            let key = TaskEntity.dayKey(for: day, calendar: cal)
            task.suppressReminder(for: key)

            syncOwnerFieldsToCurrentOwnerIfNeeded(task: task, calendar: cal)
            try taskRepository.save()

        case .allFutureDays:
            if isOwnerDay(task: task, day: day, calendar: cal) {
                try taskRepository.delete(task)
                return
            }

            deleteAllFuture(task: task, from: day)
            syncOwnerFieldsToCurrentOwnerIfNeeded(task: task, calendar: cal)
            try taskRepository.save()
        }
    }

    func applyBaseRecurringIdentityEdit(
        taskId: PersistentIdentifier,
        changes: BaseRecurringIdentityChanges
    ) throws {
        guard let task = try taskRepository.fetch(by: taskId) else { return }

        let cal = Calendar.current
        TaskSeriesEngine.ensureBaseSegmentIfNeeded(for: task, calendar: cal)

        if changes.repeatRule == .none {
            collapseSeriesToSingleNonRepeatingTemplate(
                task: task,
                changes: changes,
                calendar: cal
            )
        } else {
            // Base recurring fields are shared across scoped templates, so merge them in-place.
            task.seriesSegments = task.seriesSegments.map { segment in
                var segment = segment
                segment.template = mergeBaseRecurringIdentity(into: segment.template, changes: changes)
                return segment
            }

            task.seriesOverrides = task.seriesOverrides.map { override in
                var override = override

                if let template = override.template {
                    override.template = mergeBaseRecurringIdentity(into: template, changes: changes)
                }

                return override
            }
        }

        syncOwnerFieldsToCurrentOwnerIfNeeded(task: task, calendar: cal)
        try taskRepository.save()
    }

    // MARK: - Only this day edit / move

    private func applyOnlyThisDayEdit(
        task: TaskEntity,
        sourceDay: Date,
        targetDay: Date,
        template: TaskSeriesTemplate,
        calendar: Calendar
    ) {
        if calendar.isDate(sourceDay, inSameDayAs: targetDay) {
            upsertOverride(task: task, day: sourceDay, template: template)
            normalizeReminderSuppressionAfterExplicitOccurrence(
                task: task,
                day: sourceDay,
                template: template,
                calendar: calendar
            )
            return
        }

        // remove old occurrence from original day
        markDeletedOverride(task: task, day: sourceDay)
        task.suppressReminder(for: DayKey.format(sourceDay, calendar: calendar))

        // create explicit moved occurrence on target day
        upsertOverride(task: task, day: targetDay, template: template)
        normalizeReminderSuppressionAfterExplicitOccurrence(
            task: task,
            day: targetDay,
            template: template,
            calendar: calendar
        )
    }

    // MARK: - Overrides

    private func upsertOverride(task: TaskEntity, day: Date, template: TaskSeriesTemplate) {
        let cal = Calendar.current
        let key = DayKey.format(day, calendar: cal)
        var overrides = task.seriesOverrides

        if let idx = overrides.firstIndex(where: { $0.dayKey == key }) {
            overrides[idx].isDeleted = false
            overrides[idx].template = template
        } else {
            overrides.append(
                TaskSeriesOverride(
                    id: UUID(),
                    dayKey: key,
                    isDeleted: false,
                    template: template
                )
            )
        }

        task.seriesOverrides = overrides
    }

    private func markDeletedOverride(task: TaskEntity, day: Date) {
        let cal = Calendar.current
        let key = DayKey.format(day, calendar: cal)
        var overrides = task.seriesOverrides

        if let idx = overrides.firstIndex(where: { $0.dayKey == key }) {
            overrides[idx].isDeleted = true
            overrides[idx].template = nil
        } else {
            overrides.append(
                TaskSeriesOverride(
                    id: UUID(),
                    dayKey: key,
                    isDeleted: true,
                    template: nil
                )
            )
        }

        task.seriesOverrides = overrides
    }

    // MARK: - Ownership transfer / sync

    private func isOwnerDay(task: TaskEntity, day: Date, calendar: Calendar) -> Bool {
        calendar.isDate(
            calendar.startOfDay(for: task.dayDate),
            inSameDayAs: calendar.startOfDay(for: day)
        )
    }

    @discardableResult
    private func transferOwnershipAfterDeletingOwnerDay(
        task: TaskEntity,
        deletedOwnerDay: Date,
        calendar: Calendar
    ) -> Bool {
        guard let nextDay = TaskSeriesEngine.nextOccurrenceStartDay(
            for: task,
            after: deletedOwnerDay,
            weekStartsOnMonday: true
        ) else {
            return false
        }

        applyOwnerFields(task: task, ownerDay: nextDay, calendar: calendar)
        return true
    }

    private func syncOwnerFieldsToCurrentOwnerIfNeeded(task: TaskEntity, calendar: Calendar) {
        guard let ownerDay = resolvedOwnerDay(for: task, calendar: calendar) else { return }
        applyOwnerFields(task: task, ownerDay: ownerDay, calendar: calendar)
    }

    private func resolvedOwnerDay(for task: TaskEntity, calendar: Calendar) -> Date? {
        let explicitDays = task.seriesOverrides.compactMap { override -> Date? in
            guard override.isDeleted == false, override.template != nil else { return nil }
            return DayKey.parse(override.dayKey, calendar: calendar)
        }

        let segmentDays = task.seriesSegments.map { calendar.startOfDay(for: $0.startDay) }
        let mirroredOwnerDay = calendar.startOfDay(for: task.dayDate)

        let earliestCandidate = ([mirroredOwnerDay] + explicitDays + segmentDays).min() ?? mirroredOwnerDay
        let probeDay = calendar.date(byAdding: .day, value: -1, to: earliestCandidate) ?? earliestCandidate

        if TaskSeriesEngine.occursStartOn(task, on: earliestCandidate, weekStartsOnMonday: true) {
            return earliestCandidate
        }

        return TaskSeriesEngine.nextOccurrenceStartDay(
            for: task,
            after: probeDay,
            weekStartsOnMonday: true
        )
    }

    private func applyOwnerFields(task: TaskEntity, ownerDay: Date, calendar: Calendar) {
        guard let tpl = TaskSeriesEngine.template(for: task, startDay: ownerDay, calendar: calendar) else { return }

        let endDay = calendar.date(byAdding: .day, value: max(0, tpl.endDayOffset), to: ownerDay) ?? ownerDay

        task.dayDate = ownerDay
        task.startTime = TimeMinutes.date(on: ownerDay, minutes: tpl.startMinutes, calendar: calendar)
        task.endTime = TimeMinutes.date(on: endDay, minutes: tpl.endMinutes, calendar: calendar)

        task.title = tpl.title
        task.notes = tpl.notes
        task.isAllDay = tpl.isAllDay
        task.repeatRuleRaw = tpl.repeatRuleRaw
        task.repeatIntervalDays = tpl.repeatIntervalDays
        task.colorRaw = tpl.colorRaw
        task.categoryTitle = tpl.categoryTitle
        task.photoThumbData = tpl.photoThumbData
        task.reminderEnabled = tpl.reminderEnabled
        task.reminderOffsetMinutes = tpl.reminderOffsetMinutes
        task.reminderAllDayTimeMinutes = tpl.reminderAllDayTimeMinutes

        task.normalizeRepeatFields()
    }

    private func mergeBaseRecurringIdentity(
        into template: TaskSeriesTemplate,
        changes: BaseRecurringIdentityChanges
    ) -> TaskSeriesTemplate {
        var template = template
        template.title = changes.title
        template.repeatRuleRaw = changes.repeatRuleRaw
        template.repeatIntervalDays = changes.repeatIntervalDays
        template.colorRaw = changes.colorRaw
        template.categoryTitle = changes.categoryTitle
        return template
    }

    private func collapseSeriesToSingleNonRepeatingTemplate(
        task: TaskEntity,
        changes: BaseRecurringIdentityChanges,
        calendar: Calendar
    ) {
        let ownerDay = resolvedOwnerDay(for: task, calendar: calendar)
            ?? calendar.startOfDay(for: task.dayDate)

        let currentTemplate = TaskSeriesEngine.template(for: task, startDay: ownerDay, calendar: calendar)
            ?? TaskSeriesEngine.templateFromTask(task, dayStart: ownerDay, calendar: calendar)

        let mergedTemplate = mergeBaseRecurringIdentity(into: currentTemplate, changes: changes)

        task.seriesSegments = [
            TaskSeriesSegment(
                id: UUID(),
                startDayKey: DayKey.format(ownerDay, calendar: calendar),
                endDayKey: nil,
                template: mergedTemplate
            )
        ]
        task.seriesOverrides = []
        task.seriesEndDay = nil
        task.removeSuppressedReminders(onOrAfter: ownerDay, calendar: calendar)
    }

    // MARK: - All future split / move

    private func splitAndApplyAllFuture(
        task: TaskEntity,
        from sourceDay: Date,
        newStartDay targetDay: Date,
        newTemplate: TaskSeriesTemplate,
        calendar: Calendar
    ) {
        let preservedPast = buildPreservedPastOccurrences(
            task: task,
            sourceDay: sourceDay,
            targetDay: targetDay,
            newTemplate: newTemplate,
            calendar: calendar
        )

        var segments = task.seriesSegments.sorted { $0.startDay < $1.startDay }
        guard !segments.isEmpty else { return }

        let originalSeriesEnd = task.seriesEndDay.map { calendar.startOfDay(for: $0) }
        let sourceMinusOne = calendar.date(byAdding: .day, value: -1, to: sourceDay) ?? sourceDay

        if let activeIndex = activeSegmentIndex(in: segments, for: sourceDay, calendar: calendar) {
            let activeStart = calendar.startOfDay(for: segments[activeIndex].startDay)

            if sourceDay <= activeStart {
                segments.removeAll { calendar.startOfDay(for: $0.startDay) >= activeStart }
            } else {
                segments[activeIndex].endDayKey = DayKey.format(sourceMinusOne, calendar: calendar)
                segments.removeAll { calendar.startOfDay(for: $0.startDay) > sourceMinusOne }
            }
        } else {
            segments.removeAll { calendar.startOfDay(for: $0.startDay) >= sourceDay }
        }

        segments.removeAll { segment in
            if let end = segment.endDay {
                return calendar.startOfDay(for: end) < calendar.startOfDay(for: segment.startDay)
            }
            return false
        }

        let newSegment = TaskSeriesSegment(
            id: UUID(),
            startDayKey: DayKey.format(targetDay, calendar: calendar),
            endDayKey: originalSeriesEnd.map { DayKey.format($0, calendar: calendar) },
            template: newTemplate
        )

        segments.append(newSegment)
        task.seriesSegments = normalizedSegments(segments, calendar: calendar)

        // remove all overrides affected by the rewritten future
        let wipeFloor = min(sourceDay, targetDay)
        var overrides = task.seriesOverrides
        overrides.removeAll { override in
            DayKey.parse(override.dayKey, calendar: calendar) >= wipeFloor
        }
        task.seriesOverrides = overrides

        // restore past occurrences that must survive backward moves
        for preserved in preservedPast {
            upsertOverride(task: task, day: preserved.day, template: preserved.template)
        }

        normalizeReminderSuppressionAfterFutureMove(
            task: task,
            sourceDay: sourceDay,
            targetDay: targetDay,
            newTemplate: newTemplate,
            calendar: calendar
        )
    }

    private func buildPreservedPastOccurrences(
        task: TaskEntity,
        sourceDay: Date,
        targetDay: Date,
        newTemplate: TaskSeriesTemplate,
        calendar: Calendar
    ) -> [PreservedPastOccurrence] {
        guard targetDay < sourceDay else { return [] }

        var preserved: [PreservedPastOccurrence] = []
        var cursor = targetDay

        while cursor < sourceDay {
            let oldOccurs = TaskSeriesEngine.occursStartOn(task, on: cursor, weekStartsOnMonday: true)
            let newOccurs = TaskOccurrence.occursStartOnBase(
                rule: newTemplate.repeatRule,
                intervalDays: newTemplate.repeatIntervalDays,
                baseDay: targetDay,
                targetDay: cursor,
                calendar: calendar,
                weekStartsOnMonday: true
            )

            // deterministic rule:
            // if shifted future does NOT occupy this day, preserve the old past occurrence
            if oldOccurs,
               newOccurs == false,
               let oldTemplate = TaskSeriesEngine.template(for: task, startDay: cursor, calendar: calendar) {
                preserved.append(PreservedPastOccurrence(day: cursor, template: oldTemplate))
            }

            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? cursor.addingTimeInterval(86_400)
        }

        return preserved
    }

    private func activeSegmentIndex(
        in segments: [TaskSeriesSegment],
        for day: Date,
        calendar: Calendar
    ) -> Int? {
        segments.lastIndex(where: { segment in
            let start = calendar.startOfDay(for: segment.startDay)
            guard day >= start else { return false }
            if let end = segment.endDay {
                return day <= calendar.startOfDay(for: end)
            }
            return true
        })
    }

    private func normalizedSegments(
        _ segments: [TaskSeriesSegment],
        calendar: Calendar
    ) -> [TaskSeriesSegment] {
        let sorted = segments.sorted { $0.startDay < $1.startDay }
        var result: [TaskSeriesSegment] = []

        for var segment in sorted {
            let start = calendar.startOfDay(for: segment.startDay)

            if let last = result.last,
               calendar.isDate(calendar.startOfDay(for: last.startDay), inSameDayAs: start) {
                result.removeLast()
            }

            if let end = segment.endDay {
                let normalizedEnd = calendar.startOfDay(for: end)
                if normalizedEnd < start {
                    continue
                }
                segment.endDayKey = DayKey.format(normalizedEnd, calendar: calendar)
            }

            segment.startDayKey = DayKey.format(start, calendar: calendar)
            result.append(segment)
        }

        return result
    }

    // MARK: - Reminder normalization

    private func normalizeReminderSuppressionAfterExplicitOccurrence(
        task: TaskEntity,
        day: Date,
        template: TaskSeriesTemplate,
        calendar: Calendar
    ) {
        let key = DayKey.format(day, calendar: calendar)

        if template.reminderEnabled {
            task.unsuppressReminder(for: key)
        } else {
            task.suppressReminder(for: key)
        }
    }

    private func normalizeReminderSuppressionAfterFutureMove(
        task: TaskEntity,
        sourceDay: Date,
        targetDay: Date,
        newTemplate: TaskSeriesTemplate,
        calendar: Calendar
    ) {
        let floorDay = min(sourceDay, targetDay)
        task.removeSuppressedReminders(onOrAfter: floorDay, calendar: calendar)

        guard newTemplate.reminderEnabled == false else { return }

        // keep deterministic reminder state for disabled reminders after future rewrite
        var cursor = targetDay
        let limit = calendar.date(byAdding: .day, value: 120, to: targetDay) ?? targetDay

        while cursor <= limit {
            let occurs = TaskOccurrence.occursStartOnBase(
                rule: newTemplate.repeatRule,
                intervalDays: newTemplate.repeatIntervalDays,
                baseDay: targetDay,
                targetDay: cursor,
                calendar: calendar,
                weekStartsOnMonday: true
            )

            if occurs {
                task.suppressReminder(for: DayKey.format(cursor, calendar: calendar))
            }

            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? cursor.addingTimeInterval(86_400)
        }
    }

    // MARK: - Delete all future

    private func deleteAllFuture(task: TaskEntity, from day: Date) {
        let cal = Calendar.current
        var segs = task.seriesSegments.sorted { $0.startDay < $1.startDay }
        guard !segs.isEmpty else {
            task.seriesEndDay = cal.date(byAdding: .day, value: -1, to: day)
            return
        }

        if let activeIndex = segs.lastIndex(where: { s in
            let sStart = cal.startOfDay(for: s.startDay)
            guard day >= sStart else { return false }
            if let end = s.endDay {
                return day <= cal.startOfDay(for: end)
            }
            return true
        }) {
            let leftEnd = cal.date(byAdding: .day, value: -1, to: day)!
            segs[activeIndex].endDayKey = DayKey.format(leftEnd, calendar: cal)

            segs.removeAll { s in
                cal.startOfDay(for: s.startDay) >= day
            }

            var ovs = task.seriesOverrides
            ovs.removeAll { ov in
                DayKey.parse(ov.dayKey, calendar: cal) >= day
            }
            task.seriesOverrides = ovs

            task.seriesEndDay = leftEnd
        } else {
            task.seriesEndDay = cal.date(byAdding: .day, value: -1, to: day)
        }

        segs.removeAll { s in
            if let end = s.endDay {
                return cal.startOfDay(for: end) < cal.startOfDay(for: s.startDay)
            }
            return false
        }

        task.seriesSegments = segs
    }
}
