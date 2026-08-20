//
//  TaskTitleNormalizer.swift
//  Task Planner
//
//  Created by Codex on 20.08.2026.
//

import Foundation

nonisolated enum TaskTitleNormalizer {
    static func normalize(_ value: String, locale: Locale = .current) -> String {
        value
            .precomposedStringWithCanonicalMapping
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.isEmpty == false }
            .joined(separator: " ")
            .folding(options: [.caseInsensitive], locale: locale)
    }

    static func matchRank(title: String, query: String, locale: Locale = .current) -> Int? {
        let normalizedTitle = normalize(title, locale: locale)
        let normalizedQuery = normalize(query, locale: locale)

        guard normalizedQuery.isEmpty == false else { return 0 }
        guard normalizedTitle.isEmpty == false else { return nil }

        if normalizedTitle == normalizedQuery { return 0 }
        if normalizedTitle.hasPrefix(normalizedQuery) { return 1 }

        let hasWordPrefix = normalizedTitle
            .split(separator: " ")
            .contains { $0.hasPrefix(normalizedQuery) }
        if hasWordPrefix { return 2 }

        if normalizedTitle.contains(normalizedQuery) { return 3 }
        return nil
    }
}
