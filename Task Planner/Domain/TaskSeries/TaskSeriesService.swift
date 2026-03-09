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
        let day = cal.startOfDay(for: occurrenceStartDay)

        TaskSeriesEngine.ensureBaseSegmentIfNeeded(for: task, calendar: cal)

        switch scope {
        case .onlyThisDay:
            upsertOverride(task: task, day: day, template: changes.template)
            try taskRepository.save()

        case .allFutureDays:
            splitAndApplyAllFuture(task: task, from: day, newTemplate: changes.template)
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
                let transferred = transferOwnershipAfterDeletingOwnerDay(task: task, deletedOwnerDay: day, calendar: cal)
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

    // MARK: - Overrides

    private func upsertOverride(task: TaskEntity, day: Date, template: TaskSeriesTemplate) {
        let cal = Calendar.current
        let key = DayKey.format(day, calendar: cal)
        var overrides = task.seriesOverrides

        if let idx = overrides.firstIndex(where: { $0.dayKey == key }) {
            overrides[idx].isDeleted = false
            overrides[idx].template = template
        } else {
            overrides.append(TaskSeriesOverride(id: UUID(), dayKey: key, isDeleted: false, template: template))
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
            overrides.append(TaskSeriesOverride(id: UUID(), dayKey: key, isDeleted: true, template: nil))
        }

        task.seriesOverrides = overrides
    }

    // MARK: - Ownership transfer

    private func isOwnerDay(task: TaskEntity, day: Date, calendar: Calendar) -> Bool {
        calendar.isDate(calendar.startOfDay(for: task.dayDate), inSameDayAs: calendar.startOfDay(for: day))
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
        let ownerDay = calendar.startOfDay(for: task.dayDate)
        applyOwnerFields(task: task, ownerDay: ownerDay, calendar: calendar)
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

    // MARK: - All future split (deterministic, no conflicts)

    private func splitAndApplyAllFuture(task: TaskEntity, from day: Date, newTemplate: TaskSeriesTemplate) {
        let cal = Calendar.current
        var segs = task.seriesSegments.sorted { $0.startDay < $1.startDay }
        guard !segs.isEmpty else { return }

        guard let activeIndex = segs.lastIndex(where: { s in
            let sStart = cal.startOfDay(for: s.startDay)
            guard day >= sStart else { return false }
            if let end = s.endDay {
                let sEnd = cal.startOfDay(for: end)
                return day <= sEnd
            }
            return true
        }) else {
            let nextStart = segs.first(where: { cal.startOfDay(for: $0.startDay) > day })?.startDay
            let endCap = nextStart.map { cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: $0))! }
            segs.append(TaskSeriesSegment(
                id: UUID(),
                startDayKey: DayKey.format(day, calendar: cal),
                endDayKey: endCap.map { DayKey.format($0, calendar: cal) },
                template: newTemplate
            ))
            task.seriesSegments = segs
            return
        }

        let nextSegStartDay: Date? = {
            for i in (activeIndex + 1)..<segs.count {
                let s = cal.startOfDay(for: segs[i].startDay)
                if s > day { return s }
            }
            return nil
        }()

        let cappedEnd: Date? = {
            if let next = nextSegStartDay {
                return cal.date(byAdding: .day, value: -1, to: next)
            }
            return segs[activeIndex].endDay.map { cal.startOfDay(for: $0) }
        }()

        let activeStart = cal.startOfDay(for: segs[activeIndex].startDay)
        let activeEnd = segs[activeIndex].endDay.map { cal.startOfDay(for: $0) }

        if activeStart == day {
            segs[activeIndex].template = newTemplate
            segs[activeIndex].endDayKey = cappedEnd.map { DayKey.format($0, calendar: cal) }
        } else {
            let leftEnd = cal.date(byAdding: .day, value: -1, to: day)!
            segs[activeIndex].endDayKey = DayKey.format(leftEnd, calendar: cal)

            let newSeg = TaskSeriesSegment(
                id: UUID(),
                startDayKey: DayKey.format(day, calendar: cal),
                endDayKey: cappedEnd.map { DayKey.format($0, calendar: cal) } ?? activeEnd.map { DayKey.format($0, calendar: cal) },
                template: newTemplate
            )
            segs.insert(newSeg, at: activeIndex + 1)
        }

        segs.removeAll { s in
            if let end = s.endDay {
                return cal.startOfDay(for: end) < cal.startOfDay(for: s.startDay)
            }
            return false
        }

        task.seriesSegments = segs
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
