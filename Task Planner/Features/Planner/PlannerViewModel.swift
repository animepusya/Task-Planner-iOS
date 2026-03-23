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

    private var sourceTasks: [TaskEntity] = []
    private var weekStartsOnMonday = true
    private var isOverlayEnabled = false
    private var externalEventsByDay: [Date: [ExternalCalendarEvent]] = [:]
    private var sortDoneOverride: [PersistentIdentifier: Bool] = [:]
    private var selectedDayStorage: Date
    private var monthAnchorStorage: Date
    private var didAttachView = false

    @Published private(set) var visualDoneOverride: [PersistentIdentifier: Bool] = [:]
    @Published private(set) var snapshot: PlannerScreenSnapshot = .empty
    @Published private(set) var isMonthTransitionLocked = false

    private var pendingToggleTasks: [PersistentIdentifier: Task<Void, Never>] = [:]
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

        if !loadPreferences() {
            refreshSnapshot()
        }
    }

    var selectedDay: Date { selectedDayStorage }
    var monthAnchor: Date { snapshot.month.monthAnchor }

    func onViewAppear(tasks: [TaskEntity]) {
        guard !didAttachView else { return }
        didAttachView = true
        updateSourceTasks(tasks)
    }

    func handleModelContextDidSave(tasks: [TaskEntity]) {
        updateSourceTasks(tasks)
        _ = loadPreferences()
    }

    func applyExternalSelectedDay(_ day: Date) {
        let calendar = Calendar.current
        let normalizedDay = calendar.startOfDay(for: day)
        let normalizedMonth = calendar.startOfMonth(for: normalizedDay)

        selectedDayStorage = normalizedDay
        monthAnchorStorage = normalizedMonth
        refreshSnapshot()
        refreshExternalEvents()
    }

    func selectDay(_ day: Date) {
        let normalizedDay = Calendar.current.startOfDay(for: day)
        guard normalizedDay != selectedDayStorage else { return }
        selectedDayStorage = normalizedDay
        refreshSnapshot()
    }

    func openCreateTask() { onOpenTaskEditor(nil, selectedDayStorage) }
    func openEditTask(id: PersistentIdentifier) { onOpenTaskEditor(id, selectedDayStorage) }
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
        refreshSnapshot()
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
        refreshSnapshot()

        if needsMonthChange {
            refreshExternalEvents()
        }

        return true
    }

    func isVisuallyDone(taskId: PersistentIdentifier, modelCompleted: Bool) -> Bool {
        visualDoneOverride[taskId] ?? modelCompleted
    }

    func toggleDoneTwoPhase(taskId: PersistentIdentifier, on day: Date) {
        pendingToggleTasks[taskId]?.cancel()

        let dayKey = Calendar.current.startOfDay(for: day)

        let task = Task { [weak self] in
            guard let self else { return }

            do {
                guard let taskEntity = try self.taskRepository.fetch(by: taskId) else {
                    assertionFailure("toggleDoneTwoPhase: task not found")
                    return
                }

                let currentlyCompleted = taskEntity.isCompleted(on: dayKey)
                let targetCompleted = !currentlyCompleted

                self.visualDoneOverride[taskId] = targetCompleted

                try await Task.sleep(nanoseconds: self.donePhaseDelay)
                guard !Task.isCancelled else { return }

                withAnimation(self.moveAnim) {
                    self.sortDoneOverride[taskId] = targetCompleted
                    self.invalidateMonthCache()
                    self.refreshSnapshot()
                }

                taskEntity.toggleCompleted(on: dayKey)
                try self.taskRepository.save()

                self.visualDoneOverride[taskId] = nil
                self.sortDoneOverride[taskId] = nil
                self.invalidateMonthCache()
                self.refreshSnapshot()
            } catch {
                assertionFailure("toggleDoneTwoPhase failed: \(error)")
                self.visualDoneOverride[taskId] = nil
                self.sortDoneOverride[taskId] = nil
                self.invalidateMonthCache()
                self.refreshSnapshot()
            }
        }

        pendingToggleTasks[taskId] = task
    }

    func delete(taskId: PersistentIdentifier) {
        pendingToggleTasks[taskId]?.cancel()
        visualDoneOverride[taskId] = nil
        sortDoneOverride[taskId] = nil
        invalidateMonthCache()
        refreshSnapshot()

        do {
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
        taskId: PersistentIdentifier,
        occurrenceStartDay: Date,
        scope: TaskSeriesService.Scope
    ) {
        pendingToggleTasks[taskId]?.cancel()
        visualDoneOverride[taskId] = nil
        sortDoneOverride[taskId] = nil
        invalidateMonthCache()
        refreshSnapshot()

        do {
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
        sourceTasks = tasks
        invalidateMonthCache()
        refreshSnapshot()
    }

    @discardableResult
    private func loadPreferences() -> Bool {
        let previousWeekStartsOnMonday = weekStartsOnMonday
        let previousOverlayEnabled = isOverlayEnabled
        let hadExternalEvents = !externalEventsByDay.isEmpty

        do {
            let prefs = try preferencesRepository.getOrCreate()
            weekStartsOnMonday = prefs.weekStartsOnMonday
            isOverlayEnabled = prefs.showAppleCalendarEventsInPlanner
        } catch {
            weekStartsOnMonday = true
            isOverlayEnabled = false
        }

        if !isOverlayEnabled {
            externalMonthTask?.cancel()
            externalEventsByDay = [:]
        }

        let didChangeMonthInputs =
            previousWeekStartsOnMonday != weekStartsOnMonday ||
            previousOverlayEnabled != isOverlayEnabled ||
            (hadExternalEvents && !isOverlayEnabled)

        if didChangeMonthInputs {
            invalidateMonthCache()
            refreshSnapshot()
        }

        if isOverlayEnabled && (
            previousWeekStartsOnMonday != weekStartsOnMonday ||
            previousOverlayEnabled != isOverlayEnabled
        ) {
            refreshExternalEvents()
        }

        return didChangeMonthInputs
    }

    private func refreshExternalEvents() {
        guard isOverlayEnabled else { return }

        externalMonthTask?.cancel()
        externalMonthTask = Task { [weak self] in
            guard let self else { return }
            await self.loadExternalEventsForVisibleMonth()
        }
    }

    private func loadExternalEventsForVisibleMonth() async {
        guard isOverlayEnabled else { return }

        let calendar = Calendar.current
        let start = calendar.startOfMonth(for: monthAnchorStorage)
        let end = calendar.date(byAdding: .month, value: 1, to: start) ?? start.addingTimeInterval(30 * 86_400)

        do {
            let events = try await calendarSync.fetchReadOnlyEvents(
                start: start,
                end: end,
                excludeTaskPlannerCalendar: true
            )
            guard !Task.isCancelled, isOverlayEnabled else { return }

            var grouped: [Date: [ExternalCalendarEvent]] = [:]
            grouped.reserveCapacity(42)

            for event in events {
                let dayKey = calendar.startOfDay(for: event.startDate)
                grouped[dayKey, default: []].append(event)
            }

            for key in grouped.keys {
                grouped[key]?.sort { $0.startDate < $1.startDate }
            }

            externalEventsByDay = grouped
        } catch {
            externalEventsByDay = [:]
        }

        invalidateMonthCache()
        refreshSnapshot()
    }

    private func refreshSnapshot() {
        let calendar = TaskOccurrence.calendar(weekStartsOnMonday: weekStartsOnMonday)
        let normalizedMonthAnchor = calendar.startOfMonth(for: monthAnchorStorage)

        let monthKey = PlannerMonthBuildKey(
            monthAnchor: normalizedMonthAnchor,
            weekStartsOnMonday: weekStartsOnMonday
        )

        let monthBuild: PlannerMonthBuildOutput
        if let cached = monthCache.value(for: monthKey) {
            monthBuild = cached
        } else {
            let built = snapshotBuilder.buildMonth(
                tasks: sourceTasks,
                monthAnchor: normalizedMonthAnchor,
                weekStartsOnMonday: weekStartsOnMonday,
                externalEventsByDay: externalEventsByDay,
                isOverlayEnabled: isOverlayEnabled,
                sortDoneOverride: sortDoneOverride
            )
            monthCache.insert(built, for: monthKey)
            monthBuild = built
        }

        let selectedDaySnapshot = snapshotBuilder.buildSelectedDaySnapshot(
            selectedDay: selectedDayStorage,
            monthBuild: monthBuild,
            tasks: sourceTasks,
            weekStartsOnMonday: weekStartsOnMonday,
            externalEventsByDay: externalEventsByDay,
            isOverlayEnabled: isOverlayEnabled,
            sortDoneOverride: sortDoneOverride
        )

        snapshot = PlannerScreenSnapshot(
            month: monthBuild.monthSnapshot,
            selectedDay: selectedDaySnapshot
        )
    }

    private func invalidateMonthCache() {
        monthCache.invalidateAll()
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
