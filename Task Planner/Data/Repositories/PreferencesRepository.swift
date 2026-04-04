//
//  PreferencesRepository.swift
//  Task Planner
//
//  Created by Руслан Меланин on 09.02.2026.
//

import Foundation

@MainActor
protocol PreferencesRepository {
    func getOrCreate() throws -> AppPreferencesEntity
    func save() throws
}

extension PreferencesRepository {
    func appTheme() throws -> AppTheme {
        try getOrCreate().theme
    }

    func setAppTheme(_ theme: AppTheme) throws {
        let preferences = try getOrCreate()
        preferences.theme = theme
        try save()
    }
}
