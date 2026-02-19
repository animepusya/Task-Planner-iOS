//
//  TaskStatisticsMinutes.swift
//  Task Planner
//
//  Created by Руслан Меланин on 18.02.2026.
//

import Foundation

enum TaskStatisticsMinutes {
    /// For statistics only:
    /// - all-day tasks contribute 0
    /// - otherwise use the existing overlap logic (including repeats)
    static func minutesOnDay(
        task: TaskEntity,
        day: Date,
        weekStartsOnMonday: Bool
    ) -> Int {
        guard task.isAllDay == false else { return 0 }
        return TaskDayOverlap.minutesOnDay(task: task, day: day, weekStartsOnMonday: weekStartsOnMonday)
    }
}
