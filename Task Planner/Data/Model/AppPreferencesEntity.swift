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
    var themeValue: String?

    var notificationsEnabled: Bool
    var defaultReminderOffsetMinutes: Int
    var defaultAllDayTimeMinutes: Int

    var theme: AppTheme {
        get { themeValue.flatMap(AppTheme.init(rawValue:)) ?? .system }
        set { themeValue = newValue.rawValue }
    }

    init(
        weekStartsOnMonday: Bool = true,
        showTasksInAppleCalendar: Bool = false,
        showAppleCalendarEventsInPlanner: Bool = false,
        taskPlannerCalendarIdentifier: String? = nil,
        themeValue: String? = AppTheme.system.rawValue,
        notificationsEnabled: Bool = true,
        defaultReminderOffsetMinutes: Int = 10,
        defaultAllDayTimeMinutes: Int = 9 * 60
    ) {
        self.weekStartsOnMonday = weekStartsOnMonday
        self.showTasksInAppleCalendar = showTasksInAppleCalendar
        self.showAppleCalendarEventsInPlanner = showAppleCalendarEventsInPlanner
        self.taskPlannerCalendarIdentifier = taskPlannerCalendarIdentifier
        self.themeValue = themeValue

        self.notificationsEnabled = notificationsEnabled
        self.defaultReminderOffsetMinutes = defaultReminderOffsetMinutes
        self.defaultAllDayTimeMinutes = defaultAllDayTimeMinutes
    }
}
