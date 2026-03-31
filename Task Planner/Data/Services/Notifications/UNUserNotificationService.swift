//
//  UNUserNotificationService.swift
//  Task Planner
//
//  Created by Руслан Меланин on 03.03.2026.
//

import Foundation
import UserNotifications
import UIKit

@MainActor
final class UNUserNotificationService: NotificationService {

    func getAuthorizationStatus() async -> NotificationAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .authorized, .provisional, .ephemeral:
            return .authorized
        @unknown default:
            return .notDetermined
        }
    }

    func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    func scheduleReminders(_ reminders: [PendingReminder]) async {
        let center = UNUserNotificationCenter.current()

        for r in reminders {
            let content = UNMutableNotificationContent()
            content.title = r.taskTitle
            content.body = String(localized: "Reminder")
            content.sound = .default

            let triggerDate = r.fireDate
            if triggerDate <= Date() {
                // Не планируем в прошлом — тихо пропускаем.
                continue
            }

            let comps = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: triggerDate
            )

            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

            let request = UNNotificationRequest(
                identifier: r.id,
                content: content,
                trigger: trigger
            )

            do {
                try await center.add(request)
            } catch {
                // Best-effort
            }
        }
    }

    func cancel(ids: [String]) async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    func cancelAll() async {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
