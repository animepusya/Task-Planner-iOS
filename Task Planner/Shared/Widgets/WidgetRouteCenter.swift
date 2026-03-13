//
//  WidgetRouteCenter.swift
//  Task Planner
//
//  Created by Руслан Меланин on 13.03.2026.
//

import Foundation

extension Notification.Name {
    static let widgetPlannerDayRequested = Notification.Name("widgetPlannerDayRequested")
}

enum WidgetRouteCenter {
    static func postPlannerDay(_ day: Date) {
        NotificationCenter.default.post(name: .widgetPlannerDayRequested, object: day)
    }
}
