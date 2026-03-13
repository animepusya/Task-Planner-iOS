//
//  TaskPlannerHomeWidgetProvider.swift
//  TaskPlannerWidgetsExtension
//
//  Created by Руслан Меланин on 13.03.2026.
//

import WidgetKit
import AppIntents
import Foundation

struct TaskPlannerHomeEntry: TimelineEntry {
    let date: Date
    let configuration: TaskPlannerWidgetConfigurationIntent
    let visibleDays: [PlannerWidgetDaySnapshot]
    let selectedDayKey: String

    var selectedDay: PlannerWidgetDaySnapshot? {
        visibleDays.first(where: { $0.dayKey == selectedDayKey }) ?? visibleDays.first
    }
}

struct TaskPlannerHomeWidgetProvider: AppIntentTimelineProvider {
    typealias Entry = TaskPlannerHomeEntry
    typealias Intent = TaskPlannerWidgetConfigurationIntent

    func placeholder(in context: Context) -> TaskPlannerHomeEntry {
        let snapshot = PlannerWidgetSnapshot.empty()
        let visible = snapshot.rollingWindow(from: .now, count: 7)
        let selected = WidgetStore.selectedDayKey()
        return TaskPlannerHomeEntry(
            date: .now,
            configuration: .init(),
            visibleDays: visible,
            selectedDayKey: selected
        )
    }

    func snapshot(for configuration: TaskPlannerWidgetConfigurationIntent, in context: Context) async -> TaskPlannerHomeEntry {
        makeEntry(configuration: configuration, now: .now)
    }

    func timeline(for configuration: TaskPlannerWidgetConfigurationIntent, in context: Context) async -> Timeline<TaskPlannerHomeEntry> {
        let entry = makeEntry(configuration: configuration, now: .now)
        let nextRefresh = nextRefreshDate(after: .now)
        return Timeline(entries: [entry], policy: .after(nextRefresh))
    }

    private func makeEntry(configuration: TaskPlannerWidgetConfigurationIntent, now: Date) -> TaskPlannerHomeEntry {
        let snapshot = WidgetStore.loadSnapshot()
        let visibleDays = snapshot.rollingWindow(from: now, count: 7)

        let fallbackKey = WidgetDayKey.make(from: now)
        let storedKey = WidgetStore.selectedDayKey(fallbackTo: now)
        let selectedKey = visibleDays.contains(where: { $0.dayKey == storedKey }) ? storedKey : fallbackKey

        return TaskPlannerHomeEntry(
            date: now,
            configuration: configuration,
            visibleDays: visibleDays,
            selectedDayKey: selectedKey
        )
    }

    private func nextRefreshDate(after date: Date, calendar: Calendar = .current) -> Date {
        let startOfTomorrow = calendar.date(
            byAdding: .day,
            value: 1,
            to: calendar.startOfDay(for: date)
        ) ?? date.addingTimeInterval(60 * 60 * 24)

        return calendar.date(byAdding: .minute, value: 1, to: startOfTomorrow) ?? startOfTomorrow
    }
}
