//
//  UnscheduledTasksUsageStore.swift
//  Task Planner
//

import Foundation

final class UnscheduledTasksUsageStore {
    private enum Key {
        static let hasUsedUnscheduledTasks = "hasUsedUnscheduledTasks"
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    var hasUsedUnscheduledTasks: Bool {
        get { userDefaults.bool(forKey: Key.hasUsedUnscheduledTasks) }
        set { userDefaults.set(newValue, forKey: Key.hasUsedUnscheduledTasks) }
    }
}
