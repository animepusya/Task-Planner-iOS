//
//  CategoryStat.swift
//  Task Planner
//
//  Created by Руслан Меланин on 10.02.2026.
//

import Foundation

struct CategoryStat: Identifiable, Hashable {
    let id: String
    let name: String
    let minutes: Int
    let colorRaw: String

    init(name: String, minutes: Int, colorRaw: String) {
        self.id = name
        self.name = name
        self.minutes = minutes
        self.colorRaw = colorRaw
    }

    var taskColor: TaskColor? {
        TaskColor(rawValue: colorRaw)
    }
}
