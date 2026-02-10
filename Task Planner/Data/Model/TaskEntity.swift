//
//  TaskEntity.swift
//  Task Planner
//
//  Created by Руслан Меланин on 09.02.2026.
//

import Foundation
import SwiftData

@Model
final class TaskEntity {
    var title: String
    var notes: String?

    // Храним день отдельно (для календаря/гридов) — нормализованный startOfDay
    var dayDate: Date

    var startTime: Date
    var endTime: Date

    var repeatRuleRaw: String
    var statusRaw: String
    var colorRaw: String

    // Пока категория хранится строкой (быстрее старт). Позже можно сделать relationship на CategoryEntity.
    var categoryTitle: String?

    init(
        title: String,
        notes: String? = nil,
        dayDate: Date,
        startTime: Date,
        endTime: Date,
        repeatRule: RepeatRule = .none,
        status: TaskStatus = .todo,
        color: TaskColor = .purple,
        categoryTitle: String? = nil
    ) {
        self.title = title
        self.notes = notes
        self.dayDate = dayDate
        self.startTime = startTime
        self.endTime = endTime
        self.repeatRuleRaw = repeatRule.rawValue
        self.statusRaw = status.rawValue
        self.colorRaw = color.rawValue
        self.categoryTitle = categoryTitle
    }

    var repeatRule: RepeatRule {
        get { RepeatRule(rawValue: repeatRuleRaw) ?? .none }
        set { repeatRuleRaw = newValue.rawValue }
    }

    var status: TaskStatus {
        get { TaskStatus(rawValue: statusRaw) ?? .todo }
        set { statusRaw = newValue.rawValue }
    }

    var color: TaskColor {
        get { TaskColor(rawValue: colorRaw) ?? .purple }
        set { colorRaw = newValue.rawValue }
    }
}
