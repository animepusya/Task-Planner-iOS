//
//  SheetRoute.swift
//  Task Planner
//
//  Created by Руслан Меланин on 09.02.2026.
//

import Foundation
import SwiftData

enum SheetRoute: Identifiable {
    case taskEditor(taskId: PersistentIdentifier?, preselectedDay: Date, mode: TaskEditorMode)
    case notifications
    case recurringBaseTasks

    var id: String {
        switch self {
        case .taskEditor(let taskId, let day, let mode):
            let taskKey = taskId.map { String(describing: $0) } ?? "new"
            return "taskEditor-\(taskKey)-\(Int(day.timeIntervalSince1970))-\(mode.rawValue)"
        case .notifications:
            return "notifications"
        case .recurringBaseTasks:
            return "recurringBaseTasks"
        }
    }
}
