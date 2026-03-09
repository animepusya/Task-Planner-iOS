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

    private let taskRepository: TaskRepository
    private let preferencesRepository: PreferencesRepository
    private let notificationService: NotificationService
    private let seriesService: TaskSeriesService

    private let taskId: PersistentIdentifier?
    private let time: TaskEditorTimeCoordinator
    private let category: TaskEditorCategoryCoordinator
    private let editMode: TaskEditorMode

    private let preselectedDay: Date
    private var occurrenceStartDay: Date?

    @Published private(set) var isEditingRepeatingTask: Bool = false
    @Published private(set) var isEditingRepeatingBaseOwner: Bool = false
    @Published private(set) var isEditingRepeatingOccurrence: Bool = false

    var isBaseRecurringIdentityMode: Bool {
        editMode == .baseRecurringIdentity
    }

    var requiresScopeMenuOnSave: Bool {
        editMode == .standard && isEditing && isEditingRepeatingTask && canSave
    }

    var showsNameSection: Bool { true }
    var showsTitleAndCategory: Bool { !isEditingRepeatingOccurrence || isBaseRecurringIdentityMode }
    var showsNotesEditor: Bool { !isBaseRecurringIdentityMode }
    var showsDateTimeSection: Bool { !isBaseRecurringIdentityMode }
    var showsReminderSection: Bool { !isBaseRecurringIdentityMode }
    var showsColorSection: Bool { !isEditingRepeatingOccurrence || isBaseRecurringIdentityMode }
    var showsRepeatSection: Bool { !isEditingRepeatingOccurrence || isBaseRecurringIdentityMode }
    var showsPhotoSection: Bool { !isBaseRecurringIdentityMode }

    @Published var isBusy: Bool = false
    @Published var alert: TaskEditorAlert?

    @Published private(set) var form: FormState

    private var didBootstrap = false
    private var weekStartsOnMonday = true

    @Published private(set) var defaultAllDayTimeMinutes: Int = 9 * 60
    @Published private(set) var defaultReminderOffsetMinutes: Int = ReminderPreset.default.minutes

    @Published private(set) var reminderGate: ReminderGate?

    var isEditing: Bool { taskId != nil }
    var navigationTitle: String {
        if isBaseRecurringIdentityMode { return "Edit Recurring Task" }
        return isEditing ? "Edit Task" : "Create Task"
    }
    var canSave: Bool { !isBusy && !form.isRepeatInvalid }

    init(
        taskRepository: TaskRepository,
        preferencesRepository: PreferencesRepository,
        notificationService: NotificationService,
        seriesService: TaskSeriesService,
        taskId: PersistentIdentifier?,
        preselectedDay: Date,
        editMode: TaskEditorMode
    ) {
        self.taskRepository = taskRepository
        self.preferencesRepository = preferencesRepository
        self.notificationService = notificationService
        self.seriesService = seriesService
        self.taskId = taskId
        self.editMode = editMode

        self.time = TaskEditorTimeCoordinator(calendar: .current)
        self.category = TaskEditorCategoryCoordinator()

        let startDay = Calendar.current.startOfDay(for: preselectedDay)
        self.preselectedDay = startDay

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

    func ensureCategoryIsValid(available: [String]) {
        let fixed = category.ensureCategoryIsValid(current: form.categoryTitle, available: available)
        guard fixed != form.categoryTitle else { return }

        var copy = form
        copy.categoryTitle = fixed
        setFormIfChanged(copy)
    }

    func loadExistingTask() async {
        guard let taskId else { return }
        
        isBusy = true
        defer { isBusy = false }
        
        do {
            do {
                let prefs = try preferencesRepository.getOrCreate()
                weekStartsOnMonday = prefs.weekStartsOnMonday
            } catch {
                weekStartsOnMonday = true
            }
            
            guard let existing = try taskRepository.fetch(by: taskId) else {
                alert = .init(title: "Task not found", message: "This task no longer exists.")
                return
            }

            isEditingRepeatingTask = existing.repeatRule != .none
            isEditingRepeatingBaseOwner = false
            isEditingRepeatingOccurrence = false

            if existing.repeatRule != .none {
                TaskSeriesEngine.ensureBaseSegmentIfNeeded(for: existing, calendar: .current)

                let ownerDay = Calendar.current.startOfDay(for: existing.dayDate)

                let targetDay: Date
                if isBaseRecurringIdentityMode {
                    targetDay = ownerDay
                } else {
                    targetDay = Calendar.current.startOfDay(for: preselectedDay)
                }

                let occStart = TaskSeriesEngine
                    .occurrenceStartDayOverlapping(task: existing, day: targetDay, weekStartsOnMonday: weekStartsOnMonday)
                    ?? ownerDay

                occurrenceStartDay = isBaseRecurringIdentityMode ? ownerDay : occStart
                isEditingRepeatingBaseOwner = isBaseRecurringIdentityMode
                isEditingRepeatingOccurrence = !isBaseRecurringIdentityMode

                let tpl = TaskSeriesEngine.template(for: existing, startDay: occurrenceStartDay ?? ownerDay, calendar: .current)
                    ?? TaskSeriesEngine.templateFromTask(existing, dayStart: ownerDay, calendar: .current)

                var next = form
                next.title = tpl.title
                next.notes = tpl.notes ?? ""
                next.dayDate = occurrenceStartDay ?? ownerDay

                let endDay = Calendar.current.date(byAdding: .day, value: max(0, tpl.endDayOffset), to: next.dayDate) ?? next.dayDate
                next.endDayDate = endDay

                next.startTime = TimeMinutes.date(on: next.dayDate, minutes: tpl.startMinutes, calendar: .current)
                next.endTime = TimeMinutes.date(on: endDay, minutes: tpl.endMinutes, calendar: .current)

                next.isAllDay = tpl.isAllDay
                next.repeatRule = tpl.repeatRule
                next.repeatIntervalDays = tpl.repeatIntervalDays ?? 2

                next.color = TaskColor(rawValue: tpl.colorRaw) ?? existing.color
                next.categoryTitle = tpl.categoryTitle ?? (existing.categoryTitle ?? CategorySystem.uncategorizedTitle)
                next.photoThumbData = tpl.photoThumbData

                next.reminderEnabled = tpl.reminderEnabled
                next.reminderOffsetMinutes = ReminderPreset.normalizeOffsetMinutes(tpl.reminderOffsetMinutes)
                next.reminderAllDayTimeMinutes = tpl.reminderAllDayTimeMinutes

                setFormIfChanged(next)
                reminderGate = nil

                let validated = time.validateAndFix(
                    dayDate: form.dayDate,
                    endDayDate: form.endDayDate,
                    startTime: form.startTime,
                    endTime: form.endTime
                )
                apply(validated)
                return
            }

            occurrenceStartDay = nil

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

    func save() throws {
        try saveNormal()
    }

    func saveNormal() throws {
        if isBaseRecurringIdentityMode {
            try saveBaseRecurringIdentity()
            return
        }

        if requiresScopeMenuOnSave {
            try saveWithScope(.allFutureDays)
        } else {
            try saveInternalDirect()
        }
    }

    func saveWithScope(_ scope: TaskSeriesService.Scope) throws {
        guard let taskId else {
            throw EditorError.taskNotFound
        }

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

        let cal = Calendar.current
        let startDay = cal.startOfDay(for: occurrenceStartDay ?? form.dayDate)

        let normalizedTitle = form.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeTitle = normalizedTitle.isEmpty ? "Untitled" : normalizedTitle

        let trimmedNotes = form.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedNotes: String? = trimmedNotes.isEmpty ? nil : trimmedNotes

        let trimmedCategory = form.categoryTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedCategory = trimmedCategory.isEmpty ? "Work" : trimmedCategory

        let startMinutes = TimeMinutes.minutes(from: form.startTime, calendar: cal)
        let endMinutes = TimeMinutes.minutes(from: form.endTime, calendar: cal)

        let endOffset = max(
            0,
            cal.dateComponents(
                [.day],
                from: cal.startOfDay(for: form.dayDate),
                to: cal.startOfDay(for: form.endDayDate)
            ).day ?? 0
        )

        let intervalOrNil: Int? = (form.repeatRule == .everyNDays) ? max(1, form.repeatIntervalDays) : nil
        let reminderOffset = ReminderPreset.normalizeOffsetMinutes(form.reminderOffsetMinutes)

        let tpl = TaskSeriesTemplate(
            title: safeTitle,
            notes: normalizedNotes,
            isAllDay: form.isAllDay,
            startMinutes: startMinutes,
            endMinutes: endMinutes,
            endDayOffset: endOffset,
            repeatRuleRaw: form.repeatRule.rawValue,
            repeatIntervalDays: intervalOrNil,
            colorRaw: form.color.rawValue,
            categoryTitle: normalizedCategory,
            photoThumbData: form.photoThumbData,
            reminderEnabled: form.reminderEnabled,
            reminderOffsetMinutes: reminderOffset,
            reminderAllDayTimeMinutes: form.reminderAllDayTimeMinutes
        )

        try seriesService.applyEdit(
            taskId: taskId,
            occurrenceStartDay: startDay,
            scope: scope,
            changes: .init(template: tpl)
        )
    }

    private func saveBaseRecurringIdentity() throws {
        guard let taskId else { throw EditorError.taskNotFound }

        guard let existing = try taskRepository.fetch(by: taskId) else {
            throw EditorError.taskNotFound
        }

        guard existing.repeatRule != .none else {
            throw EditorError.repeatingTasksMustUseSeriesSave
        }

        let cal = Calendar.current
        let ownerDay = cal.startOfDay(for: existing.dayDate)
        let currentOwnerTemplate = TaskSeriesEngine.template(for: existing, startDay: ownerDay, calendar: cal)
            ?? TaskSeriesEngine.templateFromTask(existing, dayStart: ownerDay, calendar: cal)

        var template = currentOwnerTemplate

        let normalizedTitle = form.title.trimmingCharacters(in: .whitespacesAndNewlines)
        template.title = normalizedTitle.isEmpty ? "Untitled" : normalizedTitle

        let trimmedCategory = form.categoryTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        template.categoryTitle = trimmedCategory.isEmpty ? "Work" : trimmedCategory

        template.repeatRuleRaw = form.repeatRule.rawValue
        template.repeatIntervalDays = (form.repeatRule == .everyNDays) ? max(1, form.repeatIntervalDays) : nil
        template.colorRaw = form.color.rawValue

        try seriesService.applyEdit(
            taskId: taskId,
            occurrenceStartDay: ownerDay,
            scope: .allFutureDays,
            changes: .init(template: template)
        )
    }

    private func saveInternalDirect() throws {
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

            if existing.repeatRule != .none {
                throw EditorError.repeatingTasksMustUseSeriesSave
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
        case repeatingTasksMustUseSeriesSave

        var errorDescription: String? {
            switch self {
            case .taskNotFound:
                return "The task was not found. It may have been deleted."
            case .repeatConflict:
                return "Repeat unavailable: task overlaps the next occurrence."
            case .repeatingTasksMustUseSeriesSave:
                return "Repeating tasks must be saved through the series model."
            }
        }
    }
}
