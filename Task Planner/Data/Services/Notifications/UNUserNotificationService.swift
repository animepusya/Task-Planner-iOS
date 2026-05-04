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
                .requestAuthorization(options: [.alert, .sound])
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
        let reminders = uniqueRemindersPreservingLast(reminders)
        if reminders.isEmpty == false {
            center.removePendingNotificationRequests(withIdentifiers: reminders.map(\.id))
        }

        for r in reminders {
            let content = UNMutableNotificationContent()
            content.title = r.taskTitle
            content.body = String(localized: "Reminder")
            content.sound = .default
            content.userInfo = [
                "taskId": r.taskId,
                "occurrenceKey": r.occurrenceKey,
                "reminderId": r.id
            ]

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

    func cancel(taskIDs: [String]) async {
        await cancel(taskIDs: taskIDs, matching: [])
    }

    func cancel(taskIDs: [String], matching reminders: [PendingReminder]) async {
        guard !taskIDs.isEmpty else { return }

        let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        let ids = matchingPendingRequestIDs(
            in: requests,
            taskIDs: taskIDs,
            reminders: reminders
        )

        #if DEBUG
        if ids.isEmpty == false {
            print("TaskPlannerNotifications cancel matched ids=\(ids)")
        }
        #endif

        guard !ids.isEmpty else { return }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    func cancelAll() async {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    #if DEBUG
    func debugLogPendingRequests(label: String) async {
        let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        print("TaskPlannerNotifications \(label) pendingCount=\(requests.count)")

        for request in requests.sorted(by: { $0.identifier < $1.identifier }) {
            let fireDate = fireDateDescription(for: request)
            print(
                "TaskPlannerNotifications id=\(request.identifier) title=\(request.content.title) body=\(request.content.body) fireDate=\(fireDate) userInfo=\(request.content.userInfo)"
            )
        }
    }
    #endif

    private func uniqueRemindersPreservingLast(_ reminders: [PendingReminder]) -> [PendingReminder] {
        var indexesByID: [String: Int] = [:]
        var unique: [PendingReminder] = []
        unique.reserveCapacity(reminders.count)

        for reminder in reminders {
            if let existingIndex = indexesByID[reminder.id] {
                unique[existingIndex] = reminder
            } else {
                indexesByID[reminder.id] = unique.count
                unique.append(reminder)
            }
        }

        return unique
    }

    private func matchingPendingRequestIDs(
        in requests: [UNNotificationRequest],
        taskIDs: [String],
        reminders: [PendingReminder]
    ) -> [String] {
        let taskIDs = Set(taskIDs)
        let taskTokens = Set(taskIDs.flatMap { taskIDMatchTokens(for: $0) })
        let directReminderIDs = Set(reminders.flatMap { reminderIdentifiers(for: $0) })
        let fireDateTokens = Set(reminders.flatMap { fireDateIdentifierTokens(for: $0.fireDate) })
        let reminderFireDates = reminders.map(\.fireDate)

        var ids: [String] = []
        ids.reserveCapacity(requests.count)

        for request in requests {
            if directReminderIDs.contains(request.identifier) {
                ids.append(request.identifier)
                continue
            }

            if let requestTaskID = request.content.userInfo["taskId"] as? String,
               taskIDs.contains(requestTaskID) {
                ids.append(request.identifier)
                continue
            }

            if taskTokens.contains(where: { request.identifier.contains($0) }) {
                ids.append(request.identifier)
                continue
            }

            if matchesFireDateBasedLegacyRequest(
                request,
                fireDateTokens: fireDateTokens,
                reminderFireDates: reminderFireDates
            ) {
                ids.append(request.identifier)
            }
        }

        return ids
    }

    private func reminderIdentifiers(for reminder: PendingReminder) -> [String] {
        let taskID = reminder.taskId
        let occurrenceKey = reminder.occurrenceKey
        let fireDateTokens = fireDateIdentifierTokens(for: reminder.fireDate)

        var ids = [
            reminder.id,
            "\(taskID)_\(occurrenceKey)",
            "task-\(taskID)-\(occurrenceKey)"
        ]

        ids.append(contentsOf: fireDateTokens.flatMap { token in
            [
                "\(taskID)_\(token)",
                "task-\(taskID)-\(token)"
            ]
        })

        return ids
    }

    private func taskIDMatchTokens(for taskID: String) -> [String] {
        var tokens: [String] = [
            taskID,
            "\(taskID)_",
            "task-\(taskID)-"
        ]

        for scheme in ["x-coredata://", "x-swiftdata://"] {
            if let urlToken = embeddedURLToken(in: taskID, scheme: scheme) {
                tokens.append(urlToken)
                tokens.append(contentsOf: pathTailTokens(from: urlToken))
            }
        }

        return Array(Set(tokens.filter { isStrongTaskToken($0) }))
    }

    private func embeddedURLToken(in value: String, scheme: String) -> String? {
        guard let range = value.range(of: scheme) else { return nil }

        let suffix = value[range.lowerBound...]
        let end = suffix.firstIndex { char in
            char == ")" || char == "," || char == " " || char == "]"
        } ?? suffix.endIndex

        return String(suffix[..<end])
    }

    private func pathTailTokens(from token: String) -> [String] {
        let parts = token
            .split(separator: "/")
            .map(String.init)
            .filter { $0.isEmpty == false }

        guard parts.count >= 2 else { return [] }

        let lastTwo = parts.suffix(2).joined(separator: "/")
        let lastThree = parts.suffix(3).joined(separator: "/")
        return [lastTwo, lastThree]
    }

    private func isStrongTaskToken(_ token: String) -> Bool {
        if token.count >= 12 { return true }
        return token.contains("://") || token.contains("/")
    }

    private func matchesFireDateBasedLegacyRequest(
        _ request: UNNotificationRequest,
        fireDateTokens: Set<String>,
        reminderFireDates: [Date]
    ) -> Bool {
        guard looksLikeTaskPlannerReminder(request) else { return false }

        if fireDateTokens.contains(where: { request.identifier.contains($0) }) {
            return true
        }

        guard identifierLooksFireDateBased(request.identifier) else { return false }
        guard let requestFireDate = fireDate(for: request) else { return false }
        return reminderFireDates.contains { abs(requestFireDate.timeIntervalSince($0)) <= 90 }
    }

    private func identifierLooksFireDateBased(_ identifier: String) -> Bool {
        if identifier.contains("T") && identifier.contains(":") {
            return true
        }

        var digitRun = 0
        for scalar in identifier.unicodeScalars {
            if CharacterSet.decimalDigits.contains(scalar) {
                digitRun += 1
                if digitRun >= 10 { return true }
            } else {
                digitRun = 0
            }
        }

        return false
    }

    private func looksLikeTaskPlannerReminder(_ request: UNNotificationRequest) -> Bool {
        let body = request.content.body.trimmingCharacters(in: .whitespacesAndNewlines)
        if body == String(localized: "Reminder") || body == "Reminder" {
            return true
        }

        if request.content.userInfo["reminderId"] != nil {
            return true
        }

        return request.identifier.localizedCaseInsensitiveContains("reminder")
            || request.identifier.localizedCaseInsensitiveContains("task")
            || request.content.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private func fireDateIdentifierTokens(for date: Date) -> [String] {
        let seconds = Int(date.timeIntervalSince1970)
        let milliseconds = Int(date.timeIntervalSince1970 * 1000)
        return [
            String(seconds),
            String(milliseconds),
            iso8601IdentifierString(from: date)
        ]
    }

    private func fireDate(for request: UNNotificationRequest) -> Date? {
        if let trigger = request.trigger as? UNCalendarNotificationTrigger {
            return trigger.nextTriggerDate()
        }

        if let trigger = request.trigger as? UNTimeIntervalNotificationTrigger {
            return Date().addingTimeInterval(trigger.timeInterval)
        }

        return nil
    }

    private func iso8601IdentifierString(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    private func fireDateDescription(for request: UNNotificationRequest) -> String {
        guard let date = fireDate(for: request) else { return "nil" }
        return iso8601IdentifierString(from: date)
    }
}
