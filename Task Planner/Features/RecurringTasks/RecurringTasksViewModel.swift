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
    private let taskRepository: TaskRepository
    private let preferencesRepository: PreferencesRepository
    private let onOpenBaseRecurringEditor: (_ taskId: PersistentIdentifier, _ day: Date) -> Void

    @Published private(set) var weekStartsOnMonday: Bool = true

    init(
        taskRepository: TaskRepository,
        preferencesRepository: PreferencesRepository,
        onOpenBaseRecurringEditor: @escaping (_ taskId: PersistentIdentifier, _ day: Date) -> Void
    ) {
        self.taskRepository = taskRepository
        self.preferencesRepository = preferencesRepository
        self.onOpenBaseRecurringEditor = onOpenBaseRecurringEditor
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

    func open(task: TaskEntity) {
        onOpenBaseRecurringEditor(task.persistentModelID, Calendar.current.startOfDay(for: task.dayDate))
    }

    func deleteSeries(taskId: PersistentIdentifier) {
        do {
            guard let task = try taskRepository.fetch(by: taskId) else { return }
            try taskRepository.delete(task)
        } catch {
            assertionFailure("deleteSeries failed: \(error)")
        }
    }

    func sections(from tasks: [TaskEntity]) -> Sections {
        let recurring = tasks
            .filter { $0.repeatRule != .none }
            .sorted { lhs, rhs in
                if lhs.title != rhs.title {
                    return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
                }
                return lhs.dayDate < rhs.dayDate
            }

        let active = recurring.filter { isActive($0) }
        let past = recurring.filter { !isActive($0) }

        return Sections(active: active, past: past)
    }

    private func isActive(_ task: TaskEntity) -> Bool {
        let cal = TaskOccurrence.calendar(weekStartsOnMonday: weekStartsOnMonday)
        let today = cal.startOfDay(for: .now)

        if TaskOccurrence.occursStartOn(task, on: today, weekStartsOnMonday: weekStartsOnMonday) {
            return true
        }

        let yesterday = cal.date(byAdding: .day, value: -1, to: today) ?? today.addingTimeInterval(-86400)

        return TaskSeriesEngine.nextOccurrenceStartDay(
            for: task,
            after: yesterday,
            weekStartsOnMonday: weekStartsOnMonday
        ) != nil
    }

    struct Sections {
        let active: [TaskEntity]
        let past: [TaskEntity]
    }
}
