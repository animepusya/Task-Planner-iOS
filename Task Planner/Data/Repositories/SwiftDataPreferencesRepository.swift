//
//  SwiftDataPreferencesRepository.swift
//  Task Planner
//
//  Created by Руслан Меланин on 09.02.2026.
//

import Foundation
import SwiftData

@MainActor
final class SwiftDataPreferencesRepository: PreferencesRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func getOrCreate() throws -> AppPreferencesEntity {
        let descriptor = FetchDescriptor<AppPreferencesEntity>()
        if let existing = try context.fetch(descriptor).first {
            return existing
        }
        let created = AppPreferencesEntity()
        context.insert(created)
        try save()
        return created
    }

    func save() throws {
        if context.hasChanges {
            try context.save()
        }
    }
}
