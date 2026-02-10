//
//  TaskEditorViewModel.swift
//  Task Planner
//
//  Created by Руслан Меланин on 09.02.2026.
//

import Foundation
import SwiftData
import Combine

@MainActor
final class TaskEditorViewModel: ObservableObject {
    private let taskRepository: TaskRepository
    private let taskId: PersistentIdentifier?

    // UI State
    @Published var isBusy: Bool = false
    @Published var alertTitle: String?
    @Published var alertMessage: String?

    // Form fields
    @Published var title: String = ""
    @Published var notes: String = ""

    @Published var dayDate: Date
    @Published var startTime: Date
    @Published var endTime: Date

    @Published var repeatRule: RepeatRule = .daily
    @Published var color: TaskColor = .purple
    @Published var categoryTitle: String = ""

    private let calendar = Calendar.current

    var isEditing: Bool { taskId != nil }
    var navigationTitle: String { isEditing ? "Edit Task" : "Create Task" }

    init(taskRepository: TaskRepository, taskId: PersistentIdentifier?, preselectedDay: Date) {
        self.taskRepository = taskRepository
        self.taskId = taskId

        let day = calendar.startOfDay(for: preselectedDay)
        self.dayDate = day

        // дефолтные времена — на выбранный день, без секунд
        self.startTime = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: day) ?? day
        self.endTime = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: day) ?? day

        // ✅ Ключевой фикс: если редактирование — загружаем сразу
        if taskId != nil {
            Task { [weak self] in
                await self?.loadExistingTask()
            }
        }
    }

    // MARK: - Loading

    func loadExistingTask() async {
        guard let taskId else { return }

        isBusy = true
        defer { isBusy = false }

        do {
            guard let existing = try taskRepository.fetch(by: taskId) else {
                alertTitle = "Task not found"
                alertMessage = "This task no longer exists. You can close this screen or create a new task."
                return
            }

            // ✅ Заполняем поля
            title = existing.title
            notes = existing.notes ?? ""
            dayDate = calendar.startOfDay(for: existing.dayDate)
            startTime = existing.startTime
            endTime = existing.endTime
            repeatRule = existing.repeatRule
            color = existing.color
            categoryTitle = existing.categoryTitle ?? ""

            // ✅ На всякий: синхронизируем время с dayDate (если вдруг start/end лежали на другом дне)
            syncTimesToSelectedDay()
        } catch {
            alertTitle = "Failed to load"
            alertMessage = error.localizedDescription
        }
    }

    // ✅ Если пользователь меняет дату — переносим время на новый день, сохраняя часы/минуты
    func syncTimesToSelectedDay() {
        let day = calendar.startOfDay(for: dayDate)
        startTime = combine(day: day, time: startTime)
        endTime = combine(day: day, time: endTime)
    }

    // MARK: - Save

    func save() throws {
        let day = calendar.startOfDay(for: dayDate)

        var start = combine(day: day, time: startTime)
        var end = combine(day: day, time: endTime)

        if end < start { end = start }

        let normalizedCategory: String? = categoryTitle
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
        ? nil
        : categoryTitle.trimmingCharacters(in: .whitespacesAndNewlines)

        if let taskId {
            // ✅ строго редактирование
            guard let existing = try taskRepository.fetch(by: taskId) else {
                throw EditorError.taskNotFound
            }

            existing.title = title.isEmpty ? "Untitled" : title
            existing.notes = notes.isEmpty ? nil : notes
            existing.dayDate = day
            existing.startTime = start
            existing.endTime = end
            existing.repeatRule = repeatRule
            existing.color = color
            existing.categoryTitle = normalizedCategory

            try taskRepository.save()
        } else {
            // ✅ создание
            let new = TaskEntity(
                title: title.isEmpty ? "Untitled" : title,
                notes: notes.isEmpty ? nil : notes,
                dayDate: day,
                startTime: start,
                endTime: end,
                repeatRule: repeatRule,
                status: .todo,
                color: color,
                categoryTitle: normalizedCategory
            )
            try taskRepository.add(new)
        }
    }

    // MARK: - Helpers

    private func combine(day: Date, time: Date) -> Date {
        let dayStart = calendar.startOfDay(for: day)
        let comps = calendar.dateComponents([.hour, .minute], from: time)
        let hour = comps.hour ?? 0
        let minute = comps.minute ?? 0
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: dayStart) ?? dayStart
    }

    enum EditorError: LocalizedError {
        case taskNotFound

        var errorDescription: String? {
            switch self {
            case .taskNotFound:
                return "The task was not found. It may have been deleted."
            }
        }
    }
}



