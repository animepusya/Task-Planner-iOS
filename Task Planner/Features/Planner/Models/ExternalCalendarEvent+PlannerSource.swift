//
//  ExternalCalendarEvent+PlannerSource.swift
//  Task Planner
//
//  Created by Codex on 15.04.2026.
//

import Foundation

extension ExternalCalendarEvent {
    @MainActor
    func plannerSource() -> PlannerExternalEventSource {
        PlannerExternalEventSource(
            id: id,
            title: title,
            startDate: startDate,
            endDate: endDate,
            isAllDay: isAllDay,
            calendarTitle: calendarTitle,
            mappedColor: TaskColor.closest(to: calendarColor),
            location: location
        )
    }
}
