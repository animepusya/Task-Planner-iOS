//
//  TaskEditorTimeCoordinator.swift
//  Task Planner
//
//  Created by Руслан Меланин on 11.02.2026.
//

import Foundation

struct TaskEditorTimeCoordinator {
    let calendar: Calendar
    private let minDurationMinutes: Int = 15

    struct Result {
        var dayDate: Date
        var endDayDate: Date
        var startTime: Date
        var endTime: Date
        var message: String?
    }

    func startOfDay(_ date: Date) -> Date { calendar.startOfDay(for: date) }

    // MARK: - Core helpers

    func combine(day: Date, time: Date) -> Date {
        let dayStart = calendar.startOfDay(for: day)
        let comps = calendar.dateComponents([.hour, .minute], from: time)
        return calendar.date(bySettingHour: comps.hour ?? 0, minute: comps.minute ?? 0, second: 0, of: dayStart) ?? dayStart
    }

    // MARK: - Rules

    func clampEndDayDateIfNeeded(
        dayDate: Date,
        endDayDate: Date,
        startTime: Date,
        endTime: Date
    ) -> Result {
        let startDay = startOfDay(dayDate)
        let endDay = startOfDay(endDayDate)

        let alignedStart = combine(day: startDay, time: startTime)
        let alignedEnd = combine(day: endDay, time: endTime)

        guard endDay < startDay else {
            return Result(
                dayDate: startDay,
                endDayDate: endDay,
                startTime: alignedStart,
                endTime: alignedEnd,
                message: nil
            )
        }

        // возвращаем endDayDate на startDay
        let fixedEndDay = startDay
        let fixedEnd = combine(day: fixedEndDay, time: endTime)

        return Result(
            dayDate: startDay,
            endDayDate: fixedEndDay,
            startTime: alignedStart, // ✅ НЕ dayDate, а startTime
            endTime: fixedEnd,
            message: "End date can’t be earlier than start date."
        )
    }

    /// При смене start day переносим startTime и endDayDate с сохранением смещения по дням.
    func syncTimesToSelectedDay(newStartDay: Date, startTime: Date, endDayDate: Date, endTime: Date) -> Result {
        let newStart = startOfDay(newStartDay)

        let oldStartDay = startOfDay(startTime)
        let oldEndDay = startOfDay(endDayDate)
        let offsetDays = calendar.dateComponents([.day], from: oldStartDay, to: oldEndDay).day ?? 0

        let newEndDay = calendar.date(byAdding: .day, value: max(0, offsetDays), to: newStart) ?? newStart

        let alignedStart = combine(day: newStart, time: startTime)
        let alignedEnd = combine(day: startOfDay(newEndDay), time: endTime)

        return Result(
            dayDate: newStart,
            endDayDate: startOfDay(newEndDay),
            startTime: alignedStart,
            endTime: alignedEnd,
            message: nil
        )
    }

    func alignStartTimeToSelectedDay(dayDate: Date, startTime: Date) -> Date {
        combine(day: startOfDay(dayDate), time: startTime)
    }

    func alignEndTimeToEndDay(endDayDate: Date, endTime: Date) -> Date {
        combine(day: startOfDay(endDayDate), time: endTime)
    }

    // MARK: - Validation

    func validateAndFix(dayDate: Date, endDayDate: Date, startTime: Date, endTime: Date) -> Result {
        let startDay = startOfDay(dayDate)
        let endDay = startOfDay(endDayDate)

        let start = combine(day: startDay, time: startTime)
        var end = combine(day: endDay, time: endTime)

        // if same day and end < start => next day
        if calendar.isDate(endDay, inSameDayAs: startDay), end < start {
            let nextDay = calendar.date(byAdding: .day, value: 1, to: startDay) ?? startDay
            let fixedEndDay = startOfDay(nextDay)
            end = combine(day: fixedEndDay, time: endTime)

            return Result(
                dayDate: startDay,
                endDayDate: fixedEndDay,
                startTime: start,
                endTime: end,
                message: "Ends next day."
            )
        }

        // if same day and end == start => +min duration
        if calendar.isDate(endDay, inSameDayAs: startDay), end == start {
            end = calendar.date(byAdding: .minute, value: minDurationMinutes, to: start) ?? start
            return Result(
                dayDate: startDay,
                endDayDate: startOfDay(end),
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

    func applyDuration(minutes: Int, dayDate: Date, startTime: Date) -> (startTime: Date, endDayDate: Date, endTime: Date) {
        let startDay = startOfDay(dayDate)
        let start = combine(day: startDay, time: startTime)
        let end = calendar.date(byAdding: .minute, value: max(minDurationMinutes, minutes), to: start) ?? start
        return (start, startOfDay(end), end)
    }

    // MARK: - Save normalization

    func normalizeForSave(dayDate: Date, endDayDate: Date, startTime: Date, endTime: Date) -> (start: Date, end: Date) {
        let startDay = startOfDay(dayDate)
        let endDay = startOfDay(endDayDate)
        let start = combine(day: startDay, time: startTime)
        let end = combine(day: endDay, time: endTime)
        return (start, end)
    }

    func ensureNextDayIfSameDayEndBeforeOrEqualStart(dayDate: Date, start: Date, endDayDate: Date, end: Date) -> (start: Date, end: Date) {
        let startDay = startOfDay(dayDate)

        if calendar.isDate(startDay, inSameDayAs: startOfDay(endDayDate)), end <= start {
            let bumped = calendar.date(byAdding: .day, value: 1, to: end) ?? end
            return (start, bumped)
        }
        return (start, end)
    }
}
