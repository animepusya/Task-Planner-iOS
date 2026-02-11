//
//  CategorySystem.swift
//  Task Planner
//
//  Created by Руслан Меланин on 11.02.2026.
//

import Foundation

enum CategorySystem {
    static let uncategorizedId = "system.uncategorized"
    static let workId = "system.work"
    static let studyId = "system.study"
    static let hobbyId = "system.hobby"

    static let uncategorizedTitle = "Без категории"
    static let workTitle = "Work"
    static let studyTitle = "Study"
    static let hobbyTitle = "Hobby"

    static let nonDeletableIds: Set<String> = [uncategorizedId, workId, studyId, hobbyId]

    static func isNonDeletable(_ category: CategoryEntity) -> Bool {
        nonDeletableIds.contains(category.id)
    }

    static func isUncategorized(_ category: CategoryEntity) -> Bool {
        category.id == uncategorizedId
    }
}
