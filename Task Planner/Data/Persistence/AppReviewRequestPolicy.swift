//
//  AppReviewRequestPolicy.swift
//  Task Planner
//

import Foundation

@MainActor
final class AppReviewRequestPolicy {
    static let paywallDidAppearNotification = Notification.Name(
        "AppReviewRequestPolicy.paywallDidAppear"
    )

    private enum Key {
        static let requestAttempted = "appReviewRequestAttempted"
        static let firstSuccessfulCompletionAt = "appReviewFirstSuccessfulCompletionAt"
        static let successfulCompletionDayKeys = "appReviewSuccessfulCompletionDayKeys"
    }

    private enum Threshold {
        static let completedScheduledOccurrences = 5
        static let successfulCompletionDays = 3
        static let minimumElapsedTime: TimeInterval = 72 * 60 * 60
    }

    private let userDefaults: UserDefaults
    private let calendar: Calendar

    init(
        userDefaults: UserDefaults = .standard,
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.userDefaults = userDefaults
        self.calendar = calendar
    }

    var requestAttempted: Bool {
        userDefaults.bool(forKey: Key.requestAttempted)
    }

    func recordSuccessfulCompletion(at date: Date = .now) {
        guard requestAttempted == false else { return }

        if userDefaults.object(forKey: Key.firstSuccessfulCompletionAt) as? Date == nil {
            userDefaults.set(date, forKey: Key.firstSuccessfulCompletionAt)
        }

        var dayKeys = successfulCompletionDayKeys
        dayKeys.insert(TaskEntity.dayKey(for: date, calendar: calendar))
        userDefaults.set(dayKeys.sorted(), forKey: Key.successfulCompletionDayKeys)
    }

    func isEligible(
        completedScheduledOccurrenceCount: Int,
        at date: Date = .now
    ) -> Bool {
        guard requestAttempted == false,
              completedScheduledOccurrenceCount >= Threshold.completedScheduledOccurrences,
              successfulCompletionDayKeys.count >= Threshold.successfulCompletionDays,
              let firstCompletionAt = userDefaults.object(
                forKey: Key.firstSuccessfulCompletionAt
              ) as? Date else {
            return false
        }

        return date.timeIntervalSince(firstCompletionAt) >= Threshold.minimumElapsedTime
    }

    @discardableResult
    func markRequestAttemptedIfNeeded() -> Bool {
        guard requestAttempted == false else { return false }
        userDefaults.set(true, forKey: Key.requestAttempted)
        return true
    }

    private var successfulCompletionDayKeys: Set<String> {
        Set(userDefaults.stringArray(forKey: Key.successfulCompletionDayKeys) ?? [])
    }
}
