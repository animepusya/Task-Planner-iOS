//
//  TaskPlannerWidgetConfigurationIntent.swift
//  TaskPlannerWidgetsExtension
//
//  Created by Руслан Меланин on 13.03.2026.
//

import AppIntents

struct TaskPlannerWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Planner Widget"
    static var description = IntentDescription("Shows the next 7 days and tasks for the selected day.")
}
