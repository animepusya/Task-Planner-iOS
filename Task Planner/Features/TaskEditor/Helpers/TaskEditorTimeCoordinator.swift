//
//  TaskEditorTimeCoordinator.swift
//  Task Planner
//
//  Created by Руслан Меланин on 11.02.2026.
//

import Foundation

struct TaskEditorTimeCoordinator {
    struct Result {
        var dayDate: Date
        var endDayDate: Date
        var startTime: Date
        var endTime: Date
        var isInvalidRange: Bool
        var message: String?
    }

    struct DurationResult {
        let startTime: Date
        let endTime: Date
        let endDayDate: Date
    }

    private let calendar: Calendar
    private let minDurationMinutes: Int = 15

    init(calendar: Calendar) {
        self.calendar = calendar
    }

    // MARK: - Basics

    func startOfDay(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    func combine(day: Date, time: Date) -> Date {
        let dayStart = calendar.startOfDay(for: day)
        let comps = calendar.dateComponents([.hour, .minute], from: time)
        let hour = comps.hour ?? 0
        let minute = comps.minute ?? 0
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: dayStart) ?? dayStart
    }

    // MARK: - Alignment

    func syncTimesToSelectedDay(
        newStartDay: Date,
        startTime: Date,
        endDayDate: Date,
        endTime: Date
    ) -> Result {
        let newStart = calendar.startOfDay(for: newStartDay)

        let oldStartDay = calendar.startOfDay(for: startTime)
        let oldEndDay = calendar.startOfDay(for: endDayDate)
        let offset = calendar.dateComponents([.day], from: oldStartDay, to: oldEndDay).day ?? 0
        let newEndDay = calendar.date(byAdding: .day, value: offset, to: newStart) ?? newStart

        let alignedStartTime = combine(day: newStart, time: startTime)
        let alignedEndTime = combine(day: newEndDay, time: endTime)

        return Result(
            dayDate: newStart,
            endDayDate: calendar.startOfDay(for: newEndDay),
            startTime: alignedStartTime,
            endTime: alignedEndTime,
            isInvalidRange: false,
            message: nil
        )
    }

    func alignStartTimeToSelectedDay(dayDate: Date, startTime: Date) -> Date {
        combine(day: calendar.startOfDay(for: dayDate), time: startTime)
    }

    func alignEndTimeToEndDay(endDayDate: Date, endTime: Date) -> Date {
        combine(day: calendar.startOfDay(for: endDayDate), time: endTime)
    }

    // MARK: - Validation

    func normalizeAndValidate(
        dayDate: Date,
        endDayDate: Date,
        startTime: Date,
        endTime: Date
    ) -> Result {
        let startDay = calendar.startOfDay(for: dayDate)
        let endDay = calendar.startOfDay(for: endDayDate)
        let alignedStart = combine(day: startDay, time: startTime)
        let alignedEnd = combine(day: endDay, time: endTime)
        let message = validationMessage(start: alignedStart, end: alignedEnd)

        return Result(
            dayDate: startDay,
            endDayDate: endDay,
            startTime: alignedStart,
            endTime: alignedEnd,
            isInvalidRange: message != nil,
            message: message
        )
    }

    // MARK: - Duration

    func applyDuration(minutes: Int, dayDate: Date, startTime: Date) -> DurationResult {
        let startDay = calendar.startOfDay(for: dayDate)

        let start = combine(day: startDay, time: startTime)
        let end = calendar.date(byAdding: .minute, value: max(minDurationMinutes, minutes), to: start) ?? start

        return DurationResult(
            startTime: start,
            endTime: end,
            endDayDate: calendar.startOfDay(for: end)
        )
    }

    func moveStartKeepingDuration(
        dayDate: Date,
        oldStartTime: Date,
        oldEndDayDate: Date,
        oldEndTime: Date,
        newStartTime: Date
    ) -> DurationResult {
        let startDay = calendar.startOfDay(for: dayDate)
        let alignedStart = combine(day: startDay, time: newStartTime)

        let oldNormalized = normalizeForSave(
            dayDate: dayDate,
            endDayDate: oldEndDayDate,
            startTime: oldStartTime,
            endTime: oldEndTime
        )

        let actualMinutes = Int(oldNormalized.end.timeIntervalSince(oldNormalized.start) / 60)
        guard actualMinutes > 0 else {
            let preservedEndDay = calendar.startOfDay(for: oldEndDayDate)
            return DurationResult(
                startTime: alignedStart,
                endTime: combine(day: preservedEndDay, time: oldEndTime),
                endDayDate: preservedEndDay
            )
        }

        let newEnd = calendar.date(byAdding: .minute, value: actualMinutes, to: alignedStart) ?? alignedStart

        return DurationResult(
            startTime: alignedStart,
            endTime: newEnd,
            endDayDate: calendar.startOfDay(for: newEnd)
        )
    }

    // MARK: - Save normalization

    func normalizeForSave(
        dayDate: Date,
        endDayDate: Date,
        startTime: Date,
        endTime: Date
    ) -> (start: Date, end: Date) {
        let startDay = calendar.startOfDay(for: dayDate)
        let endDay = calendar.startOfDay(for: endDayDate)

        let start = combine(day: startDay, time: startTime)
        let end = combine(day: endDay, time: endTime)
        return (start, end)
    }

    func isInvalidRange(
        dayDate: Date,
        endDayDate: Date,
        startTime: Date,
        endTime: Date
    ) -> Bool {
        let normalized = normalizeForSave(
            dayDate: dayDate,
            endDayDate: endDayDate,
            startTime: startTime,
            endTime: endTime
        )

        return normalized.end <= normalized.start
    }

    func validationMessage(start: Date, end: Date) -> String? {
        guard end <= start else { return nil }
        return String(localized: "End date & time must be later than start date & time.")
    }
}

extension TaskEditorTimeCoordinator {

    func nextOccurrenceStartDay(
        from startDay: Date,
        repeatRule: RepeatRule,
        repeatIntervalDays: Int,
        weekStartsOnMonday: Bool
    ) -> Date? {
        let s = calendar.startOfDay(for: startDay)

        switch repeatRule {
        case .none:
            return nil
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: s)
        case .weekdays, .weekends:
            return Workweek.nextMatchingStartDay(
                after: s,
                rule: repeatRule,
                calendar: calendar,
                weekStartsOnMonday: weekStartsOnMonday
            )
        case .weekly:
            return calendar.date(byAdding: .day, value: 7, to: s)
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: s)
        case .everyNDays:
            return calendar.date(byAdding: .day, value: max(1, repeatIntervalDays), to: s)
        }
    }

    func isRepeatConflict(
        dayDate: Date,
        endDayDate: Date,
        startTime: Date,
        endTime: Date,
        repeatRule: RepeatRule,
        repeatIntervalDays: Int,
        weekStartsOnMonday: Bool
    ) -> Bool {
        guard repeatRule != .none else { return false }

        let normalized = normalizeForSave(
            dayDate: dayDate,
            endDayDate: endDayDate,
            startTime: startTime,
            endTime: endTime
        )
        let start = normalized.start
        let end = normalized.end
        let duration = end.timeIntervalSince(start)
        guard duration > 0 else { return false }

        let startDay = calendar.startOfDay(for: dayDate)

        guard let nextStartDay = nextOccurrenceStartDay(
            from: startDay,
            repeatRule: repeatRule,
            repeatIntervalDays: repeatIntervalDays,
            weekStartsOnMonday: weekStartsOnMonday
        ) else { return false }

        let nextStart = combine(day: nextStartDay, time: startTime)

        return end > nextStart
    }
}
