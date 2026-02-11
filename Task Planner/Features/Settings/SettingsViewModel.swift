//
//  SettingsViewModel.swift
//  Task Planner
//
//  Created by Руслан Меланин on 09.02.2026.
//

import Foundation
import Combine
import SwiftData

@MainActor
final class SettingsViewModel: ObservableObject {
    private let preferencesRepository: PreferencesRepository
    private let taskRepository: TaskRepository
    private let categoryRepository: CategoryRepository

    @Published var weekStartsOnMonday: Bool = true
    @Published var categories: [CategoryEntity] = []
    @Published var newCategoryTitle: String = ""

    init(
        preferencesRepository: PreferencesRepository,
        taskRepository: TaskRepository,
        categoryRepository: CategoryRepository
    ) {
        self.preferencesRepository = preferencesRepository
        self.taskRepository = taskRepository
        self.categoryRepository = categoryRepository
    }

    func load() {
        do {
            let prefs = try preferencesRepository.getOrCreate()
            weekStartsOnMonday = prefs.weekStartsOnMonday
        } catch {}

        reloadCategories()
    }

    func reloadCategories() {
        do {
            try categoryRepository.ensureSystemCategories()
            categories = try categoryRepository.fetchAll()
        } catch {
            categories = []
        }
    }

    func setWeekStartsOnMonday(_ value: Bool) {
        weekStartsOnMonday = value
        do {
            let prefs = try preferencesRepository.getOrCreate()
            prefs.weekStartsOnMonday = value
            try preferencesRepository.save()
        } catch {}
    }

    func addCategory() {
        do {
            try categoryRepository.add(title: newCategoryTitle)
            newCategoryTitle = ""
            reloadCategories()
        } catch {}
    }

    func deleteCategory(_ category: CategoryEntity) {
        // ❌ системные не удаляем
        if CategorySystem.isNonDeletable(category) { return }

        do {
            // 1) все задачи с этой категорией → в "Без категории" (т.е. nil)
            let tasks = try taskRepository.fetchAll()
            let deletedTitle = category.title

            tasks.forEach { task in
                if (task.categoryTitle ?? "").lowercased() == deletedTitle.lowercased() {
                    task.categoryTitle = nil
                }
            }
            try taskRepository.save()

            // 2) удаляем категорию
            try categoryRepository.delete(category)
            reloadCategories()
        } catch {}
    }

    func clearAllTasks() {
        do { try taskRepository.deleteAll() } catch {}
    }

    func isDeletable(_ category: CategoryEntity) -> Bool {
        !CategorySystem.isNonDeletable(category)
    }
}
