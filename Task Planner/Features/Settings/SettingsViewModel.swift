//
//  SettingsViewModel.swift
//  Task Planner
//
//  Created by Руслан Меланин on 09.02.2026.
//

import Foundation
import Combine
import SwiftData
import EventKit

@MainActor
final class SettingsViewModel: ObservableObject {
    private let preferencesRepository: PreferencesRepository
    private let taskRepository: TaskRepository
    private let categoryRepository: CategoryRepository
    private let calendarSync: CalendarSyncService

    @Published var weekStartsOnMonday: Bool = true
    @Published var categories: [CategoryEntity] = []
    @Published var newCategoryTitle: String = ""

    // ✅ Calendar toggles
    @Published var showTasksInAppleCalendar: Bool = false
    @Published var showAppleCalendarEventsInPlanner: Bool = false

    // UI feedback
    @Published var calendarStatusText: String = ""
    @Published var calendarErrorText: String?

    init(
        preferencesRepository: PreferencesRepository,
        taskRepository: TaskRepository,
        categoryRepository: CategoryRepository,
        calendarSync: CalendarSyncService
    ) {
        self.preferencesRepository = preferencesRepository
        self.taskRepository = taskRepository
        self.categoryRepository = categoryRepository
        self.calendarSync = calendarSync
    }

    func load() {
        do {
            let prefs = try preferencesRepository.getOrCreate()
            weekStartsOnMonday = prefs.weekStartsOnMonday
            showTasksInAppleCalendar = prefs.showTasksInAppleCalendar
            showAppleCalendarEventsInPlanner = prefs.showAppleCalendarEventsInPlanner
            calendarStatusText = statusText()
        } catch {
            calendarStatusText = "Preferences load failed"
        }

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

            if prefs.showTasksInAppleCalendar {
                Task { [weak self] in
                    guard let self else { return }
                    do {
                        let tasks = try self.taskRepository.fetchAll()
                        try await self.calendarSync.exportAllTasks(tasks)
                    } catch {
                        self.calendarErrorText = error.localizedDescription
                    }
                }
            }
        } catch {}
    }

    // MARK: - Calendar actions

    func setShowTasksInAppleCalendar(_ value: Bool) {
        showTasksInAppleCalendar = value
        calendarErrorText = nil

        Task {
            do {
                let prefs = try preferencesRepository.getOrCreate()
                prefs.showTasksInAppleCalendar = value
                try preferencesRepository.save()

                if value {
                    // request permission + ensure calendar exists + export all
                    _ = try await calendarSync.ensureTaskPlannerCalendarExists()
                    let tasks = try taskRepository.fetchAll()
                    try await calendarSync.exportAllTasks(tasks)
                }

                calendarStatusText = statusText()
            } catch {
                calendarErrorText = error.localizedDescription
                // rollback UI if needed
                showTasksInAppleCalendar = false
                do {
                    let prefs = try preferencesRepository.getOrCreate()
                    prefs.showTasksInAppleCalendar = false
                    try preferencesRepository.save()
                } catch {}
                calendarStatusText = statusText()
            }
        }
    }

    func setShowAppleCalendarEventsInPlanner(_ value: Bool) {
        showAppleCalendarEventsInPlanner = value
        calendarErrorText = nil

        Task {
            do {
                let prefs = try preferencesRepository.getOrCreate()
                prefs.showAppleCalendarEventsInPlanner = value
                try preferencesRepository.save()

                if value {
                    try await calendarSync.requestAccessIfNeeded()
                }

                calendarStatusText = statusText()
            } catch {
                calendarErrorText = error.localizedDescription
                showAppleCalendarEventsInPlanner = false
                do {
                    let prefs = try preferencesRepository.getOrCreate()
                    prefs.showAppleCalendarEventsInPlanner = false
                    try preferencesRepository.save()
                } catch {}
                calendarStatusText = statusText()
            }
        }
    }

    func exportNow() {
        calendarErrorText = nil
        Task {
            do {
                let tasks = try taskRepository.fetchAll()
                try await calendarSync.exportAllTasks(tasks)
                calendarStatusText = statusText(prefix: "Export done")
            } catch {
                calendarErrorText = error.localizedDescription
            }
        }
    }

    func removeExportedEvents() {
        calendarErrorText = nil
        Task {
            do {
                try await calendarSync.removeAllExportedEvents()
                calendarStatusText = statusText(prefix: "Removed exported events")
            } catch {
                calendarErrorText = error.localizedDescription
            }
        }
    }

    private func statusText(prefix: String? = nil) -> String {
        let base = switch calendarSync.authorizationStatus {
        case .authorized, .fullAccess: "Calendar access: granted"
        case .notDetermined: "Calendar access: not determined"
        case .denied: "Calendar access: denied"
        case .restricted: "Calendar access: restricted"
        @unknown default: "Calendar access: unknown"
        }

        let export = "Export: \(showTasksInAppleCalendar ? "ON" : "OFF")"
        let importEvents = "Overlay events: \(showAppleCalendarEventsInPlanner ? "ON" : "OFF")"

        if let prefix {
            return "\(prefix) • \(base) • \(export) • \(importEvents)"
        }
        return "\(base) • \(export) • \(importEvents)"
    }

    // MARK: - Categories

    func addCategory() {
        do {
            try categoryRepository.add(title: newCategoryTitle)
            newCategoryTitle = ""
            reloadCategories()
        } catch {}
    }

    func deleteCategory(_ category: CategoryEntity) {
        if CategorySystem.isNonDeletable(category) { return }

        do {
            let tasks = try taskRepository.fetchAll()
            let deletedTitle = category.title

            tasks.forEach { task in
                if (task.categoryTitle ?? "").lowercased() == deletedTitle.lowercased() {
                    task.categoryTitle = nil
                }
            }
            try taskRepository.save()

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
