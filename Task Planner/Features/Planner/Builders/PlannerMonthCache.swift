//
//  PlannerMonthCache.swift
//  Task Planner
//
//  Created by Codex on 21.03.2026.
//

import Foundation

nonisolated struct PlannerMonthBuildKey: Hashable, Sendable {
    let monthAnchor: Date
    let weekStartsOnMonday: Bool
    let taskRevision: Int
    let externalEventsRevision: Int
}

final class PlannerMonthCache {
    private var storage: [PlannerMonthBuildKey: PlannerMonthBuildOutput] = [:]
    private var accessOrder: [PlannerMonthBuildKey] = []
    private let maxEntries = 9

    func value(for key: PlannerMonthBuildKey) -> PlannerMonthBuildOutput? {
        guard let value = storage[key] else { return nil }
        accessOrder.removeAll { $0 == key }
        accessOrder.append(key)
        return value
    }

    func insert(_ value: PlannerMonthBuildOutput, for key: PlannerMonthBuildKey) {
        storage[key] = value
        accessOrder.removeAll { $0 == key }
        accessOrder.append(key)

        while accessOrder.count > maxEntries {
            let oldest = accessOrder.removeFirst()
            storage.removeValue(forKey: oldest)
        }
    }

    func invalidateAll() {
        storage.removeAll(keepingCapacity: true)
        accessOrder.removeAll(keepingCapacity: true)
    }
}
