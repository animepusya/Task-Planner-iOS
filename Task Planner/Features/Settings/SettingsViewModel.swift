//
//  SettingsViewModel.swift
//  Task Planner
//
//  Created by Руслан Меланин on 09.02.2026.
//

import EventKit
import Combine
import Foundation
import WidgetKit

@MainActor
final class SettingsViewModel: ObservableObject {
    private let preferencesRepository: PreferencesRepository
    private let taskRepository: TaskRepository
    private let categoryRepository: CategoryRepository
    private let calendarSync: CalendarSyncService

    @Published var weekStartsOnMonday: Bool = true
    @Published var categories: [CategoryEntity] = []
    @Published var newCategoryTitle: String = ""
    @Published private(set) var appLanguageDisplayName: String = ""

    @Published var showTasksInAppleCalendar: Bool = false
    @Published var showAppleCalendarEventsInPlanner: Bool = false

    @Published var calendarStatusText: String = ""
    @Published var calendarErrorText: String?

    @Published var selectedTheme: AppTheme = .system

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
            selectedTheme = prefs.theme
            calendarStatusText = statusText()
        } catch {
            calendarStatusText = String(localized: "Couldn't load settings.")
            selectedTheme = .system
        }

        refreshAppLanguageDisplayName()
        reloadCategories()
    }

    func reloadCategories() {
        do {
            try categoryRepository.ensureSystemCategories()
            let allCategories = try categoryRepository.fetchAll()
            categories = CategorySystem.userVisibleCategories(from: allCategories)
        } catch {
            categories = []
        }
    }

    func refreshAppLanguageDisplayName() {
        appLanguageDisplayName = Self.resolveAppLanguageDisplayName()
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

    // MARK: - Calendar actions

    func setShowTasksInAppleCalendar(_ value: Bool) {
        showTasksInAppleCalendar = value
        calendarErrorText = nil

        Task {
            if value {
                await enableTaskExport()
            } else {
                await disableTaskExportAndRemoveEvents()
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
                    try await calendarSync.requestAccessIfNeeded(canPrompt: true)
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
                guard showTasksInAppleCalendar else {
                    calendarErrorText = String(localized: "Turn on Show tasks in Apple Calendar first.")
                    calendarStatusText = statusText()
                    return
                }

                let tasks = try taskRepository.fetchAll()
                _ = try await calendarSync.removeAllExportedEvents(tasks: tasks, canPrompt: true)
                try await calendarSync.exportAllTasks(tasks, canPrompt: true)
                calendarStatusText = statusText(prefix: String(localized: "Export complete"))
            } catch {
                calendarErrorText = error.localizedDescription
            }
        }
    }

    func removeExportedEvents() {
        calendarErrorText = nil
        Task {
            await disableTaskExportAndRemoveEvents(showRemovalStatus: true, canPromptForRemoval: true)
        }
    }

    private func enableTaskExport() async {
        do {
            try setTaskExportEnabled(true)
            _ = try await calendarSync.ensureTaskPlannerCalendarExists(canPrompt: true)
            let tasks = try taskRepository.fetchAll()
            try await calendarSync.exportAllTasks(tasks)
            calendarStatusText = statusText()
        } catch {
            calendarErrorText = error.localizedDescription
            showTasksInAppleCalendar = false
            try? setTaskExportEnabled(false)
            calendarStatusText = statusText()
        }
    }

    private func disableTaskExportAndRemoveEvents(
        showRemovalStatus: Bool = false,
        canPromptForRemoval: Bool = false
    ) async {
        do {
            try setTaskExportEnabled(false)
        } catch {
            calendarErrorText = error.localizedDescription
            showTasksInAppleCalendar = true
            calendarStatusText = statusText()
            return
        }

        do {
            let tasks = try taskRepository.fetchAll()
            _ = try await calendarSync.removeAllExportedEvents(
                tasks: tasks,
                canPrompt: canPromptForRemoval
            )
            clearAppleEventIdentifiers(in: tasks)
            try taskRepository.save(tasks)
            calendarStatusText = statusText(
                prefix: showRemovalStatus ? String(localized: "Exported events removed") : nil
            )
        } catch {
            calendarErrorText = error.localizedDescription
            calendarStatusText = statusText()
        }
    }

    private func setTaskExportEnabled(_ enabled: Bool) throws {
        let prefs = try preferencesRepository.getOrCreate()
        prefs.showTasksInAppleCalendar = enabled
        try preferencesRepository.save()
        showTasksInAppleCalendar = enabled
    }

    private func clearAppleEventIdentifiers(in tasks: [TaskEntity]) {
        for task in tasks where task.appleEventIdentifier != nil {
            task.appleEventIdentifier = nil
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

    func prepareForNewCategory() {
        newCategoryTitle = ""
    }

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
            let fallbackTitle = CategorySystem.storedFallbackTaskCategoryTitle

            tasks.forEach { task in
                clearCategoryReferences(
                    in: task,
                    deletedTitle: deletedTitle,
                    fallbackTitle: fallbackTitle
                )
            }

            try taskRepository.save(tasks)
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

    private func clearCategoryReferences(
        in task: TaskEntity,
        deletedTitle: String,
        fallbackTitle: String?
    ) {
        if equalsCategory(task.categoryTitle, deletedTitle) {
            task.categoryTitle = fallbackTitle
        }

        if !task.seriesSegments.isEmpty {
            var segs = task.seriesSegments
            var changed = false

            for idx in segs.indices {
                if equalsCategory(segs[idx].template.categoryTitle, deletedTitle) {
                    segs[idx].template.categoryTitle = fallbackTitle
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
                    tpl.categoryTitle = fallbackTitle
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

    private static func resolveAppLanguageDisplayName() -> String {
        let preferredIdentifier = resolvedAppLanguageIdentifier()
        let locale = Locale.autoupdatingCurrent

        if let localizedName = locale.localizedString(forIdentifier: preferredIdentifier) {
            return localizedName.capitalized(with: locale)
        }

        if
            let languageCode = Locale.Language(identifier: preferredIdentifier).languageCode?.identifier,
            let localizedName = locale.localizedString(forLanguageCode: languageCode)
        {
            return localizedName.capitalized(with: locale)
        }

        return preferredIdentifier
    }

    private static func resolvedAppLanguageIdentifier() -> String {
        let preferredLocalization = Bundle.main.preferredLocalizations.first
        let normalizedPreferredLocalization: String?

        if preferredLocalization == "Base" {
            normalizedPreferredLocalization = nil
        } else {
            normalizedPreferredLocalization = preferredLocalization
        }

        return normalizedPreferredLocalization
        ?? Bundle.main.developmentLocalization
        ?? Locale.autoupdatingCurrent.identifier
    }
}
