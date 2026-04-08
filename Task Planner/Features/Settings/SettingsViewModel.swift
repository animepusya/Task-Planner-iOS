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
import WidgetKit

@MainActor
final class SettingsViewModel: ObservableObject {
    enum LocalizationOption: String, CaseIterable, Identifiable {
        case system
        case english
        case russian
        case hebrew

        var id: String { rawValue }

        var title: String {
            switch self {
            case .system: return String(localized: "System")
            case .english: return String(localized: "English")
            case .russian: return String(localized: "Russian")
            case .hebrew: return String(localized: "Hebrew")
            }
        }
    }

    private enum StorageKey {
        static let localization = "settings.localization"
    }

    private let preferencesRepository: PreferencesRepository
    private let taskRepository: TaskRepository
    private let categoryRepository: CategoryRepository
    private let calendarSync: CalendarSyncService
    private let defaults: UserDefaults

    @Published var weekStartsOnMonday: Bool = true
    @Published var categories: [CategoryEntity] = []
    @Published var newCategoryTitle: String = ""

    @Published var showTasksInAppleCalendar: Bool = false
    @Published var showAppleCalendarEventsInPlanner: Bool = false

    @Published var calendarStatusText: String = ""
    @Published var calendarErrorText: String?

    @Published var selectedTheme: AppTheme = .system
    @Published var selectedLocalization: LocalizationOption = .system

    init(
        preferencesRepository: PreferencesRepository,
        taskRepository: TaskRepository,
        categoryRepository: CategoryRepository,
        calendarSync: CalendarSyncService,
        defaults: UserDefaults = .standard
    ) {
        self.preferencesRepository = preferencesRepository
        self.taskRepository = taskRepository
        self.categoryRepository = categoryRepository
        self.calendarSync = calendarSync
        self.defaults = defaults
    }

    func load() {
        do {
            let prefs = try preferencesRepository.getOrCreate()
            weekStartsOnMonday = prefs.weekStartsOnMonday
            showTasksInAppleCalendar = prefs.showTasksInAppleCalendar
            showAppleCalendarEventsInPlanner = prefs.showAppleCalendarEventsInPlanner
            selectedTheme = prefs.theme
            calendarStatusText = statusText()
        } catch {
            calendarStatusText = String(localized: "Couldn't load settings.")
            selectedTheme = .system
        }

        selectedLocalization = loadLocalization()

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

    func setTheme(_ value: AppTheme) {
        let previousValue = selectedTheme
        selectedTheme = value

        do {
            try preferencesRepository.setAppTheme(value)
            WidgetStore.setAppTheme(value)
            WidgetCenter.shared.reloadTimelines(ofKind: WidgetShared.WidgetKind.plannerHome)
        } catch {
            selectedTheme = previousValue
        }
    }

    func setLocalization(_ value: LocalizationOption) {
        selectedLocalization = value
        defaults.set(value.rawValue, forKey: StorageKey.localization)
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
                    _ = try await calendarSync.ensureTaskPlannerCalendarExists()
                    let tasks = try taskRepository.fetchAll()
                    try await calendarSync.exportAllTasks(tasks)
                }

                calendarStatusText = statusText()
            } catch {
                calendarErrorText = error.localizedDescription
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
                calendarStatusText = statusText(prefix: String(localized: "Export complete"))
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
                calendarStatusText = statusText(prefix: String(localized: "Exported events removed"))
            } catch {
                calendarErrorText = error.localizedDescription
            }
        }
    }

    private func statusText(prefix: String? = nil) -> String {
        let base = switch calendarSync.authorizationStatus {
        case .authorized, .fullAccess: String(localized: "Calendar access: granted")
        case .writeOnly: String(localized: "Calendar access: write-only")
        case .notDetermined: String(localized: "Calendar access: not requested")
        case .denied: String(localized: "Calendar access: denied")
        case .restricted: String(localized: "Calendar access: restricted")
        @unknown default: String(localized: "Calendar access: unknown")
        }

        let exportState = showTasksInAppleCalendar ? String(localized: "On") : String(localized: "Off")
        let overlayState = showAppleCalendarEventsInPlanner ? String(localized: "On") : String(localized: "Off")
        let export = String(
            format: String(localized: "Export: %@"),
            locale: Locale.current,
            exportState
        )
        let importEvents = String(
            format: String(localized: "Calendar overlay: %@"),
            locale: Locale.current,
            overlayState
        )

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
                clearCategoryReferences(in: task, deletedTitle: deletedTitle)
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

    // MARK: - Helpers

    private func loadLocalization() -> LocalizationOption {
        guard
            let rawValue = defaults.string(forKey: StorageKey.localization),
            let value = LocalizationOption(rawValue: rawValue)
        else {
            return .system
        }
        return value
    }

    private func clearCategoryReferences(in task: TaskEntity, deletedTitle: String) {
        if equalsCategory(task.categoryTitle, deletedTitle) {
            task.categoryTitle = nil
        }

        if !task.seriesSegments.isEmpty {
            var segs = task.seriesSegments
            var changed = false

            for idx in segs.indices {
                if equalsCategory(segs[idx].template.categoryTitle, deletedTitle) {
                    segs[idx].template.categoryTitle = nil
                    changed = true
                }
            }

            if changed {
                task.seriesSegments = segs
            }
        }

        if !task.seriesOverrides.isEmpty {
            var ovs = task.seriesOverrides
            var changed = false

            for idx in ovs.indices {
                guard var tpl = ovs[idx].template else { continue }
                if equalsCategory(tpl.categoryTitle, deletedTitle) {
                    tpl.categoryTitle = nil
                    ovs[idx].template = tpl
                    changed = true
                }
            }

            if changed {
                task.seriesOverrides = ovs
            }
        }
    }

    private func equalsCategory(_ lhs: String?, _ rhs: String) -> Bool {
        (lhs ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        == rhs.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
