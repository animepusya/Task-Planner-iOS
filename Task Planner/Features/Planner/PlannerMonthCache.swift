//
//  PlannerMonthCache.swift
//  Task Planner
//
//  Created by Codex on 21.03.2026.
//

import Foundation

struct PlannerMonthBuildKey: Hashable {
    let monthAnchor: Date
    let weekStartsOnMonday: Bool
}

final class PlannerMonthCache {
    private var storage: [PlannerMonthBuildKey: PlannerMonthBuildOutput] = [:]
    private var accessOrder: [PlannerMonthBuildKey] = []
    private let maxEntries = 6

    func value(for key: PlannerMonthBuildKey) -> PlannerMonthBuildOutput? {
        storage[key]
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
