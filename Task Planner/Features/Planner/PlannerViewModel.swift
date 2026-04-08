//
//  PlannerViewModel.swift
//  Task Planner
//
//  Created by Руслан Меланин on 09.02.2026.
//

import Foundation
import SwiftData
import SwiftUI
import Combine

@MainActor
final class PlannerViewModel: ObservableObject {
    static let monthTransitionDuration: TimeInterval = 0.2
    static let monthTransitionAnimation = Animation.easeInOut(duration: monthTransitionDuration)

    private let taskRepository: TaskRepository
    private let preferencesRepository: PreferencesRepository
    private let calendarSync: CalendarSyncService
    private let onOpenTaskEditor: (_ taskId: PersistentIdentifier?, _ day: Date) -> Void
    private let onOpenNotifications: () -> Void
    private let onOpenRecurringBaseTasks: () -> Void
    private let seriesService: TaskSeriesService

    private let snapshotBuilder = PlannerScreenSnapshotBuilder()
    private let monthCache = PlannerMonthCache()

    private var plannerTasks: [PlannerTaskSource] = []
    private var taskIDsByKey: [String: PersistentIdentifier] = [:]
    private var weekStartsOnMonday = true
    private var isOverlayEnabled = false
    private var externalEventsByDay: [Date: [PlannerExternalEventSource]] = [:]
    private var sortDoneOverride: [String: Bool] = [:]
    private var selectedDayStorage: Date
    private var monthAnchorStorage: Date
    private var didAttachView = false
    private var taskRevision = 0
    private var externalEventsRevision = 0
    private var activeMonthBuildKey: PlannerMonthBuildKey?
    private var activeMonthBuild: PlannerMonthBuildOutput?

    @Published private(set) var visualDoneOverride: [String: Bool] = [:]
    @Published private(set) var snapshot: PlannerScreenSnapshot = .empty
    @Published private(set) var isMonthTransitionLocked = false

    private var pendingToggleTasks: [String: Task<Void, Never>] = [:]
    private var monthBuildTasks: [PlannerMonthBuildKey: Task<PlannerMonthBuildOutput, Never>] = [:]
    private var externalMonthTask: Task<Void, Never>?
    private var monthTransitionUnlockTask: Task<Void, Never>?

    private let donePhaseDelay: UInt64 = 800_000_000
    private let moveAnim: Animation = .easeInOut(duration: 0.8)

    init(
        taskRepository: TaskRepository,
        preferencesRepository: PreferencesRepository,
        calendarSync: CalendarSyncService,
        seriesService: TaskSeriesService,
        onOpenTaskEditor: @escaping (_ taskId: PersistentIdentifier?, _ day: Date) -> Void,
        onOpenNotifications: @escaping () -> Void,
        onOpenRecurringBaseTasks: @escaping () -> Void
    ) {
        self.taskRepository = taskRepository
        self.preferencesRepository = preferencesRepository
        self.calendarSync = calendarSync
        self.seriesService = seriesService
        self.onOpenTaskEditor = onOpenTaskEditor
        self.onOpenNotifications = onOpenNotifications
        self.onOpenRecurringBaseTasks = onOpenRecurringBaseTasks

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        self.selectedDayStorage = today
        self.monthAnchorStorage = calendar.startOfMonth(for: today)

        _ = loadPreferences()
        refreshPlannerSnapshot(prefetchAdjacent: true)

        if isOverlayEnabled {
            refreshExternalEvents()
        }
    }

    var selectedDay: Date { selectedDayStorage }
    var monthAnchor: Date { monthAnchorStorage }

    func onViewAppear(tasks: [TaskEntity]) {
        guard !didAttachView else { return }
        didAttachView = true
        updateSourceTasks(tasks)
    }

    func handleModelContextDidSave(tasks: [TaskEntity]) {
        updateSourceTasks(tasks)

        if loadPreferences() {
            refreshPlannerSnapshot(prefetchAdjacent: true)

            if isOverlayEnabled {
                refreshExternalEvents()
            }
        }
    }

