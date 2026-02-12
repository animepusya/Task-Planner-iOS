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

    private let time: TaskEditorTimeCoordinator
    private let category: TaskEditorCategoryCoordinator

    // UI State
    @Published var isBusy: Bool = false
    @Published var alertTitle: String?
    @Published var alertMessage: String?

    @Published var timeValidationMessage: String?

    @Published var repeatValidationMessage: String?
    @Published var isRepeatInvalid: Bool = false

    // Form fields
    @Published var title: String = ""
    @Published var notes: String = ""

    @Published var dayDate: Date
    @Published var endDayDate: Date

    @Published var startTime: Date
    @Published var endTime: Date

    @Published var repeatRule: RepeatRule = .none {
        didSet { validateRepeatConflict() }
    }
    @Published var repeatIntervalDays: Int = 2 {
        didSet { validateRepeatConflict() }
    }

    @Published var color: TaskColor = .purple
    @Published var categoryTitle: String = "Work"

    var isEditing: Bool { taskId != nil }
    var navigationTitle: String { isEditing ? "Edit Task" : "Create Task" }

    var canSave: Bool { !isBusy && !isRepeatInvalid }
    
    init(taskRepository: TaskRepository, taskId: PersistentIdentifier?, preselectedDay: Date) {
        self.taskRepository = taskRepository
        self.taskId = taskId

        self.time = TaskEditorTimeCoordinator(calendar: .current)
        self.category = TaskEditorCategoryCoordinator()

        let startDay = Calendar.current.startOfDay(for: preselectedDay)
        self.dayDate = startDay
        self.endDayDate = startDay

        self.startTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: startDay) ?? startDay
        self.endTime = Calendar.current.date(bySettingHour: 9, minute: 30, second: 0, of: startDay) ?? startDay

        if taskId != nil {
            Task { [weak self] in
                await self?.loadExistingTask()
            }
        } else {
            let result = time.validateAndFix(
                dayDate: dayDate,
                endDayDate: endDayDate,
                startTime: startTime,
                endTime: endTime
            )
            apply(result) // ✅ also validates repeat via apply()
        }
    }

    // MARK: - View Hooks

    func onAppear(availableCategories: [String]) {
        ensureCategoryIsValid(available: availableCategories)

        let synced = time.syncTimesToSelectedDay(
            newStartDay: dayDate,
            startTime: startTime,
            endDayDate: endDayDate,
            endTime: endTime
        )
        apply(synced)

        let validated = time.validateAndFix(
            dayDate: dayDate,
            endDayDate: endDayDate,
            startTime: startTime,
            endTime: endTime
        )
        apply(validated)
    }

    func onStartDayChanged() {
        let synced = time.syncTimesToSelectedDay(
            newStartDay: dayDate,
            startTime: startTime,
            endDayDate: endDayDate,
            endTime: endTime
        )
        apply(synced)

        let validated = time.validateAndFix(
            dayDate: dayDate,
            endDayDate: endDayDate,
            startTime: startTime,
            endTime: endTime
        )
        apply(validated)
    }

    func onStartTimeChanged() {
        startTime = time.alignStartTimeToSelectedDay(dayDate: dayDate, startTime: startTime)

        let validated = time.validateAndFix(
            dayDate: dayDate,
            endDayDate: endDayDate,
            startTime: startTime,
            endTime: endTime
        )
        apply(validated)
    }

    func onEndDayChanged(triggerFeedback: Bool) {
        let clamped = time.clampEndDayDateIfNeeded(
            dayDate: dayDate,
            endDayDate: endDayDate,
            startTime: startTime,
            endTime: endTime
        )
        apply(clamped)

        endTime = time.alignEndTimeToEndDay(endDayDate: endDayDate, endTime: endTime)

        let validated = time.validateAndFix(
            dayDate: dayDate,
            endDayDate: endDayDate,
            startTime: startTime,
            endTime: endTime
        )
        apply(validated)
    }

    func onEndTimeChanged() {
        endTime = time.alignEndTimeToEndDay(endDayDate: endDayDate, endTime: endTime)
        
        let validated = time.validateAndFix(
            dayDate: dayDate,
            endDayDate: endDayDate,
            startTime: startTime,
            endTime: endTime
        )
        apply(validated)
    }

    // MARK: - Category

    func ensureCategoryIsValid(available: [String]) {
        categoryTitle = category.ensureCategoryIsValid(current: categoryTitle, available: available)
    }

    // MARK: - Loading

    func loadExistingTask() async {
        guard let taskId else { return }

        isBusy = true
        defer { isBusy = false }

        do {
            guard let existing = try taskRepository.fetch(by: taskId) else {
                alertTitle = "Task not found"
                alertMessage = "This task no longer exists."
                return
            }

            title = existing.title
            notes = existing.notes ?? ""

            dayDate = time.startOfDay(existing.dayDate)
            startTime = existing.startTime
            endTime = existing.endTime
            endDayDate = time.startOfDay(existing.endTime)

            repeatRule = existing.repeatRule
            repeatIntervalDays = existing.repeatIntervalDays ?? 2
            color = existing.color
            categoryTitle = existing.categoryTitle ?? CategorySystem.uncategorizedTitle

            let clamped = time.clampEndDayDateIfNeeded(
                dayDate: dayDate,
                endDayDate: endDayDate,
                startTime: startTime,
                endTime: endTime
            )
            apply(clamped)

            let synced = time.syncTimesToSelectedDay(
                newStartDay: dayDate,
                startTime: startTime,
                endDayDate: endDayDate,
                endTime: endTime
            )
            apply(synced)

            let validated = time.validateAndFix(
                dayDate: dayDate,
                endDayDate: endDayDate,
                startTime: startTime,
                endTime: endTime
            )
            apply(validated)

        } catch {
            alertTitle = "Failed to load"
            alertMessage = error.localizedDescription
        }
    }

    // MARK: - Time UX

    func applyDuration(minutes: Int) {
        let result = time.applyDuration(
            minutes: minutes,
            dayDate: dayDate,
            startTime: startTime
        )
        
        endDayDate = result.endDayDate
        endTime = result.endTime
        startTime = result.startTime
        timeValidationMessage = nil

        let clamped = time.clampEndDayDateIfNeeded(
            dayDate: dayDate,
            endDayDate: endDayDate,
            startTime: startTime,
            endTime: endTime
        )
        apply(clamped) // ✅ repeat conflict validated inside apply()
    }

    // MARK: - Save

    func save() throws {
        let clamped = time.clampEndDayDateIfNeeded(
            dayDate: dayDate,
            endDayDate: endDayDate,
            startTime: startTime,
            endTime: endTime
        )
        apply(clamped)
        
        if isRepeatInvalid && repeatRule != .none {
            throw EditorError.repeatConflict
        }

        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeTitle = normalizedTitle.isEmpty ? "Untitled" : normalizedTitle

        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedNotes: String? = trimmedNotes.isEmpty ? nil : trimmedNotes

        let trimmedCategory = categoryTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedCategory = trimmedCategory.isEmpty ? "Work" : trimmedCategory

        let normalizedTimes = time.normalizeForSave(
            dayDate: dayDate,
            endDayDate: endDayDate,
            startTime: startTime,
            endTime: endTime
        )

        let finalTimes = time.ensureNextDayIfSameDayEndBeforeOrEqualStart(
            dayDate: dayDate,
            start: normalizedTimes.start,
            endDayDate: endDayDate,
            end: normalizedTimes.end
        )

        let intervalOrNil: Int? = (repeatRule == .everyNDays) ? max(1, repeatIntervalDays) : nil

        if let taskId {
            guard let existing = try taskRepository.fetch(by: taskId) else {
                throw EditorError.taskNotFound
            }

            existing.title = safeTitle
            existing.notes = normalizedNotes
            existing.dayDate = time.startOfDay(dayDate)
            existing.startTime = finalTimes.start
            existing.endTime = finalTimes.end

            existing.repeatRule = repeatRule
            existing.repeatIntervalDays = intervalOrNil
            existing.normalizeRepeatFields()

            existing.color = color
            existing.categoryTitle = normalizedCategory

            try taskRepository.save()
        } else {
            let new = TaskEntity(
                title: safeTitle,
                notes: normalizedNotes,
                dayDate: time.startOfDay(dayDate),
                startTime: finalTimes.start,
                endTime: finalTimes.end,
                repeatRule: repeatRule,
                repeatIntervalDays: intervalOrNil,
                status: .todo,
                color: color,
                categoryTitle: normalizedCategory
            )
            new.normalizeRepeatFields()
            try taskRepository.add(new)
        }
    }

    // MARK: - Apply helper

    private func apply(_ result: TaskEditorTimeCoordinator.Result) {
        dayDate = result.dayDate
        endDayDate = result.endDayDate
        startTime = result.startTime
        endTime = result.endTime
        timeValidationMessage = result.message
        
        validateRepeatConflict()
    }

    enum EditorError: LocalizedError {
        case taskNotFound
        case repeatConflict
        
        var errorDescription: String? {
            switch self {
            case .taskNotFound:
                return "The task was not found. It may have been deleted."
            case .repeatConflict:
                return "Repeat unavailable: task overlaps the next occurrence."
            }
        }
    }
    
    // MARK: - Repeat Conflict
    
    private func validateRepeatConflict() {
        let conflict = time.isRepeatConflict(
            dayDate: dayDate,
            endDayDate: endDayDate,
            startTime: startTime,
            endTime: endTime,
            repeatRule: repeatRule,
            repeatIntervalDays: repeatIntervalDays
        )
        
        if conflict {
            isRepeatInvalid = true
            repeatValidationMessage = "Repeat unavailable: task overlaps the next occurrence."
        } else {
            isRepeatInvalid = false
            repeatValidationMessage = nil
        }
    }
}
