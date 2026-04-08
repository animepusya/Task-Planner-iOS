//
//  LocalizedDisplayText.swift
//  Task Planner
//
//  Created by Codex on 31.03.2026.
//

import Foundation

nonisolated enum LocalizedDisplayText {
    static func taskTitle(_ rawTitle: String) -> String {
        let trimmed = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return String(localized: "Untitled")
        }

        switch normalizedKey(for: trimmed) {
        case normalizedKey(for: "Untitled"), normalizedKey(for: "Без названия"):
            return String(localized: "Untitled")
        default:
            return trimmed
        }
    }

    private static func normalizedKey(for value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}