    func applyExternalSelectedDay(_ day: Date) {
        let calendar = Calendar.current
        let normalizedDay = calendar.startOfDay(for: day)
        let normalizedMonth = calendar.startOfMonth(for: normalizedDay)

        selectedDayStorage = normalizedDay
        monthAnchorStorage = normalizedMonth

        refreshPlannerSnapshot(prefetchAdjacent: true)
        refreshExternalEvents()
    }

    func selectDay(_ day: Date) {
        let normalizedDay = Calendar.current.startOfDay(for: day)
        guard normalizedDay != selectedDayStorage else { return }

        selectedDayStorage = normalizedDay
        refreshSelectedDaySnapshot()
    }

    func openCreateTask() { onOpenTaskEditor(nil, selectedDayStorage) }

    func openEditTask(taskKey: String) {
        guard let taskId = taskIDsByKey[taskKey] else {
            assertionFailure("openEditTask: task not found for key \(taskKey)")
            return
        }

        onOpenTaskEditor(taskId, selectedDayStorage)
    }

    func openNotifications() { onOpenNotifications() }
    func openRecurringBaseTasks() { onOpenRecurringBaseTasks() }

    @discardableResult
    func goToPreviousMonth() -> Bool {
        setMonthAnchor(monthAnchorStorage.addingMonths(-1))
    }

    @discardableResult
    func goToNextMonth() -> Bool {
        setMonthAnchor(monthAnchorStorage.addingMonths(1))
    }

    @discardableResult
    func setMonthAnchor(_ date: Date) -> Bool {
        let normalized = Calendar.current.startOfMonth(for: date)
        guard normalized != monthAnchorStorage else { return false }
        guard beginMonthTransitionLock() else { return false }

        monthAnchorStorage = normalized
        refreshPlannerSnapshot(prefetchAdjacent: true)
        refreshExternalEvents()
        return true
    }

    @discardableResult
    func goToToday() -> Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let todayMonth = calendar.startOfMonth(for: today)
        let needsMonthChange = todayMonth != monthAnchorStorage
        let needsDayChange = today != selectedDayStorage

        guard needsMonthChange || needsDayChange else { return false }

        if needsMonthChange {
            guard beginMonthTransitionLock() else { return false }
        }

        selectedDayStorage = today
        monthAnchorStorage = todayMonth
        refreshPlannerSnapshot(prefetchAdjacent: true)

        if needsMonthChange {
            refreshExternalEvents()
        }

