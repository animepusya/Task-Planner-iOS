//
//  PlannerViewModel.swift
//  Task Planner
//
//  Created by Руслан Меланин on 09.02.2026.
//

import Foundation
import SwiftData
import Combine
import SwiftUI

@MainActor
final class PlannerViewModel: ObservableObject {
    private let taskRepository: TaskRepository
    private let preferencesRepository: PreferencesRepository
    private let onOpenTaskEditor: (_ taskId: PersistentIdentifier?, _ day: Date) -> Void

    @Published var selectedDay: Date = Calendar.current.startOfDay(for: .now)
    @Published var monthAnchor: Date = Calendar.current.startOfDay(for: .now)
    @Published var weekStartsOnMonday: Bool = true

    @Published private(set) var visualDoneOverride: [PersistentIdentifier: Bool] = [:]
    @Published private(set) var sortDoneOverride: [PersistentIdentifier: Bool] = [:]

    private var pendingToggleTasks: [PersistentIdentifier: Task<Void, Never>] = [:]

    private let donePhaseDelay: UInt64 = 800_000_000
    private let moveAnim: Animation = .easeInOut(duration: 0.8)

    init(
        taskRepository: TaskRepository,
        preferencesRepository: PreferencesRepository,
        onOpenTaskEditor: @escaping (_ taskId: PersistentIdentifier?, _ day: Date) -> Void
    ) {
        self.taskRepository = taskRepository
        self.preferencesRepository = preferencesRepository
        self.onOpenTaskEditor = onOpenTaskEditor

        loadPreferences()
    }

    func loadPreferences() {
        do {
            let prefs = try preferencesRepository.getOrCreate()
            weekStartsOnMonday = prefs.weekStartsOnMonday
        } catch {
            weekStartsOnMonday = true
        }
    }

    func openCreateTask() { onOpenTaskEditor(nil, selectedDay) }
    func openEditTask(id: PersistentIdentifier) { onOpenTaskEditor(id, selectedDay) }

    func goToPreviousMonth() { monthAnchor = monthAnchor.addingMonths(-1) }
    func goToNextMonth() { monthAnchor = monthAnchor.addingMonths(1) }

    func setMonthAnchor(_ date: Date) {
        monthAnchor = Calendar.current.startOfMonth(for: date)
    }

    func goToToday() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        selectedDay = today
        monthAnchor = cal.startOfMonth(for: today)
    }

    // MARK: - Visual helpers

    func isVisuallyDone(taskId: PersistentIdentifier, modelCompleted: Bool) -> Bool {
        visualDoneOverride[taskId] ?? modelCompleted
    }

    private func isCompletedForSort(task: TaskEntity, taskId: PersistentIdentifier, dayKey: Date) -> Bool {
        sortDoneOverride[taskId] ?? task.isCompleted(on: dayKey)
    }

    // MARK: - Two-phase Done/Undo

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

                // Реальная запись в модель
                taskEntity.toggleCompleted(on: dayKey)
                try self.taskRepository.save()

                // cleanup: убираем overrides
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
}

// MARK: - Sorting / building day occurrences

extension PlannerViewModel {

    func tasksForDay(_ date: Date, from tasks: [TaskEntity]) -> [DayOccurrence] {
        let cal = TaskOccurrence.calendar(weekStartsOnMonday: weekStartsOnMonday)
        let dayKey = cal.startOfDay(for: date)

        let occs = TaskDaySegment.occurrences(
            for: dayKey,
            from: tasks,
            weekStartsOnMonday: weekStartsOnMonday
        )

        return occs.sorted {
            let lhsId = $0.task.persistentModelID
            let rhsId = $1.task.persistentModelID

            // сортировка опирается на sortDoneOverride, а не только на модель
            let lhsCompleted = isCompletedForSort(task: $0.task, taskId: lhsId, dayKey: dayKey)
            let rhsCompleted = isCompletedForSort(task: $1.task, taskId: rhsId, dayKey: dayKey)

            if lhsCompleted != rhsCompleted { return !lhsCompleted }

            if $0.displayStart != $1.displayStart { return $0.displayStart < $1.displayStart }

            return $0.task.title.localizedCaseInsensitiveCompare($1.task.title) == .orderedAscending
        }
    }

    func indicatorColors(for date: Date, tasks: [TaskEntity]) -> [TaskColor] {
        let cal = TaskOccurrence.calendar(weekStartsOnMonday: weekStartsOnMonday)
        let dayKey = cal.startOfDay(for: date)

        let occurringAndIncomplete = tasks
            .filter { task in
                TaskDayOverlap.affectsDay(task: task, day: dayKey, weekStartsOnMonday: weekStartsOnMonday)
                && !task.isCompleted(on: dayKey)
            }
            .sorted {
                let lhsStart = TaskDayOverlap.effectiveStartOnDay(task: $0, day: dayKey, weekStartsOnMonday: weekStartsOnMonday) ?? $0.startTime
                let rhsStart = TaskDayOverlap.effectiveStartOnDay(task: $1, day: dayKey, weekStartsOnMonday: weekStartsOnMonday) ?? $1.startTime
                return lhsStart < rhsStart
            }

        return Array(occurringAndIncomplete.prefix(3).map { $0.color })
    }
}
