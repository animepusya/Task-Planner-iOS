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

    func openCreateTask() {
        onOpenTaskEditor(nil, selectedDay)
    }

    func openEditTask(id: PersistentIdentifier) {
        onOpenTaskEditor(id, selectedDay)
    }

    // Month switching
    func goToPreviousMonth() { monthAnchor = monthAnchor.addingMonths(-1) }
    func goToNextMonth() { monthAnchor = monthAnchor.addingMonths(1) }

    // MARK: - Swipe actions

    func toggleDone(taskId: PersistentIdentifier, on day: Date) {
        do {
            guard let task = try taskRepository.fetch(by: taskId) else {
                assertionFailure("toggleDone: task not found")
                return
            }
            // ✅ Per-day completion (visual-only). Status НЕ трогаем.
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

    func occurs(
        _ task: TaskEntity,
        on date: Date,
        weekStartsOnMonday: Bool
    ) -> Bool {
        let cal = calendar(weekStartsOnMonday: weekStartsOnMonday)

        let targetDay = cal.startOfDay(for: date)
        let baseDay = cal.startOfDay(for: task.dayDate)

        // никогда не показываем до даты создания
        guard targetDay >= baseDay else { return false }

        switch task.repeatRule {
        case .none:
            return cal.isDate(targetDay, inSameDayAs: baseDay)

        case .daily:
            return true

        case .weekly:
            // same weekday
            return cal.component(.weekday, from: targetDay) == cal.component(.weekday, from: baseDay)

        case .monthly:
            // same day-of-month; если в месяце нет такого дня, такого date просто не будет,
            // значит автоматом "пропуск"
            return cal.component(.day, from: targetDay) == cal.component(.day, from: baseDay)
        }
    }

    func tasksForDay(_ date: Date, from tasks: [TaskEntity]) -> [TaskEntity] {
        let dayKey = Calendar.current.startOfDay(for: date)

        return tasks
            .filter { occurs($0, on: dayKey, weekStartsOnMonday: weekStartsOnMonday) }
            .sorted {
                let lhsCompleted = $0.isCompleted(on: dayKey)
                let rhsCompleted = $1.isCompleted(on: dayKey)
                if lhsCompleted != rhsCompleted { return !lhsCompleted } // incomplete first

                return TaskSorting.timeSortKey($0.startTime) <
                       TaskSorting.timeSortKey($1.startTime)
            }
    }

    // MARK: - Calendar indicators

    /// Возвращает цвета (до 3) для самых ранних задач дня + overflow (сколько задач сверх 3)
    func indicatorColors(for date: Date, tasks: [TaskEntity]) -> [TaskColor] {
        let dayKey = Calendar.current.startOfDay(for: date)

        let occurringAndIncomplete = tasks
            .filter { task in
                occurs(task, on: dayKey, weekStartsOnMonday: weekStartsOnMonday)
                && !task.isCompleted(on: dayKey)
            }
            .sorted {
                TaskSorting.timeSortKey($0.startTime) <
                TaskSorting.timeSortKey($1.startTime)
            }

        return Array(occurringAndIncomplete.prefix(3).map { $0.color })
    }
}