        return true
    }

    func isVisuallyDone(taskKey: String, modelCompleted: Bool) -> Bool {
        visualDoneOverride[taskKey] ?? modelCompleted
    }

    func toggleDoneTwoPhase(taskKey: String, on day: Date) {
        pendingToggleTasks[taskKey]?.cancel()

        let dayKey = Calendar.current.startOfDay(for: day)

        let task = Task { [weak self] in
            guard let self else { return }

            do {
                guard let taskId = self.taskIDsByKey[taskKey] else {
                    assertionFailure("toggleDoneTwoPhase: task id missing for key \(taskKey)")
                    return
                }

                guard let taskEntity = try self.taskRepository.fetch(by: taskId) else {
                    assertionFailure("toggleDoneTwoPhase: task not found")
                    return
                }

                let currentlyCompleted = taskEntity.isCompleted(on: dayKey)
                let targetCompleted = !currentlyCompleted

                self.visualDoneOverride[taskKey] = targetCompleted

                try await Task.sleep(nanoseconds: self.donePhaseDelay)
                guard !Task.isCancelled else { return }

                withAnimation(self.moveAnim) {
                    self.sortDoneOverride[taskKey] = targetCompleted
                    self.bumpTaskRevision()
                    self.refreshPlannerSnapshot(prefetchAdjacent: true)
                }

                taskEntity.toggleCompleted(on: dayKey)
                try self.taskRepository.save()

                self.applyLocalCompletion(taskKey: taskKey, on: dayKey, completed: targetCompleted)
                self.visualDoneOverride[taskKey] = nil
                self.sortDoneOverride[taskKey] = nil
                self.bumpTaskRevision()
                self.refreshPlannerSnapshot(prefetchAdjacent: true)
            } catch {
                assertionFailure("toggleDoneTwoPhase failed: \(error)")
                self.visualDoneOverride[taskKey] = nil
                self.sortDoneOverride[taskKey] = nil
                self.bumpTaskRevision()
                self.refreshPlannerSnapshot(prefetchAdjacent: true)
            }
        }

        pendingToggleTasks[taskKey] = task
    }

    func delete(taskKey: String) {
        pendingToggleTasks[taskKey]?.cancel()
        visualDoneOverride[taskKey] = nil
        sortDoneOverride[taskKey] = nil

        do {
            guard let taskId = taskIDsByKey[taskKey] else {
                assertionFailure("delete: task id missing for key \(taskKey)")
                return
            }

            guard let task = try taskRepository.fetch(by: taskId) else {
                assertionFailure("delete: task not found")
                return
            }

            try taskRepository.delete(task)
        } catch {
            assertionFailure("delete failed: \(error)")
        }
    }

    func deleteOccurrence(
        taskKey: String,
        occurrenceStartDay: Date,
        scope: TaskSeriesService.Scope
    ) {
        pendingToggleTasks[taskKey]?.cancel()
        visualDoneOverride[taskKey] = nil
        sortDoneOverride[taskKey] = nil

        do {
            guard let taskId = taskIDsByKey[taskKey] else {
                assertionFailure("deleteOccurrence: task id missing for key \(taskKey)")
                return
            }

            try seriesService.applyDelete(
                taskId: taskId,
                occurrenceStartDay: occurrenceStartDay,
                scope: scope
            )
        } catch {
            assertionFailure("deleteOccurrence failed: \(error)")
        }
    }

    private func updateSourceTasks(_ tasks: [TaskEntity]) {
        let calendar = Calendar.current

        plannerTasks = tasks.map { $0.plannerSource(calendar: calendar) }
        taskIDsByKey = Dictionary(
            uniqueKeysWithValues: tasks.map { ($0.plannerTaskKey, $0.persistentModelID) }
        )

        bumpTaskRevision()
        refreshPlannerSnapshot(prefetchAdjacent: true)
    }

    @discardableResult
    private func loadPreferences() -> Bool {
        let previousWeekStartsOnMonday = weekStartsOnMonday
        let previousOverlayEnabled = isOverlayEnabled

        do {
            let prefs = try preferencesRepository.getOrCreate()
            weekStartsOnMonday = prefs.weekStartsOnMonday
            isOverlayEnabled = prefs.showAppleCalendarEventsInPlanner
        } catch {
            weekStartsOnMonday = true
            isOverlayEnabled = false
        }

        let didChangeWeekStart = previousWeekStartsOnMonday != weekStartsOnMonday
        let didChangeOverlay = previousOverlayEnabled != isOverlayEnabled
        let didChangeMonthInputs = didChangeWeekStart || didChangeOverlay

        if didChangeMonthInputs {
            cancelMonthBuilds()
        }

        if didChangeOverlay {
            externalEventsRevision &+= 1

            if !isOverlayEnabled {
                externalMonthTask?.cancel()
                externalEventsByDay = [:]
            }
        }

        return didChangeMonthInputs
    }

    private func refreshExternalEvents() {
        guard isOverlayEnabled else { return }

        externalMonthTask?.cancel()
        let anchor = monthAnchorStorage

        externalMonthTask = Task { [weak self] in
            guard let self else { return }
            await self.loadExternalEventsWindow(centeredOn: anchor)
        }
    }

    private func loadExternalEventsWindow(centeredOn monthAnchor: Date) async {
        guard isOverlayEnabled else { return }

        let calendar = Calendar.current
        let normalizedMonth = calendar.startOfMonth(for: monthAnchor)
        let start = calendar.startOfMonth(for: normalizedMonth.addingMonths(-1, using: calendar))
        let end = calendar.startOfMonth(for: normalizedMonth.addingMonths(2, using: calendar))

        do {
            let events = try await calendarSync.fetchReadOnlyEvents(
                start: start,
                end: end,
                excludeTaskPlannerCalendar: true
            )
            guard !Task.isCancelled, isOverlayEnabled else { return }

            var grouped: [Date: [PlannerExternalEventSource]] = [:]
            grouped.reserveCapacity(120)

            for event in events {
                let source = event.plannerSource()
                let dayKey = calendar.startOfDay(for: source.startDate)
                grouped[dayKey, default: []].append(source)
            }

            for key in grouped.keys {
                grouped[key]?.sort { $0.startDate < $1.startDate }
            }

            externalEventsByDay = grouped
        } catch {
            externalEventsByDay = [:]
        }

        externalEventsRevision &+= 1
        cancelMonthBuilds()
        refreshPlannerSnapshot(prefetchAdjacent: true)
    }

    private func refreshPlannerSnapshot(prefetchAdjacent: Bool) {
        let cachedMonthBuild = applyCachedCurrentMonthBuildIfAvailable()
        refreshSelectedDaySnapshot(monthBuild: cachedMonthBuild)
        scheduleCurrentMonthBuildIfNeeded()

        if prefetchAdjacent {
            prefetchAdjacentMonths()
        }
    }

    private func refreshSelectedDaySnapshot(monthBuild: PlannerMonthBuildOutput? = nil) {
        let selectedDaySnapshot = snapshotBuilder.buildSelectedDaySnapshot(
            selectedDay: selectedDayStorage,
            monthBuild: monthBuild ?? currentMonthBuildIfAvailable(),
            tasks: plannerTasks,
            weekStartsOnMonday: weekStartsOnMonday,
            externalEventsByDay: externalEventsByDay,
            isOverlayEnabled: isOverlayEnabled,
            sortDoneOverride: sortDoneOverride
        )

        snapshot = PlannerScreenSnapshot(
            month: snapshot.month,
            selectedDay: selectedDaySnapshot
        )
    }

    private func scheduleCurrentMonthBuildIfNeeded() {
        let key = currentMonthBuildKey()
        scheduleMonthBuild(
            for: key,
            priority: .userInitiated,
            applyIfCurrent: true
        )
    }

    private func prefetchAdjacentMonths() {
        let calendar = Calendar.current
        let adjacentAnchors = [
            calendar.startOfMonth(for: monthAnchorStorage.addingMonths(-1, using: calendar)),
            calendar.startOfMonth(for: monthAnchorStorage.addingMonths(1, using: calendar))
        ]

        for anchor in adjacentAnchors {
            let key = monthBuildKey(for: anchor)
            scheduleMonthBuild(
                for: key,
                priority: .utility,
                applyIfCurrent: false
            )
        }
    }

    private func scheduleMonthBuild(
        for key: PlannerMonthBuildKey,
        priority: TaskPriority,
        applyIfCurrent: Bool
    ) {
        if let cached = monthCache.value(for: key) {
            if applyIfCurrent {
                applyMonthBuild(cached, for: key)
            }
            return
        }

        let buildTask: Task<PlannerMonthBuildOutput, Never>

        if let existingTask = monthBuildTasks[key] {
            buildTask = existingTask
        } else {
            let tasks = plannerTasks
            let externalEvents = externalEventsByDay
            let weekStartsOnMonday = weekStartsOnMonday
            let isOverlayEnabled = isOverlayEnabled
            let sortDoneOverride = sortDoneOverride

            buildTask = Task.detached(priority: priority) {
                PlannerScreenSnapshotBuilder().buildMonth(
                    tasks: tasks,
                    monthAnchor: key.monthAnchor,
                    weekStartsOnMonday: weekStartsOnMonday,
                    externalEventsByDay: externalEvents,
                    isOverlayEnabled: isOverlayEnabled,
                    sortDoneOverride: sortDoneOverride
                )
            }

            monthBuildTasks[key] = buildTask
        }

        Task { [weak self] in
            let output = await buildTask.value
            guard !buildTask.isCancelled else { return }
            self?.finishMonthBuild(output, for: key, applyIfCurrent: applyIfCurrent)
        }
    }

    private func finishMonthBuild(
        _ output: PlannerMonthBuildOutput,
        for key: PlannerMonthBuildKey,
        applyIfCurrent: Bool
    ) {
        monthBuildTasks.removeValue(forKey: key)
        monthCache.insert(output, for: key)

        guard applyIfCurrent, key == currentMonthBuildKey() else { return }
        applyMonthBuild(output, for: key)
    }

    private func applyMonthBuild(_ output: PlannerMonthBuildOutput, for key: PlannerMonthBuildKey) {
        activeMonthBuildKey = key
        activeMonthBuild = output

        snapshot = PlannerScreenSnapshot(
            month: output.monthSnapshot,
            selectedDay: snapshot.selectedDay
        )

        refreshSelectedDaySnapshot(monthBuild: output)
    }

    private func applyCachedCurrentMonthBuildIfAvailable() -> PlannerMonthBuildOutput? {
        let key = currentMonthBuildKey()

        guard let cached = monthCache.value(for: key) else {
            if activeMonthBuildKey != key {
                activeMonthBuildKey = nil
                activeMonthBuild = nil
            }
            return nil
        }

        applyMonthBuild(cached, for: key)
        return cached
    }

    private func currentMonthBuildIfAvailable() -> PlannerMonthBuildOutput? {
        let key = currentMonthBuildKey()

        if activeMonthBuildKey == key {
            return activeMonthBuild
        }

        return monthCache.value(for: key)
    }

    private func currentMonthBuildKey() -> PlannerMonthBuildKey {
        monthBuildKey(for: monthAnchorStorage)
    }

    private func monthBuildKey(for monthAnchor: Date) -> PlannerMonthBuildKey {
        let calendar = Calendar.current
        return PlannerMonthBuildKey(
            monthAnchor: calendar.startOfMonth(for: monthAnchor),
            weekStartsOnMonday: weekStartsOnMonday,
            taskRevision: taskRevision,
            externalEventsRevision: externalEventsRevision
        )
    }

    private func bumpTaskRevision() {
        taskRevision &+= 1
        cancelMonthBuilds()
    }

    private func cancelMonthBuilds() {
        for task in monthBuildTasks.values {
            task.cancel()
        }

        monthBuildTasks.removeAll(keepingCapacity: true)
    }

    private func applyLocalCompletion(taskKey: String, on day: Date, completed: Bool) {
        guard let index = plannerTasks.firstIndex(where: { $0.taskKey == taskKey }) else { return }

        var completedDayKeys = plannerTasks[index].completedDayKeys
        let dayKey = TaskEntity.dayKey(for: day)

        if completed {
            completedDayKeys.insert(dayKey)
        } else {
            completedDayKeys.remove(dayKey)
        }

        plannerTasks[index] = plannerTasks[index].withCompletedDayKeys(completedDayKeys)
    }

    private func beginMonthTransitionLock() -> Bool {
        guard !isMonthTransitionLocked else { return false }

        isMonthTransitionLocked = true
        monthTransitionUnlockTask?.cancel()

        monthTransitionUnlockTask = Task { [weak self] in
            guard let self else { return }

            do {
                try await Task.sleep(
                    nanoseconds: UInt64(Self.monthTransitionDuration * 1_000_000_000)
                )
            } catch {
                return
            }

            guard !Task.isCancelled else { return }
            self.isMonthTransitionLocked = false
            self.monthTransitionUnlockTask = nil
        }

        return true
    }
}
