//
//  SheetRoute.swift
//  Task Planner
//
//  Created by Руслан Меланин on 09.02.2026.
//

import Foundation
import SwiftData

enum SheetRoute: Identifiable {
    case taskEditor(taskId: PersistentIdentifier?, preselectedDay: Date)
    case settings
    case notifications

    var id: String {
        switch self {
        case .taskEditor(let taskId, let day):
            let taskKey = taskId.map { String(describing: $0) } ?? "new"
            return "taskEditor-\(taskKey)-\(Int(day.timeIntervalSince1970))"
        case .settings:
            return "settings"
        case .notifications:
            return "notifications"
        }
    }
}
