//
//  RecurringTasksViewModel.swift
//  Task Planner
//
//  Created by Руслан Меланин on 09.03.2026.
//

import Foundation
import SwiftData
import Combine

@MainActor
final class RecurringTasksViewModel: ObservableObject {
    nonisolated private static let futureDayHorizon = 3660

    private let taskRepository: TaskRepository
    private let preferencesRepository: PreferencesRepository
    private let onOpenBaseRecurringEditor: (_ taskId: PersistentIdentifier, _ day: Date) -> Void
    private var taskSources: [RecurringTaskSource] = []
    private var refreshTask: Task<Sections, Never>?
    private var isViewActive = false
    private var didLoadInitialData = false
    private var needsReloadOnActivate = false
    private var cancellables: Set<AnyCancellable> = []

    @Published private(set) var weekStartsOnMonday: Bool = true
    @Published private(set) var sections: Sections = .empty
    @Published private(set) var isLoading = false

    init(
        taskRepository: TaskRepository,
        preferencesRepository: PreferencesRepository,
        onOpenBaseRecurringEditor: @escaping (_ taskId: PersistentIdentifier, _ day: Date) -> Void
    ) {
        self.taskRepository = taskRepository
        self.preferencesRepository = preferencesRepository
        self.onOpenBaseRecurringEditor = onOpenBaseRecurringEditor
        bindTaskRepositoryChanges()
    }

    func onViewAppear() {
        isViewActive = true
        let didChangePreferences = loadPreferences()

        if didLoadInitialData == false {
            didLoadInitialData = true
            reloadStoreInputsAndRefresh(force: true)
            return
        }

        if needsReloadOnActivate {
            needsReloadOnActivate = false
            reloadStoreInputsAndRefresh(force: false)
            return
        }

        if didChangePreferences {
            refreshSections()
        }
    }

    func onViewDisappear() {
        isViewActive = false
        refreshTask?.cancel()
        refreshTask = nil
    }

    @discardableResult
    func loadPreferences() -> Bool {
        let previous = weekStartsOnMonday

        do {
            let prefs = try preferencesRepository.getOrCreate()
            weekStartsOnMonday = prefs.weekStartsOnMonday
        } catch {
            weekStartsOnMonday = true
        }

        return previous != weekStartsOnMonday
    }

    func open(task: RecurringTaskSource) {
        onOpenBaseRecurringEditor(task.id, task.dayDate)
    }

    func deleteSeries(taskId: PersistentIdentifier) {
        do {
            guard let task = try taskRepository.fetch(by: taskId) else { return }
            try taskRepository.delete(task)
        } catch {
            assertionFailure("deleteSeries failed: \(error)")
        }
    }

    private func bindTaskRepositoryChanges() {
        taskRepository.changePublisher
            .sink { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in
                    guard self.isViewActive else {
                        self.needsReloadOnActivate = true
                        return
                    }

                    self.reloadStoreInputsAndRefresh(force: false)
                }
            }
            .store(in: &cancellables)
    }

    private func reloadStoreInputsAndRefresh(force: Bool) {
        let didChange = reloadStoreInputs()
        guard force || didChange else { return }
        refreshSections()
    }

    @discardableResult
    private func reloadStoreInputs() -> Bool {
        let newTaskSources: [RecurringTaskSource]

        do {
            newTaskSources = try taskRepository.fetchRecurring().map {
                RecurringTaskSource(task: $0, calendar: .current)
            }
        } catch {
            assertionFailure("Recurring tasks fetch failed: \(error)")
            newTaskSources = []
        }

        guard newTaskSources != taskSources else { return false }
        taskSources = newTaskSources
        return true
    }

    private func refreshSections() {
        let sources = taskSources
        let weekStartsOnMonday = weekStartsOnMonday

        if sources.isEmpty {
            refreshTask?.cancel()
            refreshTask = nil
            isLoading = false
            sections = .empty
            return
        }

        refreshTask?.cancel()
        isLoading = true

        let task = Task.detached(priority: .userInitiated) {
            Self.buildSections(from: sources, weekStartsOnMonday: weekStartsOnMonday)
        }
        refreshTask = task

        Task { [weak self] in
            let sections = await task.value
            guard let self else { return }
            guard task.isCancelled == false else { return }

            self.sections = sections
            self.isLoading = false
            self.refreshTask = nil
        }
    }

    nonisolated private static func buildSections(
        from tasks: [RecurringTaskSource],
        weekStartsOnMonday: Bool
    ) -> Sections {
        let recurring = tasks.sorted { lhs, rhs in
            if lhs.title != rhs.title {
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            return lhs.dayDate < rhs.dayDate
        }

        var active: [RecurringTaskSource] = []
        var past: [RecurringTaskSource] = []
        active.reserveCapacity(recurring.count)
        past.reserveCapacity(recurring.count)

        for task in recurring {
            if isActive(task, weekStartsOnMonday: weekStartsOnMonday) {
                active.append(task)
            } else {
                past.append(task)
            }
        }

        return Sections(active: active, past: past)
    }

    nonisolated private static func isActive(_ task: RecurringTaskSource, weekStartsOnMonday: Bool) -> Bool {
        let calendar = TaskOccurrence.calendar(weekStartsOnMonday: weekStartsOnMonday)
        let today = calendar.startOfDay(for: .now)

        let searchEnd: Date
        if let seriesEndDay = task.plannerSource.seriesEndDay {
            let normalizedEndDay = calendar.startOfDay(for: seriesEndDay)
            guard normalizedEndDay >= today else { return false }
            searchEnd = normalizedEndDay
        } else {
            searchEnd = calendar.date(
                byAdding: .day,
                value: Self.futureDayHorizon,
                to: today
            ) ?? today.addingTimeInterval(TimeInterval(Self.futureDayHorizon * 86_400))
        }

        return task.plannerSource.hasRelevantStarts(
            between: today,
            and: searchEnd,
            calendar: calendar
        )
    }

    struct Sections: Equatable {
        let active: [RecurringTaskSource]
        let past: [RecurringTaskSource]

        static let empty = Sections(active: [], past: [])
    }
}
