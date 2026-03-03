//
//  NotificationService.swift
//  Task Planner
//
//  Created by Руслан Меланин on 03.03.2026.
//

import Foundation

enum NotificationAuthorizationStatus: Equatable {
    case notDetermined
    case denied
    case authorized
}

struct PendingReminder: Identifiable, Hashable {
    let id: String
    let taskId: String
    let taskTitle: String
    let taskColor: TaskColor
    let fireDate: Date
    let dayKey: Date
    let isAllDay: Bool
}

@MainActor
protocol NotificationService {
    func getAuthorizationStatus() async -> NotificationAuthorizationStatus
    func requestAuthorization() async -> Bool
    func openSystemSettings()

    func scheduleReminders(_ reminders: [PendingReminder]) async
    func cancel(ids: [String]) async
    func cancelAll() async
}
