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

    func durationMinutes(
        dayDate: Date,
        endDayDate: Date,
        startTime: Date,
        endTime: Date
    ) -> Int {
        let normalized = normalizeForSave(
            dayDate: dayDate,
            endDayDate: endDayDate,
            startTime: startTime,
            endTime: endTime
        )

        let minutes = Int(normalized.end.timeIntervalSince(normalized.start) / 60)
        return max(minDurationMinutes, minutes)
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
        let safeOffset = max(0, offset)

        let newEndDay = calendar.date(byAdding: .day, value: safeOffset, to: newStart) ?? newStart

        let alignedStartTime = combine(day: newStart, time: startTime)
        let alignedEndTime = combine(day: newEndDay, time: endTime)

        return Result(
            dayDate: newStart,
            endDayDate: calendar.startOfDay(for: newEndDay),
            startTime: alignedStartTime,
            endTime: alignedEndTime,
            message: nil
        )
    }

    func alignStartTimeToSelectedDay(dayDate: Date, startTime: Date) -> Date {
        combine(day: calendar.startOfDay(for: dayDate), time: startTime)
    }

    func alignEndTimeToEndDay(endDayDate: Date, endTime: Date) -> Date {
        combine(day: calendar.startOfDay(for: endDayDate), time: endTime)
    }

    // MARK: - Hard rule: endDayDate >= dayDate

    func clampEndDayDateIfNeeded(
        dayDate: Date,
        endDayDate: Date,
        startTime: Date,
        endTime: Date
    ) -> Result {
        let startDay = calendar.startOfDay(for: dayDate)
        let endDay = calendar.startOfDay(for: endDayDate)

        guard endDay < startDay else {
            return Result(
                dayDate: startDay,
                endDayDate: endDay,
                startTime: combine(day: startDay, time: startTime),
                endTime: combine(day: endDay, time: endTime),
                message: nil
            )
        }

        let fixedEndDay = startDay
        return Result(
            dayDate: startDay,
            endDayDate: fixedEndDay,
            startTime: combine(day: startDay, time: startTime),
            endTime: combine(day: fixedEndDay, time: endTime),
            message: "End date can’t be earlier than start date."
        )
    }

    // MARK: - Validation (next day rule)

    func validateAndFix(
        dayDate: Date,
        endDayDate: Date,
        startTime: Date,
        endTime: Date
    ) -> Result {
        let startDay = calendar.startOfDay(for: dayDate)
        var endDay = calendar.startOfDay(for: endDayDate)

        let start = combine(day: startDay, time: startTime)
        var end = combine(day: endDay, time: endTime)

        if endDay < startDay {
            endDay = startDay
            end = combine(day: endDay, time: endTime)
            return Result(
                dayDate: startDay,
                endDayDate: endDay,
                startTime: start,
                endTime: end,
                message: "End date can’t be earlier than start date."
            )
        }

        if calendar.isDate(endDay, inSameDayAs: startDay), end < start {
            let nextDay = calendar.date(byAdding: .day, value: 1, to: startDay) ?? startDay
            endDay = calendar.startOfDay(for: nextDay)
            end = combine(day: endDay, time: endTime)
            return Result(
                dayDate: startDay,
                endDayDate: endDay,
                startTime: start,
                endTime: end,
                message: "Ends next day."
            )
        }

        if calendar.isDate(endDay, inSameDayAs: startDay), end == start {
            end = calendar.date(byAdding: .minute, value: minDurationMinutes, to: start) ?? start
            endDay = calendar.startOfDay(for: end)
            return Result(
                dayDate: startDay,
                endDayDate: endDay,
                startTime: start,
                endTime: end,
                message: "Added \(minDurationMinutes) minutes."
            )
        }

        return Result(
            dayDate: startDay,
            endDayDate: endDay,
            startTime: start,
            endTime: end,
            message: nil
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
        newStartTime: Date,
        currentEndDayDate: Date,
        currentEndTime: Date
    ) -> DurationResult {
        let startDay = calendar.startOfDay(for: dayDate)
        let alignedStart = combine(day: startDay, time: newStartTime)

        let currentDurationMinutes = durationMinutes(
            dayDate: dayDate,
            endDayDate: currentEndDayDate,
            startTime: combine(day: startDay, time: newStartTime == currentEndTime ? currentEndTime : newStartTime),
            endTime: currentEndTime
        )

        let oldNormalized = normalizeForSave(
            dayDate: dayDate,
            endDayDate: currentEndDayDate,
            startTime: combine(day: startDay, time: alignedStart),
            endTime: currentEndTime
        )

        let actualMinutes = Int(oldNormalized.end.timeIntervalSince(oldNormalized.start) / 60)
        let safeMinutes = max(minDurationMinutes, actualMinutes)

        let newEnd = calendar.date(byAdding: .minute, value: safeMinutes, to: alignedStart) ?? alignedStart

        return DurationResult(
            startTime: alignedStart,
            endTime: newEnd,
            endDayDate: calendar.startOfDay(for: newEnd)
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

        let oldNormalized = normalizeForSave(
            dayDate: dayDate,
            endDayDate: oldEndDayDate,
            startTime: oldStartTime,
            endTime: oldEndTime
        )

        let actualMinutes = Int(oldNormalized.end.timeIntervalSince(oldNormalized.start) / 60)
        let safeMinutes = max(minDurationMinutes, actualMinutes)

        let alignedStart = combine(day: startDay, time: newStartTime)
        let newEnd = calendar.date(byAdding: .minute, value: safeMinutes, to: alignedStart) ?? alignedStart

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

    func ensureNextDayIfSameDayEndBeforeOrEqualStart(
        dayDate: Date,
        start: Date,
        endDayDate: Date,
        end: Date
    ) -> (start: Date, end: Date) {
        let startDay = calendar.startOfDay(for: dayDate)
        let endDay = calendar.startOfDay(for: endDayDate)

        if calendar.isDate(endDay, inSameDayAs: startDay), end <= start {
            let nextDay = calendar.date(byAdding: .day, value: 1, to: startDay) ?? startDay
            let fixedEnd = combine(day: nextDay, time: end)
            return (start, fixedEnd)
        }
        return (start, end)
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
