//
//  TaskPlannerHomeWidget.swift
//  TaskPlannerWidgetsExtension
//
//  Created by Руслан Меланин on 13.03.2026.
//

import WidgetKit
import SwiftUI

struct TaskPlannerHomeWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: WidgetShared.WidgetKind.plannerHome,
            intent: TaskPlannerWidgetConfigurationIntent.self,
            provider: TaskPlannerHomeWidgetProvider()
        ) { entry in
            TaskPlannerWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Task Planner")
        .description("A rolling 7-day planner with interactive day selection.")
        .supportedFamilies([.systemLarge])
        .contentMarginsDisabled()
    }
}
