//
//  AppPreferencesEntity.swift
//  Task Planner
//
//  Created by Руслан Меланин on 09.02.2026.
//

import Foundation
import SwiftData

@Model
final class AppPreferencesEntity {
    var weekStartsOnMonday: Bool
    var showTasksInAppleCalendar: Bool
    var showAppleCalendarEventsInPlanner: Bool
    var taskPlannerCalendarIdentifier: String?

    var notificationsEnabled: Bool
    var defaultReminderOffsetMinutes: Int
    var defaultAllDayTimeMinutes: Int

    init(
        weekStartsOnMonday: Bool = true,
        showTasksInAppleCalendar: Bool = false,
        showAppleCalendarEventsInPlanner: Bool = false,
        taskPlannerCalendarIdentifier: String? = nil,
        notificationsEnabled: Bool = true,
        defaultReminderOffsetMinutes: Int = 10,
        defaultAllDayTimeMinutes: Int = 9 * 60
    ) {
        self.weekStartsOnMonday = weekStartsOnMonday
        self.showTasksInAppleCalendar = showTasksInAppleCalendar
        self.showAppleCalendarEventsInPlanner = showAppleCalendarEventsInPlanner
        self.taskPlannerCalendarIdentifier = taskPlannerCalendarIdentifier

        self.notificationsEnabled = notificationsEnabled
        self.defaultReminderOffsetMinutes = defaultReminderOffsetMinutes
        self.defaultAllDayTimeMinutes = defaultAllDayTimeMinutes
    }
}
