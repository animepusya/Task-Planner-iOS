//
//  SelectWidgetDayIntent.swift
//  TaskPlannerWidgetsExtension
//
//  Created by Руслан Меланин on 13.03.2026.
//

import AppIntents
import WidgetKit

struct SelectWidgetDayIntent: AppIntent {
    static var title: LocalizedStringResource = "Select Widget Day"
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Day Key")
    var dayKey: String

    init() {}

    init(dayKey: String) {
        self.dayKey = dayKey
    }

    func perform() async throws -> some IntentResult {
        WidgetStore.setSelectedDayKey(dayKey)
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetShared.WidgetKind.plannerHome)
        return .result()
    }
}
