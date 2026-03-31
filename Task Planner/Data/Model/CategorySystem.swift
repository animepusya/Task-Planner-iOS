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

    static let uncategorizedTitle = "Uncategorized"
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

    static var defaultSelectableTitles: [String] {
        [workTitle, studyTitle, hobbyTitle]
    }

    static func localizedDisplayTitle(for rawTitle: String?) -> String {
        let trimmed = (rawTitle ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return String(localized: "Uncategorized")
        }

        switch normalizedKey(for: trimmed) {
        case normalizedKey(for: uncategorizedTitle), normalizedKey(for: "Без категории"):
            return String(localized: "Uncategorized")
        case normalizedKey(for: workTitle), normalizedKey(for: "Работа"):
            return String(localized: "Work")
        case normalizedKey(for: studyTitle), normalizedKey(for: "Учеба"), normalizedKey(for: "Учёба"):
            return String(localized: "Study")
        case normalizedKey(for: hobbyTitle), normalizedKey(for: "Хобби"):
            return String(localized: "Hobby")
        default:
            return trimmed
        }
    }

    static func matchesWorkTitle(_ title: String) -> Bool {
        let key = normalizedKey(for: title)
        return key == normalizedKey(for: workTitle) || key == normalizedKey(for: "Работа")
    }

    private static func normalizedKey(for title: String) -> String {
        title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}
