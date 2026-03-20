//
//  PlannerViewModel.swift
//  Task Planner
//
//  Created by Руслан Меланин on 09.02.2026.
//

import Foundation
import Combine
import SwiftData
import SwiftUI

@MainActor
final class PlannerViewModel: ObservableObject {
    private let taskRepository: TaskRepository
    private let preferencesRepository: PreferencesRepository
    private let calendarSync: CalendarSyncService
    private let onOpenTaskEditor: (_ taskId: PersistentIdentifier?, _ day: Date) -> Void
    private let onOpenNotifications: () -> Void
    private let onOpenRecurringBaseTasks: () -> Void
    private let seriesService: TaskSeriesService

    private let snapshotBuilder = PlannerScreenSnapshotBuilder()

    private var sourceTasks: [TaskEntity] = []

    @Published private(set) var selectedDay: Date
    @Published private(set) var monthAnchor: Date
    @Published private(set) var weekStartsOnMonday: Bool = true

    @Published private(set) var externalEventsByDay: [Date: [ExternalCalendarEvent]] = [:] {
        didSet { rebuildSnapshot() }
    }

    @Published private(set) var isOverlayEnabled: Bool = false {
        didSet { rebuildSnapshot() }
    }

    @Published private(set) var visualDoneOverride: [PersistentIdentifier: Bool] = [:]

    @Published private(set) var sortDoneOverride: [PersistentIdentifier: Bool] = [:] {
        didSet { rebuildSnapshot() }
    }

    @Published private(set) var snapshot: PlannerScreenSnapshot = .empty

    private var pendingToggleTasks: [PersistentIdentifier: Task<Void, Never>] = [:]
    private var externalMonthTask: Task<Void, Never>?

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

        self.selectedDay = today
        self.monthAnchor = calendar.startOfMonth(for: today)

        loadPreferences()
        rebuildSnapshot()

        Task { await loadExternalEventsForVisibleMonth() }
    }

    func updateSourceTasks(_ tasks: [TaskEntity]) {
        sourceTasks = tasks
        rebuildSnapshot()
    }

    func applyExternalSelectedDay(_ day: Date) {
        let calendar = Calendar.current
        let normalizedDay = calendar.startOfDay(for: day)
        let normalizedMonth = calendar.startOfMonth(for: normalizedDay)

        selectedDay = normalizedDay
        monthAnchor = normalizedMonth
        rebuildSnapshot()
        refreshExternalEvents()
    }

    func selectDay(_ day: Date) {
        let normalizedDay = Calendar.current.startOfDay(for: day)
        guard normalizedDay != selectedDay else { return }
        selectedDay = normalizedDay
        rebuildSnapshot()
    }

    func loadPreferences() {
        do {
            let prefs = try preferencesRepository.getOrCreate()

            weekStartsOnMonday = prefs.weekStartsOnMonday

            let overlayEnabled = prefs.showAppleCalendarEventsInPlanner
            isOverlayEnabled = overlayEnabled

            if overlayEnabled {
                refreshExternalEvents()
            } else {
                externalEventsByDay = [:]
            }

            rebuildSnapshot()
        } catch {
            weekStartsOnMonday = true
            isOverlayEnabled = false
            externalEventsByDay = [:]
            rebuildSnapshot()
        }
    }

    func refreshExternalEvents() {
        externalMonthTask?.cancel()
        externalMonthTask = Task { [weak self] in
            guard let self else { return }
            await self.loadExternalEventsForVisibleMonth()
        }
    }

    private func loadExternalEventsForVisibleMonth() async {
        guard isOverlayEnabled else {
            externalEventsByDay = [:]
            return
        }

        let cal = Calendar.current
        let start = cal.startOfMonth(for: monthAnchor)
        let end = cal.date(byAdding: .month, value: 1, to: start) ?? start.addingTimeInterval(30 * 86400)

        do {
            let events = try await calendarSync.fetchReadOnlyEvents(
                start: start,
                end: end,
                excludeTaskPlannerCalendar: true
            )
            guard !Task.isCancelled else { return }

            var grouped: [Date: [ExternalCalendarEvent]] = [:]
            grouped.reserveCapacity(42)

            for ev in events {
                let dayKey = cal.startOfDay(for: ev.startDate)
                grouped[dayKey, default: []].append(ev)
            }

            for key in grouped.keys {
                grouped[key]?.sort { $0.startDate < $1.startDate }
            }

            externalEventsByDay = grouped
        } catch {
            externalEventsByDay = [:]
        }
    }

    func openCreateTask() { onOpenTaskEditor(nil, selectedDay) }
    func openEditTask(id: PersistentIdentifier) { onOpenTaskEditor(id, selectedDay) }
    func openNotifications() { onOpenNotifications() }
    func openRecurringBaseTasks() { onOpenRecurringBaseTasks() }

    func goToPreviousMonth() {
        setMonthAnchor(monthAnchor.addingMonths(-1))
    }

    func goToNextMonth() {
        setMonthAnchor(monthAnchor.addingMonths(1))
    }

    func setMonthAnchor(_ date: Date) {
        let normalized = Calendar.current.startOfMonth(for: date)
        guard normalized != monthAnchor else { return }
        monthAnchor = normalized
        rebuildSnapshot()
        refreshExternalEvents()
    }

    func goToToday() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let todayMonth = cal.startOfMonth(for: today)

        selectedDay = today
        monthAnchor = todayMonth
        rebuildSnapshot()
        refreshExternalEvents()
    }

    func isVisuallyDone(taskId: PersistentIdentifier, modelCompleted: Bool) -> Bool {
        visualDoneOverride[taskId] ?? modelCompleted
    }

    private func rebuildSnapshot() {
        snapshot = snapshotBuilder.build(
            tasks: sourceTasks,
            selectedDay: selectedDay,
            monthAnchor: monthAnchor,
            weekStartsOnMonday: weekStartsOnMonday,
            externalEventsByDay: externalEventsByDay,
            isOverlayEnabled: isOverlayEnabled,
            sortDoneOverride: sortDoneOverride
        )
    }

    func toggleDoneTwoPhase(taskId: PersistentIdentifier, on day: Date) {
        pendingToggleTasks[taskId]?.cancel()

        let dayKey = Calendar.current.startOfDay(for: day)

        let t = Task { [weak self] in
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
                }

                taskEntity.toggleCompleted(on: dayKey)
                try self.taskRepository.save()

                self.visualDoneOverride[taskId] = nil
                self.sortDoneOverride[taskId] = nil
            } catch {
                assertionFailure("toggleDoneTwoPhase failed: \(error)")
                self.visualDoneOverride[taskId] = nil
                self.sortDoneOverride[taskId] = nil
            }
        }

        pendingToggleTasks[taskId] = t
    }

    func delete(taskId: PersistentIdentifier) {
        pendingToggleTasks[taskId]?.cancel()
        visualDoneOverride[taskId] = nil
        sortDoneOverride[taskId] = nil

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
}
