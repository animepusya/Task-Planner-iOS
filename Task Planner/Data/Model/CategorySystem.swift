//
//  CategorySystem.swift
//  Task Planner
//
//  Created by Руслан Меланин on 11.02.2026.
//

import Foundation

enum CategorySystem {
    nonisolated static let uncategorizedId = "system.uncategorized"
    nonisolated static let workId = "system.work"
    nonisolated static let studyId = "system.study"
    nonisolated static let hobbyId = "system.hobby"

    nonisolated static let uncategorizedTitle = "Uncategorized"
    nonisolated static let workTitle = "Work"
    nonisolated static let studyTitle = "Study"
    nonisolated static let hobbyTitle = "Hobby"

    nonisolated static let nonDeletableIds: Set<String> = [uncategorizedId, workId, studyId, hobbyId]
    nonisolated static let orderedBaseCategoryIds: [String] = [workId, studyId, hobbyId]
    nonisolated static let storedFallbackTaskCategoryTitle: String? = nil

    static func isNonDeletable(_ category: CategoryEntity) -> Bool {
        nonDeletableIds.contains(category.id)
    }

    static func isUncategorized(_ category: CategoryEntity) -> Bool {
        category.id == uncategorizedId
    }

    nonisolated static var defaultSelectableTitles: [String] {
        [workTitle, studyTitle, hobbyTitle]
    }

    @MainActor
    static func isUserVisible(_ category: CategoryEntity) -> Bool {
        !isUncategorized(category)
    }

    @MainActor
    static func userVisibleCategories(from categories: [CategoryEntity]) -> [CategoryEntity] {
        let baseRanks = Dictionary(
            uniqueKeysWithValues: orderedBaseCategoryIds.enumerated().map { ($1, $0) }
        )

        return categories
            .filter(isUserVisible(_:))
            .sorted { lhs, rhs in
                switch (baseRanks[lhs.id], baseRanks[rhs.id]) {
                case let (left?, right?):
                    return left < right
                case (_?, nil):
                    return true
                case (nil, _?):
                    return false
                default:
                    return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
                }
            }
    }

    @MainActor
    static func selectableTitles(from categories: [CategoryEntity]) -> [String] {
        let visibleTitles = userVisibleCategories(from: categories).map(\.title)
        return visibleTitles.isEmpty ? defaultSelectableTitles : visibleTitles
    }

    nonisolated static func localizedDisplayTitle(for rawTitle: String?) -> String {
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

    nonisolated static func matchesWorkTitle(_ title: String) -> Bool {
        let key = normalizedKey(for: title)
        return key == normalizedKey(for: workTitle) || key == normalizedKey(for: "Работа")
    }

    nonisolated private static func normalizedKey(for title: String) -> String {
        title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}
