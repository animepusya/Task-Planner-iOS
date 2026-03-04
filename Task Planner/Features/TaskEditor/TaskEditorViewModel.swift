//
//  TaskEditorViewModel.swift
//  Task Planner
//
//  Created by Руслан Меланин on 09.02.2026.
//

import Foundation
import SwiftData
import SwiftUI
import Combine

@MainActor
final class TaskEditorViewModel: ObservableObject {

    // MARK: Dependencies
    private let taskRepository: TaskRepository
    private let preferencesRepository: PreferencesRepository
    private let notificationService: NotificationService

    private let taskId: PersistentIdentifier?
    private let time: TaskEditorTimeCoordinator
    private let category: TaskEditorCategoryCoordinator

    // MARK: UI State
    @Published var isBusy: Bool = false
    @Published var alert: TaskEditorAlert?

    @Published private(set) var form: FormState

    private var didBootstrap = false
    private var weekStartsOnMonday = true

    @Published private(set) var defaultAllDayTimeMinutes: Int = 9 * 60
    @Published private(set) var defaultReminderOffsetMinutes: Int = ReminderPreset.default.minutes

    @Published private(set) var reminderGate: ReminderGate?

    var isEditing: Bool { taskId != nil }
    var navigationTitle: String { isEditing ? "Edit Task" : "Create Task" }
    var canSave: Bool { !isBusy && !form.isRepeatInvalid }

    // MARK: Init
    init(
        taskRepository: TaskRepository,
        preferencesRepository: PreferencesRepository,
        notificationService: NotificationService,
        taskId: PersistentIdentifier?,
        preselectedDay: Date
    ) {
        self.taskRepository = taskRepository
        self.preferencesRepository = preferencesRepository
        self.notificationService = notificationService
        self.taskId = taskId

        self.time = TaskEditorTimeCoordinator(calendar: .current)
        self.category = TaskEditorCategoryCoordinator()

        let startDay = Calendar.current.startOfDay(for: preselectedDay)
        let startTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: startDay) ?? startDay
        let endTime = Calendar.current.date(bySettingHour: 9, minute: 30, second: 0, of: startDay) ?? startDay

        self.form = FormState(
            title: "",
            notes: "",
            dayDate: startDay,
            endDayDate: startDay,
            startTime: startTime,
            endTime: endTime,
            isAllDay: false,
            repeatRule: .none,
            repeatIntervalDays: 2,
            color: .purple,
            categoryTitle: "Work",
            photoThumbData: nil,

            reminderEnabled: false,
            reminderOffsetMinutes: ReminderPreset.default.minutes,
            reminderAllDayTimeMinutes: nil,

            timeValidationMessage: nil,
            isRepeatInvalid: false,
            repeatValidationMessage: nil
        )

