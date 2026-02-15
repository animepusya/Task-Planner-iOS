//
//  TaskStat.swift
//  Task Planner
//
//  Created by Руслан Меланин on 15.02.2026.
//

import Foundation

struct TaskStat: Identifiable, Hashable {
    let id: String
    let title: String
    let minutes: Int
    let colorRaw: String

    init(id: String, title: String, minutes: Int, colorRaw: String) {
        self.id = id
        self.title = title
        self.minutes = minutes
        self.colorRaw = colorRaw
    }

    var taskColor: TaskColor? {
        TaskColor(rawValue: colorRaw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }
}
