//
//  TaskEditorCategoryCoordinator.swift
//  Task Planner
//
//  Created by Руслан Меланин on 11.02.2026.
//

import Foundation

struct TaskEditorCategoryCoordinator {
    func ensureCategoryIsValid(current: String, available: [String]) -> String {
        guard !available.isEmpty else { return current }

        if available.contains(current) { return current }

        if let work = available.first(where: CategorySystem.matchesWorkTitle(_:)) {
            return work
        }
        return available[0]
    }
}
