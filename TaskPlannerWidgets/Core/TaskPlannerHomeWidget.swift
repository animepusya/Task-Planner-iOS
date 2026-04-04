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
                .widgetPreferredColorScheme(entry.appTheme.preferredColorScheme)
        }
        .configurationDisplayName("Task Planner")
        .description("A rolling 7-day planner with interactive day selection.")
        .supportedFamilies([.systemLarge])
        .contentMarginsDisabled()
    }
}

private extension View {
    @ViewBuilder
    func widgetPreferredColorScheme(_ colorScheme: ColorScheme?) -> some View {
        if let colorScheme {
            environment(\.colorScheme, colorScheme)
        } else {
            self
        }
    }
}
