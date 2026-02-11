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

    /// Комбинируем day (startOfDay) + hour/minute из time
    func combine(day: Date, time: Date) -> Date {
        let dayStart = calendar.startOfDay(for: day)
        let comps = calendar.dateComponents([.hour, .minute], from: time)
        let hour = comps.hour ?? 0
        let minute = comps.minute ?? 0
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: dayStart) ?? dayStart
    }

    // MARK: - Alignment

    /// dayDate изменился: переносим startTime на новый dayDate, а endDayDate сохраняем оффсет дней
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

        // если endDay пытались поставить раньше startDay → возвращаем на startDay
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

        var start = combine(day: startDay, time: startTime)
        var end = combine(day: endDay, time: endTime)

        // жёстко: endDay не может быть раньше startDay
        if endDay < startDay {
            endDay = startDay
            end = combine(day: endDay, time: endTime)
            return Result(dayDate: startDay, endDayDate: endDay, startTime: start, endTime: end, message: "End date can’t be earlier than start date.")
        }

        // правило "в тот же день end < start" → это следующий день
        if calendar.isDate(endDay, inSameDayAs: startDay), end < start {
            let nextDay = calendar.date(byAdding: .day, value: 1, to: startDay) ?? startDay
            endDay = calendar.startOfDay(for: nextDay)
            end = combine(day: endDay, time: endTime)
            return Result(dayDate: startDay, endDayDate: endDay, startTime: start, endTime: end, message: "Ends next day.")
        }

        // если end == start в тот же день → добавим минимум
        if calendar.isDate(endDay, inSameDayAs: startDay), end == start {
            end = calendar.date(byAdding: .minute, value: minDurationMinutes, to: start) ?? start
            endDay = calendar.startOfDay(for: end)
            return Result(dayDate: startDay, endDayDate: endDay, startTime: start, endTime: end, message: "Added \(minDurationMinutes) minutes.")
        }

        return Result(dayDate: startDay, endDayDate: endDay, startTime: start, endTime: end, message: nil)
    }

    // MARK: - Duration

    func applyDuration(minutes: Int, dayDate: Date, startTime: Date) -> DurationResult {
        let startDay = calendar.startOfDay(for: dayDate)

        // ✅ Ключевой момент: старт = день + выбранное время, НЕ startOfDay
        let start = combine(day: startDay, time: startTime)
        let end = calendar.date(byAdding: .minute, value: max(minDurationMinutes, minutes), to: start) ?? start

        return DurationResult(
            startTime: start,
            endTime: end,
            endDayDate: calendar.startOfDay(for: end)
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

        // только это правило: если в тот же день end <= start → переносим на следующий день
        if calendar.isDate(endDay, inSameDayAs: startDay), end <= start {
            let nextDay = calendar.date(byAdding: .day, value: 1, to: startDay) ?? startDay
            let fixedEnd = combine(day: nextDay, time: end)
            return (start, fixedEnd)
        }
        return (start, end)
    }
}

