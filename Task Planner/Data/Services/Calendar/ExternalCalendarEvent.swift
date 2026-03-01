//
//  ExternalCalendarEvent.swift
//  Task Planner
//
//  Created by Руслан Меланин on 01.03.2026.
//

import Foundation
import EventKit
import SwiftUI

struct ExternalCalendarEvent: Identifiable, Hashable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let calendarTitle: String
    let calendarColor: Color
    let location: String?

    init(event: EKEvent) {
        self.id = event.eventIdentifier ?? UUID().uuidString
        self.title = event.title ?? "Untitled"
        self.startDate = event.startDate
        self.endDate = event.endDate
        self.isAllDay = event.isAllDay
        self.calendarTitle = event.calendar.title
        self.calendarColor = Color(UIColor(cgColor: event.calendar.cgColor))
        self.location = event.location
    }
}
