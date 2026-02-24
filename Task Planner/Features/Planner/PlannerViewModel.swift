//
//  PlannerViewModel.swift
//  Task Planner
//
//  Created by Руслан Меланин on 09.02.2026.
//

import Foundation
import SwiftData
import Combine

@MainActor
final class PlannerViewModel: ObservableObject {
    private let taskRepository: TaskRepository
    private let preferencesRepository: PreferencesRepository

    private let onOpenTaskEditor: (_ taskId: PersistentIdentifier?, _ day: Date) -> Void

    @Published var selectedDay: Date = Calendar.current.startOfDay(for: .now)
    @Published var monthAnchor: Date = Calendar.current.startOfDay(for: .now)
    @Published var weekStartsOnMonday: Bool = true

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

    // Month switching
    func goToPreviousMonth() { monthAnchor = monthAnchor.addingMonths(-1) }
    func goToNextMonth() { monthAnchor = monthAnchor.addingMonths(1) }

    func setMonthAnchor(_ date: Date) {
        monthAnchor = Calendar.current.startOfMonth(for: date)
    }

    // ✅ Today: и месяц, и выбранный день
    func goToToday() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        selectedDay = today
        monthAnchor = cal.startOfMonth(for: today)
    }

    // MARK: - Swipe actions

    func toggleDone(taskId: PersistentIdentifier, on day: Date) {
        do {
            guard let task = try taskRepository.fetch(by: taskId) else {
                assertionFailure("toggleDone: task not found")
                return
            }
            task.toggleCompleted(on: day)
            try taskRepository.save()
        } catch {
            assertionFailure("toggleDone failed: \(error)")
        }
    }

    func delete(taskId: PersistentIdentifier) {
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

extension PlannerViewModel {

    // Calendar с учетом настройки начала недели (на occurs по weekday обычно не влияет,
    // но держим единый источник истины)
    private func calendar(weekStartsOnMonday: Bool) -> Calendar {
        var cal = Calendar.current
        cal.firstWeekday = weekStartsOnMonday ? 2 : 1
        return cal
    }

    func tasksForDay(_ date: Date, from tasks: [TaskEntity]) -> [DayOccurrence] {
        let cal = TaskOccurrence.calendar(weekStartsOnMonday: weekStartsOnMonday)
        let dayKey = cal.startOfDay(for: date)
        
        let occs = TaskDaySegment.occurrences(
            for: dayKey,
            from: tasks,
            weekStartsOnMonday: weekStartsOnMonday
        )
        
        return occs.sorted {
            let lhsCompleted = $0.task.isCompleted(on: dayKey)
            let rhsCompleted = $1.task.isCompleted(on: dayKey)
            if lhsCompleted != rhsCompleted { return !lhsCompleted }
            
            // sort by actual start inside this day
            if $0.displayStart != $1.displayStart { return $0.displayStart < $1.displayStart }
            
            // tie-breaker: title
            return $0.task.title.localizedCaseInsensitiveCompare($1.task.title) == .orderedAscending
        }
    }

    // MARK: - Calendar indicators

    /// Возвращает цвета (до 3) для самых ранних задач дня + overflow (сколько задач сверх 3)
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
