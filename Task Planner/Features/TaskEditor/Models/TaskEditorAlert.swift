//
//  TaskEditorAlert.swift
//  Task Planner
//
//  Created by Руслан Меланин on 14.02.2026.
//

import Foundation

struct TaskEditorAlert: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
}