        if taskId != nil {
            Task { [weak self] in
                await self?.loadExistingTask()
            }
        } else {
            let validated = time.validateAndFix(
                dayDate: form.dayDate,
                endDayDate: form.endDayDate,
                startTime: form.startTime,
                endTime: form.endTime
            )
            apply(validated)
        }
    }

    // MARK: - Reminder gate types

    struct ReminderGate: Equatable {
        enum Action: Equatable {
            case none
            case openNotificationsCenter
            case openSystemSettings
        }

        let message: String
        let action: Action
    }

    func openSystemSettings() {
        notificationService.openSystemSettings()
    }

    func onAppNotificationsEnabledChanged(_ enabled: Bool) {
        if enabled == false {
            if form.reminderEnabled {
                setReminderEnabledSilently(false)
            }

            reminderGate = ReminderGate(
                message: "Enable notifications in the app to use reminders",
                action: .openNotificationsCenter
            )
        } else {
            if reminderGate?.action == .openNotificationsCenter {
                reminderGate = nil
            }
        }
    }

    private func setReminderEnabledSilently(_ value: Bool) {
        var copy = form
        copy.reminderEnabled = value
        setFormIfChanged(copy)
    }

    // MARK: - Simple Binding helper
    func binding<T>(_ keyPath: WritableKeyPath<FormState, T>) -> Binding<T> {
        Binding(
            get: { self.form[keyPath: keyPath] },
            set: { newValue in
                var copy = self.form
                copy[keyPath: keyPath] = newValue
                self.setFormIfChanged(copy)
            }
        )
    }

    // MARK: - Smart bindings

    var reminderEnabledBinding: Binding<Bool> {
        Binding(
            get: { self.form.reminderEnabled },
            set: { [weak self] newValue in
                guard let self else { return }
                Task { await self.setReminderEnabledAttempt(newValue) }
            }
        )
    }

    var dayDateBinding: Binding<Date> {
        Binding(get: { self.form.dayDate }, set: { [weak self] in self?.setDayDate($0) })
    }

    var startTimeBinding: Binding<Date> {
        Binding(get: { self.form.startTime }, set: { [weak self] in self?.setStartTime($0) })
    }

    var endDayDateBinding: Binding<Date> {
        Binding(get: { self.form.endDayDate }, set: { [weak self] in self?.setEndDayDate($0) })
    }

    var endTimeBinding: Binding<Date> {
        Binding(get: { self.form.endTime }, set: { [weak self] in self?.setEndTime($0) })
    }

    var isAllDayBinding: Binding<Bool> {
        Binding(get: { self.form.isAllDay }, set: { [weak self] in self?.setIsAllDay($0) })
    }

    var repeatRuleBinding: Binding<RepeatRule> {
        Binding(get: { self.form.repeatRule }, set: { [weak self] in self?.setRepeatRule($0) })
    }

    var repeatIntervalDaysBinding: Binding<Int> {
        Binding(get: { self.form.repeatIntervalDays }, set: { [weak self] in self?.setRepeatIntervalDays($0) })
    }

    // MARK: - Reminder toggle pipeline

    private func setReminderEnabledAttempt(_ newValue: Bool) async {
        if newValue == false {
            reminderGate = nil
            setReminderEnabledSilently(false)
            return
        }

        let prefs: AppPreferencesEntity
        do {
            prefs = try preferencesRepository.getOrCreate()
        } catch {
            reminderGate = ReminderGate(
                message: "Enable notifications in the app to use reminders",
                action: .openNotificationsCenter
            )
            setReminderEnabledSilently(false)
            return
        }

        guard prefs.notificationsEnabled else {
            reminderGate = ReminderGate(
                message: "Enable notifications in the app to use reminders",
                action: .openNotificationsCenter
            )
            setReminderEnabledSilently(false)
            return
        }

        let status = await notificationService.getAuthorizationStatus()
        switch status {
        case .authorized:
            reminderGate = nil
            setReminderEnabledSilently(true)

        case .notDetermined:
            let granted = await notificationService.requestAuthorization()
            if granted {
                reminderGate = nil
                setReminderEnabledSilently(true)
            } else {
                reminderGate = ReminderGate(
                    message: "Allow notifications in Settings to use reminders",
                    action: .openSystemSettings
                )
                setReminderEnabledSilently(false)
            }

        case .denied:
            reminderGate = ReminderGate(
                message: "Allow notifications in Settings to use reminders",
                action: .openSystemSettings
            )
            setReminderEnabledSilently(false)
        }
    }

    // MARK: - Bootstrap (idempotent)
    func onAppear(availableCategories: [String]) {
        guard !didBootstrap else { return }
        didBootstrap = true

        do {
            let prefs = try preferencesRepository.getOrCreate()
            weekStartsOnMonday = prefs.weekStartsOnMonday
            defaultAllDayTimeMinutes = prefs.defaultAllDayTimeMinutes

            let normalizedDefaultOffset = ReminderPreset.normalizeOffsetMinutes(prefs.defaultReminderOffsetMinutes)
            defaultReminderOffsetMinutes = normalizedDefaultOffset

            if prefs.defaultReminderOffsetMinutes != normalizedDefaultOffset {
                prefs.defaultReminderOffsetMinutes = normalizedDefaultOffset
                try? preferencesRepository.save()
            }

            if taskId == nil {
                var copy = form
                copy.reminderOffsetMinutes = normalizedDefaultOffset
                setFormIfChanged(copy)
            } else {
                var copy = form
                copy.reminderOffsetMinutes = ReminderPreset.normalizeOffsetMinutes(copy.reminderOffsetMinutes)
                setFormIfChanged(copy)
            }
        } catch {
            weekStartsOnMonday = true
            defaultAllDayTimeMinutes = 9 * 60
            defaultReminderOffsetMinutes = ReminderPreset.default.minutes
        }

        ensureCategoryIsValid(available: availableCategories)

        let synced = time.syncTimesToSelectedDay(
            newStartDay: form.dayDate,
            startTime: form.startTime,
            endDayDate: form.endDayDate,
            endTime: form.endTime
        )

        let validated = time.validateAndFix(
            dayDate: synced.dayDate,
            endDayDate: synced.endDayDate,
            startTime: synced.startTime,
            endTime: synced.endTime
        )

        apply(validated)
    }

    // MARK: - Setters
    func setDayDate(_ newValue: Date) {
        let newDay = time.startOfDay(newValue)
        guard !Calendar.current.isDate(newDay, inSameDayAs: form.dayDate) else { return }

        var copy = form
        copy.dayDate = newDay
        setFormIfChanged(copy)

        onStartDayChanged()
    }

    func setStartTime(_ newValue: Date) {
        guard newValue != form.startTime else { return }
        var copy = form
        copy.startTime = newValue
        setFormIfChanged(copy)

        onStartTimeChanged()
    }

    func setEndDayDate(_ newValue: Date) {
        let newDay = time.startOfDay(newValue)
        guard !Calendar.current.isDate(newDay, inSameDayAs: form.endDayDate) else { return }

        var copy = form
        copy.endDayDate = newDay
        setFormIfChanged(copy)

        onEndDayChanged(triggerFeedback: true)
    }

    func setEndTime(_ newValue: Date) {
        guard newValue != form.endTime else { return }
        var copy = form
        copy.endTime = newValue
        setFormIfChanged(copy)

        onEndTimeChanged()
    }

    func setIsAllDay(_ newValue: Bool) {
        guard newValue != form.isAllDay else { return }
        var copy = form
        copy.isAllDay = newValue
        setFormIfChanged(copy)
    }

    func setRepeatRule(_ newValue: RepeatRule) {
        guard newValue != form.repeatRule else { return }
        var copy = form
        copy.repeatRule = newValue
        setFormIfChanged(copy)

        recalcRepeatConflictAndPublishIfNeeded()
    }

    func setRepeatIntervalDays(_ newValue: Int) {
        let safe = max(1, newValue)
        guard safe != form.repeatIntervalDays else { return }
        var copy = form
        copy.repeatIntervalDays = safe
        setFormIfChanged(copy)

        recalcRepeatConflictAndPublishIfNeeded()
    }

    // MARK: - Time pipeline
    func onStartDayChanged() {
        let synced = time.syncTimesToSelectedDay(
            newStartDay: form.dayDate,
            startTime: form.startTime,
            endDayDate: form.endDayDate,
            endTime: form.endTime
        )

        let validated = time.validateAndFix(
            dayDate: synced.dayDate,
            endDayDate: synced.endDayDate,
            startTime: synced.startTime,
            endTime: synced.endTime
        )

        apply(validated)
    }

    func onStartTimeChanged() {
        let alignedStart = time.alignStartTimeToSelectedDay(dayDate: form.dayDate, startTime: form.startTime)

        let validated = time.validateAndFix(
            dayDate: form.dayDate,
            endDayDate: form.endDayDate,
            startTime: alignedStart,
            endTime: form.endTime
        )

        apply(validated)
    }

    func onEndDayChanged(triggerFeedback: Bool) {
        let clamped = time.clampEndDayDateIfNeeded(
            dayDate: form.dayDate,
            endDayDate: form.endDayDate,
            startTime: form.startTime,
            endTime: form.endTime
        )

        let alignedEnd = time.alignEndTimeToEndDay(endDayDate: clamped.endDayDate, endTime: clamped.endTime)

        let validated = time.validateAndFix(
            dayDate: clamped.dayDate,
            endDayDate: clamped.endDayDate,
            startTime: clamped.startTime,
            endTime: alignedEnd
        )

        apply(validated)
    }

    func onEndTimeChanged() {
        let alignedEnd = time.alignEndTimeToEndDay(endDayDate: form.endDayDate, endTime: form.endTime)

        let validated = time.validateAndFix(
            dayDate: form.dayDate,
            endDayDate: form.endDayDate,
            startTime: form.startTime,
            endTime: alignedEnd
        )

        apply(validated)
    }

    // MARK: - Category
    func ensureCategoryIsValid(available: [String]) {
        let fixed = category.ensureCategoryIsValid(current: form.categoryTitle, available: available)
        guard fixed != form.categoryTitle else { return }

        var copy = form
        copy.categoryTitle = fixed
        setFormIfChanged(copy)
    }

    // MARK: - Loading
    func loadExistingTask() async {
        guard let taskId else { return }

        isBusy = true
        defer { isBusy = false }

        do {
            guard let existing = try taskRepository.fetch(by: taskId) else {
                alert = .init(title: "Task not found", message: "This task no longer exists.")
                return
            }

            var next = form
            next.title = existing.title
            next.notes = existing.notes ?? ""

            next.dayDate = time.startOfDay(existing.dayDate)
            next.startTime = existing.startTime
            next.endTime = existing.endTime
            next.endDayDate = time.startOfDay(existing.endTime)

            next.isAllDay = existing.isAllDay

            next.repeatRule = existing.repeatRule
            next.repeatIntervalDays = existing.repeatIntervalDays ?? 2
            next.color = existing.color
            next.categoryTitle = existing.categoryTitle ?? CategorySystem.uncategorizedTitle

            next.photoThumbData = existing.photoThumbData

            next.reminderEnabled = existing.reminderEnabled
            next.reminderOffsetMinutes = ReminderPreset.normalizeOffsetMinutes(existing.reminderOffsetMinutes)
            next.reminderAllDayTimeMinutes = existing.reminderAllDayTimeMinutes

            setFormIfChanged(next)
            reminderGate = nil

            let validated = time.validateAndFix(
                dayDate: form.dayDate,
                endDayDate: form.endDayDate,
                startTime: form.startTime,
                endTime: form.endTime
            )
            apply(validated)

        } catch {
            alert = .init(title: "Failed to load", message: error.localizedDescription)
        }
    }

    // MARK: - Duration
    func applyDuration(minutes: Int) {
        let result = time.applyDuration(
            minutes: minutes,
            dayDate: form.dayDate,
            startTime: form.startTime
        )

        let validated = time.validateAndFix(
            dayDate: form.dayDate,
            endDayDate: result.endDayDate,
            startTime: result.startTime,
            endTime: result.endTime
        )

        apply(validated)
    }

    // MARK: - Save
    func save() throws {
        let clamped = time.clampEndDayDateIfNeeded(
            dayDate: form.dayDate,
            endDayDate: form.endDayDate,
            startTime: form.startTime,
            endTime: form.endTime
        )
        apply(clamped)

        if form.isRepeatInvalid && form.repeatRule != .none {
            throw EditorError.repeatConflict
        }

        let normalizedTitle = form.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeTitle = normalizedTitle.isEmpty ? "Untitled" : normalizedTitle

        let trimmedNotes = form.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedNotes: String? = trimmedNotes.isEmpty ? nil : trimmedNotes

        let trimmedCategory = form.categoryTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedCategory = trimmedCategory.isEmpty ? "Work" : trimmedCategory

        let normalizedTimes = time.normalizeForSave(
            dayDate: form.dayDate,
            endDayDate: form.endDayDate,
            startTime: form.startTime,
            endTime: form.endTime
        )

        let finalTimes = time.ensureNextDayIfSameDayEndBeforeOrEqualStart(
            dayDate: form.dayDate,
            start: normalizedTimes.start,
            endDayDate: form.endDayDate,
            end: normalizedTimes.end
        )

        let intervalOrNil: Int? = (form.repeatRule == .everyNDays) ? max(1, form.repeatIntervalDays) : nil

        let reminderEnabled = form.reminderEnabled
        let reminderOffset = ReminderPreset.normalizeOffsetMinutes(form.reminderOffsetMinutes)
        let reminderAllDayTime = form.reminderAllDayTimeMinutes

        if let taskId {
            guard let existing = try taskRepository.fetch(by: taskId) else {
                throw EditorError.taskNotFound
            }

            existing.title = safeTitle
            existing.notes = normalizedNotes
            existing.dayDate = time.startOfDay(form.dayDate)
            existing.startTime = finalTimes.start
            existing.endTime = finalTimes.end

            existing.isAllDay = form.isAllDay

            existing.repeatRule = form.repeatRule
            existing.repeatIntervalDays = intervalOrNil
            existing.normalizeRepeatFields()

            existing.color = form.color
            existing.categoryTitle = normalizedCategory
            existing.photoThumbData = form.photoThumbData

            existing.reminderEnabled = reminderEnabled
            existing.reminderOffsetMinutes = reminderOffset
            existing.reminderAllDayTimeMinutes = reminderAllDayTime

            try taskRepository.save()
        } else {
            let new = TaskEntity(
                title: safeTitle,
                notes: normalizedNotes,
                dayDate: time.startOfDay(form.dayDate),
                startTime: finalTimes.start,
                endTime: finalTimes.end,
                isAllDay: form.isAllDay,
                repeatRule: form.repeatRule,
                repeatIntervalDays: intervalOrNil,
                status: .todo,
                color: form.color,
                categoryTitle: normalizedCategory,
                reminderEnabled: reminderEnabled,
                reminderOffsetMinutes: reminderOffset,
                reminderAllDayTimeMinutes: reminderAllDayTime
            )
            new.photoThumbData = form.photoThumbData
            new.normalizeRepeatFields()
            try taskRepository.add(new)
        }
    }

    // MARK: - Apply
    private func apply(_ result: TaskEditorTimeCoordinator.Result) {
        var copy = form
        copy.dayDate = result.dayDate
        copy.endDayDate = result.endDayDate
        copy.startTime = result.startTime
        copy.endTime = result.endTime
        copy.timeValidationMessage = result.message

        let (isInvalid, message) = computeRepeatConflict(
            dayDate: copy.dayDate,
            endDayDate: copy.endDayDate,
            startTime: copy.startTime,
            endTime: copy.endTime,
            repeatRule: copy.repeatRule,
            repeatIntervalDays: copy.repeatIntervalDays
        )
        copy.isRepeatInvalid = isInvalid
        copy.repeatValidationMessage = message

        setFormIfChanged(copy)
    }

    private func recalcRepeatConflictAndPublishIfNeeded() {
        let (isInvalid, message) = computeRepeatConflict(
            dayDate: form.dayDate,
            endDayDate: form.endDayDate,
            startTime: form.startTime,
            endTime: form.endTime,
            repeatRule: form.repeatRule,
            repeatIntervalDays: form.repeatIntervalDays
        )

        guard isInvalid != form.isRepeatInvalid || message != form.repeatValidationMessage else { return }

        var copy = form
        copy.isRepeatInvalid = isInvalid
        copy.repeatValidationMessage = message
        setFormIfChanged(copy)
    }

    private func computeRepeatConflict(
        dayDate: Date,
        endDayDate: Date,
        startTime: Date,
        endTime: Date,
        repeatRule: RepeatRule,
        repeatIntervalDays: Int
    ) -> (Bool, String?) {
        guard repeatRule != .none else { return (false, nil) }

        let conflict = time.isRepeatConflict(
            dayDate: dayDate,
            endDayDate: endDayDate,
            startTime: startTime,
            endTime: endTime,
            repeatRule: repeatRule,
            repeatIntervalDays: repeatIntervalDays,
            weekStartsOnMonday: weekStartsOnMonday
        )

        if conflict {
            return (true, "Repeat unavailable: task overlaps the next occurrence.")
        } else {
            return (false, nil)
        }
    }

    private func setFormIfChanged(_ newValue: FormState) {
        guard newValue != form else { return }
        form = newValue
    }

    // MARK: - Types
    struct FormState: Equatable {
        var title: String
        var notes: String

        var dayDate: Date
        var endDayDate: Date
        var startTime: Date
        var endTime: Date

        var isAllDay: Bool

        var repeatRule: RepeatRule
        var repeatIntervalDays: Int

        var color: TaskColor
        var categoryTitle: String

        var photoThumbData: Data?

        // Reminder
        var reminderEnabled: Bool
        var reminderOffsetMinutes: Int
        var reminderAllDayTimeMinutes: Int?

        var timeValidationMessage: String?

        var isRepeatInvalid: Bool
        var repeatValidationMessage: String?
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
}

