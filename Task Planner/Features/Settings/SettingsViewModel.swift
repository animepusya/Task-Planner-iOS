//
//  SettingsViewModel.swift
//  Task Planner
//
//  Created by Руслан Меланин on 09.02.2026.
//

import Foundation
import Combine

@MainActor
final class SettingsViewModel: ObservableObject {
    private let preferencesRepository: PreferencesRepository
    private let taskRepository: TaskRepository

    @Published var weekStartsOnMonday: Bool = true

    init(preferencesRepository: PreferencesRepository, taskRepository: TaskRepository) {
        self.preferencesRepository = preferencesRepository
        self.taskRepository = taskRepository
    }

    func load() {
        do {
            let prefs = try preferencesRepository.getOrCreate()
            weekStartsOnMonday = prefs.weekStartsOnMonday
        } catch {}
    }

    func setWeekStartsOnMonday(_ value: Bool) {
        weekStartsOnMonday = value
        do {
            let prefs = try preferencesRepository.getOrCreate()
            prefs.weekStartsOnMonday = value
            try preferencesRepository.save()
        } catch {}
    }

    func clearAllTasks() {
        do { try taskRepository.deleteAll() } catch {}
    }
}
