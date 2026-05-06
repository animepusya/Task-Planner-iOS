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
                "schemaVersion": reminderSchemaVersion,
                "taskId": r.taskId,
                "legacyTaskId": r.legacyTaskId,
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

    func reconcile(reminders: [PendingReminder]) async {
        let center = UNUserNotificationCenter.current()
        let reminders = uniqueRemindersPreservingLast(reminders)
        let requests = await center.pendingNotificationRequests()
        let plan = reconciliationPlan(
            in: requests,
            validReminders: reminders
        )
        let ids = uniqueIDs(from: plan.cancellations)

        #if DEBUG
        let validIDs = reminders.map(\.id).sorted()
        print("TaskPlannerNotifications reconcile validReminderCount=\(validIDs.count) validReminderIDs=\(validIDs)")
        print("TaskPlannerNotifications reconcile scheduleIDs=\(plan.remindersToSchedule.map(\.id).sorted())")
        logCancellationMatches(plan.cancellations, label: "reconcile")
        logDuplicateGroups(plan.cancellations, label: "reconcile")
        logWeakReminderMatches(plan.weakMatches, label: "reconcile")
        #endif

        if ids.isEmpty == false {
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }

        await scheduleReminders(plan.remindersToSchedule)
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
        let matches = matchingPendingRequestIDs(
            in: requests,
            taskIDs: taskIDs,
            reminders: reminders
        )

        #if DEBUG
        logCancellationMatches(matches, label: "targeted cancel")
        #endif

        guard !matches.isEmpty else { return }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: uniqueIDs(from: matches))
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

    private struct PendingRequestCancellation: Hashable {
        let id: String
        let reason: String
        let logicalKey: String?
    }

    private struct ReconciliationPlan {
        let cancellations: [PendingRequestCancellation]
        let remindersToSchedule: [PendingReminder]
        let weakMatches: [String]
    }

    private struct PendingReminderRequestMatch {
        let request: UNNotificationRequest
        let reminder: PendingReminder
        let reason: String
        let logicalKey: String
    }

    private let reminderSchemaVersion = 2

    private func matchingPendingRequestIDs(
        in requests: [UNNotificationRequest],
        taskIDs: [String],
        reminders: [PendingReminder]
    ) -> [PendingRequestCancellation] {
        let taskIDs = Set(taskIDs.filter { $0.isEmpty == false })
        let taskTokens = Set(taskIDs.flatMap { taskIDMatchTokens(for: $0) })
        let directReminderIDs = reminderIdentifierLogicalKeys(for: reminders)
        let metadataLogicalKeys = reminderMetadataLogicalKeys(for: reminders)
        let fireDateTokens = Set(reminders.flatMap { fireDateIdentifierTokens(for: $0.fireDate) })
        let reminderFireDates = reminders.map(\.fireDate)

        var matches: [PendingRequestCancellation] = []
        matches.reserveCapacity(requests.count)

        for request in requests {
            if let logicalKey = directReminderIDs[request.identifier] {
                matches.append(.init(id: request.identifier, reason: "direct current/legacy reminder identifier", logicalKey: logicalKey))
                continue
            }

            if let logicalKey = metadataLogicalKey(for: request, metadataLogicalKeys: metadataLogicalKeys) {
                matches.append(.init(id: request.identifier, reason: "notification metadata matches valid reminder", logicalKey: logicalKey))
                continue
            }

            if notificationTaskIDs(from: request).contains(where: { taskIDs.contains($0) }) {
                matches.append(.init(id: request.identifier, reason: "notification metadata matches task id", logicalKey: nil))
                continue
            }

            if taskTokens.contains(where: { request.identifier.contains($0) }) {
                matches.append(.init(id: request.identifier, reason: "identifier contains task token", logicalKey: nil))
                continue
            }

            if matchesFireDateBasedLegacyRequest(
                request,
                fireDateTokens: fireDateTokens,
                reminderFireDates: reminderFireDates
            ) {
                matches.append(.init(id: request.identifier, reason: "legacy fire-date reminder identifier", logicalKey: nil))
            }
        }

        return matches
    }

    private func reconciliationPlan(
        in requests: [UNNotificationRequest],
        validReminders reminders: [PendingReminder]
    ) -> ReconciliationPlan {
        let matches = currentReminderMatches(in: requests, validReminders: reminders)
        let matchedRequestIDs = Set(matches.map { $0.request.identifier })
        let matchesByLogicalKey = Dictionary(grouping: matches, by: \.logicalKey)
        let remindersByLogicalKey = Dictionary(uniqueKeysWithValues: reminders.map { (logicalKey(for: $0), $0) })

        var cancellations: [PendingRequestCancellation] = []
        var remindersToSchedule: [PendingReminder] = []
        var keptReminderIDs: Set<String> = []

        for (logicalKey, reminder) in remindersByLogicalKey {
            let group = matchesByLogicalKey[logicalKey] ?? []
            let exactCurrent = group.filter { $0.request.identifier == reminder.id }
            let keep = exactCurrent.first { requestMatchesDesired($0.request, reminder: reminder) }

            if let keep {
                keptReminderIDs.insert(reminder.id)
                for match in group where match.request.identifier != keep.request.identifier {
                    cancellations.append(
                        .init(
                            id: match.request.identifier,
                            reason: "duplicate reminder request",
                            logicalKey: logicalKey
                        )
                    )
                }
            } else {
                remindersToSchedule.append(reminder)
                for match in group {
                    cancellations.append(
                        .init(
                            id: match.request.identifier,
                            reason: match.request.identifier == reminder.id ? "changed reminder request" : "stale legacy reminder request",
                            logicalKey: logicalKey
                        )
                    )
                }
            }
        }

        for reminder in reminders where keptReminderIDs.contains(reminder.id) == false {
            if matchesByLogicalKey[logicalKey(for: reminder)] == nil,
               remindersToSchedule.contains(reminder) == false {
                remindersToSchedule.append(reminder)
            }
        }

        var weakMatches: [String] = []
        for request in requests {
            guard matchedRequestIDs.contains(request.identifier) == false else { continue }

            if let evidence = highConfidenceReminderEvidence(for: request) {
                cancellations.append(
                    .init(
                        id: request.identifier,
                        reason: "orphan reminder request (\(evidence))",
                        logicalKey: nil
                    )
                )
                continue
            }

            #if DEBUG
            if let evidence = weakReminderEvidence(for: request) {
                weakMatches.append("\(request.identifier): \(evidence)")
            }
            #endif
        }

        return ReconciliationPlan(
            cancellations: cancellations,
            remindersToSchedule: remindersToSchedule,
            weakMatches: weakMatches
        )
    }

    private func currentReminderMatches(
        in requests: [UNNotificationRequest],
        validReminders reminders: [PendingReminder]
    ) -> [PendingReminderRequestMatch] {
        let directReminderIDs = reminderIdentifierReminders(for: reminders)
        let metadataReminders = reminderMetadataReminders(for: reminders)

        var matches: [PendingReminderRequestMatch] = []
        matches.reserveCapacity(requests.count)

        for request in requests {
            if let reminder = directReminderIDs[request.identifier] {
                matches.append(
                    .init(
                        request: request,
                        reminder: reminder,
                        reason: "current or known legacy reminder identifier",
                        logicalKey: logicalKey(for: reminder)
                    )
                )
                continue
            }

            if let reminder = metadataReminder(for: request, metadataReminders: metadataReminders) {
                matches.append(
                    .init(
                        request: request,
                        reminder: reminder,
                        reason: "notification metadata",
                        logicalKey: logicalKey(for: reminder)
                    )
                )
            }
        }

        return matches
    }

    private func reminderIdentifiers(for reminder: PendingReminder) -> [String] {
        let occurrenceKey = reminder.occurrenceKey
        let fireDateTokens = fireDateIdentifierTokens(for: reminder.fireDate)

        var ids = [reminder.id]

        for taskID in taskIdentifiers(for: reminder) {
            ids.append(contentsOf: [
                "\(taskID)_\(occurrenceKey)",
                "task-\(taskID)-\(occurrenceKey)"
            ])

            ids.append(contentsOf: fireDateTokens.flatMap { token in
                [
                    "\(taskID)_\(token)",
                    "task-\(taskID)-\(token)"
                ]
            })
        }

        return Array(Set(ids.filter { $0.isEmpty == false }))
    }

    private func reminderIdentifierLogicalKeys(for reminders: [PendingReminder]) -> [String: String] {
        var keys: [String: String] = [:]

        for reminder in reminders {
            let logicalKey = logicalKey(for: reminder)
            for id in reminderIdentifiers(for: reminder) {
                keys[id] = logicalKey
            }
        }

        return keys
    }

    private func reminderIdentifierReminders(for reminders: [PendingReminder]) -> [String: PendingReminder] {
        var values: [String: PendingReminder] = [:]

        for reminder in reminders {
            for id in reminderIdentifiers(for: reminder) {
                values[id] = reminder
            }
        }

        return values
    }

    private func reminderMetadataLogicalKeys(for reminders: [PendingReminder]) -> [String: String] {
        var keys: [String: String] = [:]

        for reminder in reminders {
            let logicalKey = logicalKey(for: reminder)
            for taskID in taskIdentifiers(for: reminder) {
                keys[metadataLogicalKey(taskID: taskID, occurrenceKey: reminder.occurrenceKey)] = logicalKey
            }
            keys[metadataLogicalKey(taskID: reminder.id, occurrenceKey: reminder.occurrenceKey)] = logicalKey
        }

        return keys
    }

    private func reminderMetadataReminders(for reminders: [PendingReminder]) -> [String: PendingReminder] {
        var values: [String: PendingReminder] = [:]

        for reminder in reminders {
            for taskID in taskIdentifiers(for: reminder) {
                values[metadataLogicalKey(taskID: taskID, occurrenceKey: reminder.occurrenceKey)] = reminder
            }
            values[metadataLogicalKey(taskID: reminder.id, occurrenceKey: reminder.occurrenceKey)] = reminder
        }

        return values
    }

    private func metadataLogicalKey(for request: UNNotificationRequest, metadataLogicalKeys: [String: String]) -> String? {
        if let reminderID = request.content.userInfo["reminderId"] as? String,
           let occurrenceKey = request.content.userInfo["occurrenceKey"] as? String,
           let logicalKey = metadataLogicalKeys[metadataLogicalKey(taskID: reminderID, occurrenceKey: occurrenceKey)] {
            return logicalKey
        }

        guard let occurrenceKey = request.content.userInfo["occurrenceKey"] as? String else {
            return nil
        }

        for taskID in notificationTaskIDs(from: request) {
            if let logicalKey = metadataLogicalKeys[metadataLogicalKey(taskID: taskID, occurrenceKey: occurrenceKey)] {
                return logicalKey
            }
        }

        return nil
    }

    private func metadataReminder(for request: UNNotificationRequest, metadataReminders: [String: PendingReminder]) -> PendingReminder? {
        if let reminderID = request.content.userInfo["reminderId"] as? String,
           let occurrenceKey = request.content.userInfo["occurrenceKey"] as? String,
           let reminder = metadataReminders[metadataLogicalKey(taskID: reminderID, occurrenceKey: occurrenceKey)] {
            return reminder
        }

        guard let occurrenceKey = request.content.userInfo["occurrenceKey"] as? String else {
            return nil
        }

        for taskID in notificationTaskIDs(from: request) {
            if let reminder = metadataReminders[metadataLogicalKey(taskID: taskID, occurrenceKey: occurrenceKey)] {
                return reminder
            }
        }

        return nil
    }

    private func metadataLogicalKey(taskID: String, occurrenceKey: String) -> String {
        "\(taskID)|\(occurrenceKey)"
    }

    private func logicalKey(for reminder: PendingReminder) -> String {
        "\(reminder.taskId)|\(reminder.occurrenceKey)"
    }

    private func taskIdentifiers(for reminder: PendingReminder) -> [String] {
        Array(Set([reminder.taskId, reminder.legacyTaskId].filter { $0.isEmpty == false }))
    }

    private func notificationTaskIDs(from request: UNNotificationRequest) -> [String] {
        let userInfo = request.content.userInfo
        return [
            userInfo["taskId"] as? String,
            userInfo["legacyTaskId"] as? String
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { $0.isEmpty == false }
    }

    private func uniqueIDs(from matches: [PendingRequestCancellation]) -> [String] {
        var seen: Set<String> = []
        var ids: [String] = []
        ids.reserveCapacity(matches.count)

        for match in matches {
            if seen.insert(match.id).inserted {
                ids.append(match.id)
            }
        }

        return ids
    }

    private func requestMatchesDesired(_ request: UNNotificationRequest, reminder: PendingReminder) -> Bool {
        guard request.identifier == reminder.id else { return false }
        guard request.content.title == reminder.taskTitle else { return false }
        guard request.content.body == String(localized: "Reminder") else { return false }
        guard let requestFireDate = fireDate(for: request),
              Calendar.current.isDate(requestFireDate, equalTo: reminder.fireDate, toGranularity: .minute) else {
            return false
        }

        let userInfo = request.content.userInfo
        return schemaVersion(from: userInfo) == reminderSchemaVersion
            && userInfoString(userInfo, key: "taskId") == reminder.taskId
            && userInfoString(userInfo, key: "legacyTaskId") == reminder.legacyTaskId
            && userInfoString(userInfo, key: "occurrenceKey") == reminder.occurrenceKey
            && userInfoString(userInfo, key: "reminderId") == reminder.id
    }

    private func highConfidenceReminderEvidence(for request: UNNotificationRequest) -> String? {
        if hasReminderMetadata(request) {
            return "notification metadata"
        }

        if request.identifier.hasPrefix("reminder-v2-") {
            return "v2 reminder prefix"
        }

        if isKnownHistoricalReminderIdentifier(request.identifier) {
            return "known historical reminder identifier"
        }

        return nil
    }

    private func hasReminderMetadata(_ request: UNNotificationRequest) -> Bool {
        request.content.userInfo["schemaVersion"] != nil
            || request.content.userInfo["reminderId"] != nil
            || request.content.userInfo["taskId"] != nil
            || request.content.userInfo["legacyTaskId"] != nil
    }

    private func isKnownHistoricalReminderIdentifier(_ identifier: String) -> Bool {
        if identifier.hasPrefix("task-"), identifierContainsDayKey(identifier) {
            return true
        }

        return identifier.range(
            of: #"_[0-9]{4}-[0-9]{2}-[0-9]{2}"#,
            options: .regularExpression
        ) != nil
    }

    private func identifierContainsDayKey(_ identifier: String) -> Bool {
        identifier.range(
            of: #"[0-9]{4}-[0-9]{2}-[0-9]{2}"#,
            options: .regularExpression
        ) != nil
    }

    private func schemaVersion(from userInfo: [AnyHashable: Any]) -> Int? {
        if let value = userInfo["schemaVersion"] as? Int {
            return value
        }

        if let value = userInfo["schemaVersion"] as? NSNumber {
            return value.intValue
        }

        if let value = userInfo["schemaVersion"] as? String {
            return Int(value)
        }

        return nil
    }

    private func userInfoString(_ userInfo: [AnyHashable: Any], key: String) -> String? {
        (userInfo[key] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
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
        guard highConfidenceReminderEvidence(for: request) != nil else { return false }

        if fireDateTokens.contains(where: { request.identifier.contains($0) }) {
            return true
        }

        guard isKnownHistoricalReminderIdentifier(request.identifier) else { return false }
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

    #if DEBUG
    private func weakReminderEvidence(for request: UNNotificationRequest) -> String? {
        let body = request.content.body.trimmingCharacters(in: .whitespacesAndNewlines)
        if body == String(localized: "Reminder") || body == "Reminder" {
            return "reminder body text"
        }

        let title = request.content.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if identifierLooksFireDateBased(request.identifier),
           title.isEmpty == false || body.isEmpty == false {
            return "date-like identifier with visible content"
        }

        if request.identifier.localizedCaseInsensitiveContains("reminder") {
            return "identifier contains reminder"
        }

        if request.identifier.localizedCaseInsensitiveContains("task") {
            return "identifier contains task"
        }

        return nil
    }
    #endif

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

    #if DEBUG
    private func logCancellationMatches(_ matches: [PendingRequestCancellation], label: String) {
        guard matches.isEmpty == false else {
            print("TaskPlannerNotifications \(label) matchedCancelCount=0")
            return
        }

        print("TaskPlannerNotifications \(label) matchedCancelCount=\(matches.count)")
        for match in matches.sorted(by: { $0.id < $1.id }) {
            print(
                "TaskPlannerNotifications \(label) cancel id=\(match.id) reason=\(match.reason) logicalKey=\(match.logicalKey ?? "nil")"
            )
        }
    }

    private func logDuplicateGroups(_ matches: [PendingRequestCancellation], label: String) {
        let groups = Dictionary(grouping: matches.compactMap { match -> PendingRequestCancellation? in
            guard match.logicalKey != nil else { return nil }
            return match
        }, by: { $0.logicalKey ?? "" })
        .filter { $0.value.count > 1 }

        guard groups.isEmpty == false else {
            print("TaskPlannerNotifications \(label) duplicateGroups=[]")
            return
        }

        let descriptions = groups
            .map { key, matches in
                "\(key):\(matches.map(\.id).sorted())"
            }
            .sorted()

        print("TaskPlannerNotifications \(label) duplicateGroups=\(descriptions)")
    }

    private func logWeakReminderMatches(_ matches: [String], label: String) {
        guard matches.isEmpty == false else {
            print("TaskPlannerNotifications \(label) weakMatches=[]")
            return
        }

        print("TaskPlannerNotifications \(label) weakMatchesKept=\(matches.sorted())")
    }
    #endif
}
