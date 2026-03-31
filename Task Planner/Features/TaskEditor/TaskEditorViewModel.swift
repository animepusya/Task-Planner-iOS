//
//  TaskEditorViewModel.swift
//  Task Planner
//
//  Created by Руслан Меланин on 09.02.2026.
//

import Combine
import Foundation
import SwiftData
import SwiftUI

@MainActor
final class TaskEditorViewModel {

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

    private var didBootstrap = false
    private var weekStartsOnMonday = true
    private var defaultAllDayTimeMinutes: Int = 9 * 60
    private var availableCategories: [String] = [CategorySystem.workTitle]
    private var form: FormState

    let chrome: ChromeState
    let visibility: VisibilityState
    let alertState: AlertState

    let titleSection: TitleSectionState
    let descriptionSection: DescriptionSectionState
    let dateTimeSection: DateTimeSectionState
    let reminderSection: ReminderSectionState
    let repeatSection: RepeatSectionState
    let colorSection: ColorSectionState
    let photoSection: PhotoSectionState

    var isEditing: Bool { taskId != nil }

    private var isBaseRecurringIdentityMode: Bool {
        editMode == .baseRecurringIdentity
    }

    private var reminderGate: ReminderGate? = nil {
        didSet { publishReminderState() }
    }

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
            categoryTitle: CategorySystem.workTitle,
            photoThumbData: nil,
            reminderEnabled: false,
            reminderOffsetMinutes: ReminderPreset.default.minutes,
            reminderAllDayTimeMinutes: nil,
            timeValidationMessage: nil,
            isTimeRangeInvalid: false,
            isRepeatInvalid: false,
            repeatValidationMessage: nil
        )

        self.chrome = ChromeState(editMode: editMode, isEditing: taskId != nil)
        self.visibility = VisibilityState(editMode: editMode)
        self.alertState = AlertState()

        self.titleSection = TitleSectionState()
        self.descriptionSection = DescriptionSectionState()
        self.dateTimeSection = DateTimeSectionState()
        self.reminderSection = ReminderSectionState()
        self.repeatSection = RepeatSectionState()
        self.colorSection = ColorSectionState()
        self.photoSection = PhotoSectionState()

        wireSectionCallbacks()
        publishAllState()

        if taskId != nil {
            Task { [weak self] in
                await self?.loadExistingTask()
            }
        } else {
            let validated = time.normalizeAndValidate(
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

    var alert: TaskEditorAlert? {
        get { alertState.alert }
        set { alertState.alert = newValue }
    }

    var isBusy: Bool {
        get { chrome.isBusy }
        set { chrome.setBusy(newValue) }
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
                message: String(localized: "Turn on app notifications to use reminders."),
                action: .openNotificationsCenter
            )
        } else if reminderGate?.action == .openNotificationsCenter {
            reminderGate = nil
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

            if prefs.defaultReminderOffsetMinutes != normalizedDefaultOffset {
                prefs.defaultReminderOffsetMinutes = normalizedDefaultOffset
                try? preferencesRepository.save()
            }

            form.reminderOffsetMinutes = taskId == nil
                ? normalizedDefaultOffset
                : ReminderPreset.normalizeOffsetMinutes(form.reminderOffsetMinutes)
        } catch {
            weekStartsOnMonday = true
            defaultAllDayTimeMinutes = 9 * 60
        }

        ensureCategoryIsValid(available: availableCategories)
        publishReminderState()

        let synced = time.syncTimesToSelectedDay(
            newStartDay: form.dayDate,
            startTime: form.startTime,
            endDayDate: form.endDayDate,
            endTime: form.endTime
        )

        let validated = time.normalizeAndValidate(
            dayDate: synced.dayDate,
            endDayDate: synced.endDayDate,
            startTime: synced.startTime,
            endTime: synced.endTime
        )

        apply(validated)
    }

    func ensureCategoryIsValid(available: [String]) {
        availableCategories = available

        let fixed = category.ensureCategoryIsValid(current: form.categoryTitle, available: available)
        if fixed != form.categoryTitle {
            form.categoryTitle = fixed
        }

        publishTitleState()
    }

    func setDayDate(_ newValue: Date) {
        let newDay = time.startOfDay(newValue)
        guard !Calendar.current.isDate(newDay, inSameDayAs: form.dayDate) else { return }

        form.dayDate = newDay
        onStartDayChanged()
    }

    func setStartTime(_ newValue: Date) {
        guard newValue != form.startTime else { return }
        onStartTimeChanged(to: newValue)
    }

    func setEndDayDate(_ newValue: Date) {
        let newDay = time.startOfDay(newValue)
        guard !Calendar.current.isDate(newDay, inSameDayAs: form.endDayDate) else { return }

        form.endDayDate = newDay
        onEndDayChanged(triggerFeedback: true)
    }

    func setEndTime(_ newValue: Date) {
        guard newValue != form.endTime else { return }
        onEndTimeChanged(to: newValue)
    }

    func setIsAllDay(_ newValue: Bool) {
        guard newValue != form.isAllDay else { return }
        form.isAllDay = newValue
        publishDateTimeState()
    }

    func setRepeatRule(_ newValue: RepeatRule) {
        guard newValue != form.repeatRule else { return }
        form.repeatRule = newValue
        recalcRepeatConflictAndPublishIfNeeded()
    }

    func setRepeatIntervalDays(_ newValue: Int) {
        let safe = max(1, newValue)
        guard safe != form.repeatIntervalDays else { return }
        form.repeatIntervalDays = safe
        recalcRepeatConflictAndPublishIfNeeded()
    }

    func onStartDayChanged() {
        let synced = time.syncTimesToSelectedDay(
            newStartDay: form.dayDate,
            startTime: form.startTime,
            endDayDate: form.endDayDate,
            endTime: form.endTime
        )

        let validated = time.normalizeAndValidate(
            dayDate: synced.dayDate,
            endDayDate: synced.endDayDate,
            startTime: synced.startTime,
            endTime: synced.endTime
        )

        apply(validated)
    }

    func onStartTimeChanged() {
        onStartTimeChanged(to: form.startTime)
    }

    private func onStartTimeChanged(to newValue: Date) {
        let result = time.moveStartKeepingDuration(
            dayDate: form.dayDate,
            oldStartTime: form.startTime,
            oldEndDayDate: form.endDayDate,
            oldEndTime: form.endTime,
            newStartTime: newValue
        )

        let validated = time.normalizeAndValidate(
            dayDate: form.dayDate,
            endDayDate: result.endDayDate,
            startTime: result.startTime,
            endTime: result.endTime
        )

        apply(validated)
    }

    func onEndDayChanged(triggerFeedback: Bool) {
        let alignedEnd = time.alignEndTimeToEndDay(endDayDate: form.endDayDate, endTime: form.endTime)

        let validated = time.normalizeAndValidate(
            dayDate: form.dayDate,
            endDayDate: form.endDayDate,
            startTime: form.startTime,
            endTime: alignedEnd
        )

        apply(validated)
    }

    func onEndTimeChanged() {
        onEndTimeChanged(to: form.endTime)
    }

    private func onEndTimeChanged(to newValue: Date) {
        let alignedEnd = time.alignEndTimeToEndDay(endDayDate: form.endDayDate, endTime: newValue)

        let validated = time.normalizeAndValidate(
            dayDate: form.dayDate,
            endDayDate: form.endDayDate,
            startTime: form.startTime,
            endTime: alignedEnd
        )

        apply(validated)
    }

    func loadExistingTask() async {
        guard let taskId else { return }

        chrome.setBusy(true)
        defer { chrome.setBusy(false) }

        do {
            do {
                let prefs = try preferencesRepository.getOrCreate()
                weekStartsOnMonday = prefs.weekStartsOnMonday
            } catch {
                weekStartsOnMonday = true
            }

            guard let existing = try taskRepository.fetch(by: taskId) else {
                alertState.alert = .init(
                    title: String(localized: "Task not found"),
                    message: String(localized: "This task no longer exists.")
                )
                return
            }

            let isEditingRepeatingTask = existing.repeatRule != .none
            chrome.setRepeatingTaskEditing(isEditingRepeatingTask)

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
                visibility.setEditingRepeatingOccurrence(!isBaseRecurringIdentityMode)

                let tpl = TaskSeriesEngine.template(for: existing, startDay: occurrenceStartDay ?? ownerDay, calendar: .current)
                    ?? TaskSeriesEngine.templateFromTask(existing, dayStart: ownerDay, calendar: .current)

                form.title = tpl.title
                form.notes = tpl.notes ?? ""
                form.dayDate = occurrenceStartDay ?? ownerDay

                let endDay = Calendar.current.date(byAdding: .day, value: max(0, tpl.endDayOffset), to: form.dayDate) ?? form.dayDate
                form.endDayDate = endDay

                form.startTime = TimeMinutes.date(on: form.dayDate, minutes: tpl.startMinutes, calendar: .current)
                form.endTime = TimeMinutes.date(on: endDay, minutes: tpl.endMinutes, calendar: .current)

                form.isAllDay = tpl.isAllDay
                form.repeatRule = tpl.repeatRule
                form.repeatIntervalDays = tpl.repeatIntervalDays ?? 2
                form.color = TaskColor(rawValue: tpl.colorRaw) ?? existing.color
                form.categoryTitle = tpl.categoryTitle ?? (existing.categoryTitle ?? CategorySystem.uncategorizedTitle)
                form.photoThumbData = tpl.photoThumbData
                form.reminderEnabled = tpl.reminderEnabled
                form.reminderOffsetMinutes = ReminderPreset.normalizeOffsetMinutes(tpl.reminderOffsetMinutes)
                form.reminderAllDayTimeMinutes = tpl.reminderAllDayTimeMinutes

                reminderGate = nil
                publishAllState()

                let validated = time.normalizeAndValidate(
                    dayDate: form.dayDate,
                    endDayDate: form.endDayDate,
                    startTime: form.startTime,
                    endTime: form.endTime
                )
                apply(validated)
                return
            }

            occurrenceStartDay = nil
            visibility.setEditingRepeatingOccurrence(false)

            form.title = existing.title
            form.notes = existing.notes ?? ""
            form.dayDate = time.startOfDay(existing.dayDate)
            form.startTime = existing.startTime
            form.endTime = existing.endTime
            form.endDayDate = time.startOfDay(existing.endTime)
            form.isAllDay = existing.isAllDay
            form.repeatRule = existing.repeatRule
            form.repeatIntervalDays = existing.repeatIntervalDays ?? 2
            form.color = existing.color
            form.categoryTitle = existing.categoryTitle ?? CategorySystem.uncategorizedTitle
            form.photoThumbData = existing.photoThumbData
            form.reminderEnabled = existing.reminderEnabled
            form.reminderOffsetMinutes = ReminderPreset.normalizeOffsetMinutes(existing.reminderOffsetMinutes)
            form.reminderAllDayTimeMinutes = existing.reminderAllDayTimeMinutes

            reminderGate = nil
            publishAllState()

            let validated = time.normalizeAndValidate(
                dayDate: form.dayDate,
                endDayDate: form.endDayDate,
                startTime: form.startTime,
                endTime: form.endTime
            )
            apply(validated)

        } catch {
            alertState.alert = .init(
                title: String(localized: "Couldn't load"),
                message: error.localizedDescription
            )
        }
    }

    func applyDuration(minutes: Int) {
        let result = time.applyDuration(
            minutes: minutes,
            dayDate: form.dayDate,
            startTime: form.startTime
        )

        let validated = time.normalizeAndValidate(
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

        if chrome.showSaveScopeMenu {
            try saveWithScope(.allFutureDays)
        } else {
            try saveInternalDirect()
        }
    }

    func saveWithScope(_ scope: TaskSeriesService.Scope) throws {
        guard let taskId else {
            throw EditorError.taskNotFound
        }

        let validated = time.normalizeAndValidate(
            dayDate: form.dayDate,
            endDayDate: form.endDayDate,
            startTime: form.startTime,
            endTime: form.endTime
        )
        apply(validated)

        if form.isTimeRangeInvalid {
            throw EditorError.invalidTimeRange
        }

        if form.isRepeatInvalid && form.repeatRule != .none {
            throw EditorError.repeatConflict
        }

        let cal = Calendar.current
        let originalOccurrenceDay = cal.startOfDay(for: occurrenceStartDay ?? form.dayDate)
        let editedStartDay = cal.startOfDay(for: form.dayDate)

        let normalizedTitle = form.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeTitle = normalizedTitle.isEmpty ? "Untitled" : normalizedTitle

        let trimmedNotes = form.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedNotes: String? = trimmedNotes.isEmpty ? nil : trimmedNotes

        let trimmedCategory = form.categoryTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedCategory = trimmedCategory.isEmpty ? CategorySystem.workTitle : trimmedCategory

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
            occurrenceStartDay: originalOccurrenceDay,
            scope: scope,
            changes: .init(
                startDay: editedStartDay,
                template: tpl
            )
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
        template.categoryTitle = trimmedCategory.isEmpty ? CategorySystem.workTitle : trimmedCategory

        template.repeatRuleRaw = form.repeatRule.rawValue
        template.repeatIntervalDays = (form.repeatRule == .everyNDays) ? max(1, form.repeatIntervalDays) : nil
        template.colorRaw = form.color.rawValue

        try seriesService.applyEdit(
            taskId: taskId,
            occurrenceStartDay: ownerDay,
            scope: .allFutureDays,
            changes: .init(
                startDay: ownerDay,
                template: template
            )
        )
    }

    private func saveInternalDirect() throws {
        let validated = time.normalizeAndValidate(
            dayDate: form.dayDate,
            endDayDate: form.endDayDate,
            startTime: form.startTime,
            endTime: form.endTime
        )
        apply(validated)

        if form.isTimeRangeInvalid {
            throw EditorError.invalidTimeRange
        }

        if form.isRepeatInvalid && form.repeatRule != .none {
            throw EditorError.repeatConflict
        }

        let normalizedTitle = form.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeTitle = normalizedTitle.isEmpty ? "Untitled" : normalizedTitle

        let trimmedNotes = form.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedNotes: String? = trimmedNotes.isEmpty ? nil : trimmedNotes

        let trimmedCategory = form.categoryTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedCategory = trimmedCategory.isEmpty ? CategorySystem.workTitle : trimmedCategory

        let normalizedTimes = time.normalizeForSave(
            dayDate: form.dayDate,
            endDayDate: form.endDayDate,
            startTime: form.startTime,
            endTime: form.endTime
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
            existing.startTime = normalizedTimes.start
            existing.endTime = normalizedTimes.end

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
                startTime: normalizedTimes.start,
                endTime: normalizedTimes.end,
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

    private func wireSectionCallbacks() {
        titleSection.onTitleChange = { [weak self] in
            self?.updateTitle($0)
        }
        titleSection.onCategoryChange = { [weak self] in
            self?.updateCategoryTitle($0)
        }

        descriptionSection.onNotesChange = { [weak self] in
            self?.updateNotes($0)
        }

        dateTimeSection.onDayDateChange = { [weak self] in
            self?.setDayDate($0)
        }
        dateTimeSection.onEndDayDateChange = { [weak self] in
            self?.setEndDayDate($0)
        }
        dateTimeSection.onStartTimeChange = { [weak self] in
            self?.setStartTime($0)
        }
        dateTimeSection.onEndTimeChange = { [weak self] in
            self?.setEndTime($0)
        }
        dateTimeSection.onIsAllDayChange = { [weak self] in
            self?.setIsAllDay($0)
        }

        reminderSection.onReminderEnabledChange = { [weak self] newValue in
            guard let self else { return }
            Task { await self.setReminderEnabledAttempt(newValue) }
        }
        reminderSection.onReminderOffsetChange = { [weak self] in
            self?.updateReminderOffsetMinutes($0)
        }
        reminderSection.onReminderAllDayTimeChange = { [weak self] in
            self?.updateReminderAllDayTimeMinutes($0)
        }

        repeatSection.onRepeatRuleChange = { [weak self] in
            self?.setRepeatRule($0)
        }
        repeatSection.onRepeatIntervalDaysChange = { [weak self] in
            self?.setRepeatIntervalDays($0)
        }

        colorSection.onColorChange = { [weak self] in
            self?.updateColor($0)
        }
        photoSection.onThumbDataChange = { [weak self] in
            self?.updatePhotoThumbData($0)
        }
    }

    private func updateTitle(_ newValue: String) {
        guard newValue != form.title else { return }
        form.title = newValue
    }

    private func updateCategoryTitle(_ newValue: String) {
        guard newValue != form.categoryTitle else { return }
        form.categoryTitle = newValue
    }

    private func updateNotes(_ newValue: String) {
        guard newValue != form.notes else { return }
        form.notes = newValue
    }

    private func updateReminderOffsetMinutes(_ newValue: Int) {
        let normalized = ReminderPreset.normalizeOffsetMinutes(newValue)
        guard normalized != form.reminderOffsetMinutes else { return }

        form.reminderOffsetMinutes = normalized
        publishReminderState()
    }

    private func updateReminderAllDayTimeMinutes(_ newValue: Int?) {
        guard newValue != form.reminderAllDayTimeMinutes else { return }
        form.reminderAllDayTimeMinutes = newValue
        publishReminderState()
    }

    private func updateColor(_ newValue: TaskColor) {
        guard newValue != form.color else { return }
        form.color = newValue
    }

    private func updatePhotoThumbData(_ newValue: Data?) {
        guard newValue != form.photoThumbData else { return }
        form.photoThumbData = newValue
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
                message: String(localized: "Turn on app notifications to use reminders."),
                action: .openNotificationsCenter
            )
            setReminderEnabledSilently(false)
            return
        }

        guard prefs.notificationsEnabled else {
            reminderGate = ReminderGate(
                message: String(localized: "Turn on app notifications to use reminders."),
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
                    message: String(localized: "Allow notifications in Settings to use reminders."),
                    action: .openSystemSettings
                )
                setReminderEnabledSilently(false)
            }

        case .denied:
            reminderGate = ReminderGate(
                message: String(localized: "Allow notifications in Settings to use reminders."),
                action: .openSystemSettings
            )
            setReminderEnabledSilently(false)
        }
    }

    private func setReminderEnabledSilently(_ value: Bool) {
        guard value != form.reminderEnabled else {
            publishReminderState()
            return
        }

        form.reminderEnabled = value
        publishReminderState()
    }

    private func apply(_ result: TaskEditorTimeCoordinator.Result) {
        form.dayDate = result.dayDate
        form.endDayDate = result.endDayDate
        form.startTime = result.startTime
        form.endTime = result.endTime
        form.isTimeRangeInvalid = result.isInvalidRange
        form.timeValidationMessage = result.message

        let (isInvalid, message) = computeRepeatConflict(
            dayDate: form.dayDate,
            endDayDate: form.endDayDate,
            startTime: form.startTime,
            endTime: form.endTime,
            repeatRule: form.repeatRule,
            repeatIntervalDays: form.repeatIntervalDays
        )
        form.isRepeatInvalid = isInvalid
        form.repeatValidationMessage = message

        publishDateTimeState()
        publishRepeatState()
        chrome.updateValidation(
            timeRangeInvalid: form.isTimeRangeInvalid,
            repeatInvalid: form.isRepeatInvalid
        )
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

        guard isInvalid != form.isRepeatInvalid || message != form.repeatValidationMessage else {
            publishRepeatState()
            return
        }

        form.isRepeatInvalid = isInvalid
        form.repeatValidationMessage = message

        publishRepeatState()
        chrome.updateValidation(
            timeRangeInvalid: form.isTimeRangeInvalid,
            repeatInvalid: form.isRepeatInvalid
        )
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
            return (true, String(localized: "Repeat isn't available because the task overlaps the next occurrence."))
        } else {
            return (false, nil)
        }
    }

    private func publishAllState() {
        publishTitleState()
        publishDescriptionState()
        publishDateTimeState()
        publishReminderState()
        publishRepeatState()
        colorSection.render(color: form.color)
        photoSection.render(thumbData: form.photoThumbData)
        chrome.updateValidation(
            timeRangeInvalid: form.isTimeRangeInvalid,
            repeatInvalid: form.isRepeatInvalid
        )
    }

    private func publishTitleState() {
        titleSection.render(
            title: form.title,
            categoryTitle: form.categoryTitle,
            availableCategories: availableCategories
        )
    }

    private func publishDescriptionState() {
        descriptionSection.render(notes: form.notes)
    }

    private func publishDateTimeState() {
        dateTimeSection.render(
            dayDate: form.dayDate,
            endDayDate: form.endDayDate,
            startTime: form.startTime,
            endTime: form.endTime,
            isAllDay: form.isAllDay,
            isInvalid: form.isTimeRangeInvalid,
            timeValidationMessage: form.timeValidationMessage
        )
    }

    private func publishReminderState() {
        reminderSection.render(
            reminderEnabled: form.reminderEnabled,
            reminderOffsetMinutes: form.reminderOffsetMinutes,
            reminderAllDayTimeMinutes: form.reminderAllDayTimeMinutes,
            defaultAllDayTimeMinutes: defaultAllDayTimeMinutes,
            gate: reminderGate
        )
    }

    private func publishRepeatState() {
        repeatSection.render(
            repeatRule: form.repeatRule,
            repeatIntervalDays: form.repeatIntervalDays,
            isInvalid: form.isRepeatInvalid,
            validationMessage: form.repeatValidationMessage
        )
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
        var isTimeRangeInvalid: Bool

        var isRepeatInvalid: Bool
        var repeatValidationMessage: String?
    }

    enum EditorError: LocalizedError {
        case taskNotFound
        case invalidTimeRange
        case repeatConflict
        case repeatingTasksMustUseSeriesSave

        var errorDescription: String? {
            switch self {
            case .taskNotFound:
                return String(localized: "The task couldn't be found. It may have been deleted.")
            case .invalidTimeRange:
                return String(localized: "End date & time must be later than start date & time.")
            case .repeatConflict:
                return String(localized: "Repeat isn't available because the task overlaps the next occurrence.")
            case .repeatingTasksMustUseSeriesSave:
                return String(localized: "Repeating tasks need to be saved as a series.")
            }
        }
    }
}

extension TaskEditorViewModel {
    @MainActor
    final class ChromeState: ObservableObject {
        let navigationTitle: String

        @Published private(set) var isBusy = false
        @Published private(set) var canSave = true
        @Published private(set) var showSaveScopeMenu = false

        private let editMode: TaskEditorMode
        private let isEditing: Bool

        private var isEditingRepeatingTask = false
        private var isTimeRangeInvalid = false
        private var isRepeatInvalid = false

        init(editMode: TaskEditorMode, isEditing: Bool) {
            self.editMode = editMode
            self.isEditing = isEditing
            self.navigationTitle = editMode == .baseRecurringIdentity
                ? String(localized: "Edit Recurring Task")
                : (isEditing ? String(localized: "Edit Task") : String(localized: "Create Task"))
            refresh()
        }

        func setBusy(_ value: Bool) {
            guard value != isBusy else { return }
            isBusy = value
            refresh()
        }

        func setRepeatingTaskEditing(_ value: Bool) {
            guard value != isEditingRepeatingTask else { return }
            isEditingRepeatingTask = value
            refresh()
        }

        func updateValidation(timeRangeInvalid: Bool, repeatInvalid: Bool) {
            let needsUpdate = timeRangeInvalid != isTimeRangeInvalid || repeatInvalid != isRepeatInvalid
            guard needsUpdate else { return }

            isTimeRangeInvalid = timeRangeInvalid
            isRepeatInvalid = repeatInvalid
            refresh()
        }

        private func refresh() {
            let nextCanSave = !isBusy && !isTimeRangeInvalid && !isRepeatInvalid
            if nextCanSave != canSave {
                canSave = nextCanSave
            }

            let nextShowSaveScopeMenu = editMode == .standard && isEditing && isEditingRepeatingTask && nextCanSave
            if nextShowSaveScopeMenu != showSaveScopeMenu {
                showSaveScopeMenu = nextShowSaveScopeMenu
            }
        }
    }

    @MainActor
    final class VisibilityState: ObservableObject {
        struct Content: Equatable {
            let showsNameSection: Bool
            let showsTitleAndCategory: Bool
            let showsNotesEditor: Bool
            let showsDateTimeSection: Bool
            let showsReminderSection: Bool
            let showsColorSection: Bool
            let showsRepeatSection: Bool
            let showsPhotoSection: Bool
        }

        @Published private(set) var content: Content

        private let editMode: TaskEditorMode
        private var isEditingRepeatingOccurrence = false

        init(editMode: TaskEditorMode) {
            self.editMode = editMode
            self.content = Self.makeContent(
                editMode: editMode,
                isEditingRepeatingOccurrence: false
            )
        }

        func setEditingRepeatingOccurrence(_ value: Bool) {
            guard value != isEditingRepeatingOccurrence else { return }
            isEditingRepeatingOccurrence = value
            content = Self.makeContent(
                editMode: editMode,
                isEditingRepeatingOccurrence: value
            )
        }

        private static func makeContent(
            editMode: TaskEditorMode,
            isEditingRepeatingOccurrence: Bool
        ) -> Content {
            let isBaseRecurringIdentityMode = editMode == .baseRecurringIdentity

            return Content(
                showsNameSection: true,
                showsTitleAndCategory: !isEditingRepeatingOccurrence || isBaseRecurringIdentityMode,
                showsNotesEditor: !isBaseRecurringIdentityMode,
                showsDateTimeSection: !isBaseRecurringIdentityMode,
                showsReminderSection: !isBaseRecurringIdentityMode,
                showsColorSection: !isEditingRepeatingOccurrence || isBaseRecurringIdentityMode,
                showsRepeatSection: !isEditingRepeatingOccurrence || isBaseRecurringIdentityMode,
                showsPhotoSection: !isBaseRecurringIdentityMode
            )
        }
    }

    @MainActor
    final class AlertState: ObservableObject {
        @Published var alert: TaskEditorAlert?
    }

    @MainActor
    final class TitleSectionState: ObservableObject {
        @Published private(set) var title = ""
        @Published private(set) var categoryTitle = CategorySystem.workTitle
        @Published private(set) var availableCategories: [String] = []

        var onTitleChange: ((String) -> Void)?
        var onCategoryChange: ((String) -> Void)?

        var titleBinding: Binding<String> {
            Binding(
                get: { self.title },
                set: { [weak self] in self?.setTitleFromUI($0) }
            )
        }

        var categoryTitleBinding: Binding<String> {
            Binding(
                get: { self.categoryTitle },
                set: { [weak self] in self?.setCategoryTitleFromUI($0) }
            )
        }

        func render(title: String, categoryTitle: String, availableCategories: [String]) {
            if self.title != title {
                self.title = title
            }
            if self.categoryTitle != categoryTitle {
                self.categoryTitle = categoryTitle
            }
            if self.availableCategories != availableCategories {
                self.availableCategories = availableCategories
            }
        }

        private func setTitleFromUI(_ newValue: String) {
            guard newValue != title else { return }
            title = newValue
            onTitleChange?(newValue)
        }

        private func setCategoryTitleFromUI(_ newValue: String) {
            guard newValue != categoryTitle else { return }
            categoryTitle = newValue
            onCategoryChange?(newValue)
        }
    }

    @MainActor
    final class DescriptionSectionState: ObservableObject {
        @Published private(set) var notes = ""
        @Published private(set) var hasNotes = false

        var onNotesChange: ((String) -> Void)?

        var notesBinding: Binding<String> {
            Binding(
                get: { self.notes },
                set: { [weak self] in self?.setNotesFromUI($0) }
            )
        }

        func render(notes: String) {
            if self.notes != notes {
                self.notes = notes
            }

            let nextHasNotes = Self.containsMeaningfulText(notes)
            if nextHasNotes != hasNotes {
                hasNotes = nextHasNotes
            }
        }

        private func setNotesFromUI(_ newValue: String) {
            guard newValue != notes else { return }
            notes = newValue
            hasNotes = Self.containsMeaningfulText(newValue)
            onNotesChange?(newValue)
        }

        private static func containsMeaningfulText(_ value: String) -> Bool {
            !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    @MainActor
    final class DateTimeSectionState: ObservableObject {
        @Published private(set) var dayDate: Date = .now
        @Published private(set) var endDayDate: Date = .now
        @Published private(set) var startTime: Date = .now
        @Published private(set) var endTime: Date = .now
        @Published private(set) var isAllDay = false
        @Published private(set) var isInvalid = false
        @Published private(set) var timeValidationMessage: String?

        var onDayDateChange: ((Date) -> Void)?
        var onEndDayDateChange: ((Date) -> Void)?
        var onStartTimeChange: ((Date) -> Void)?
        var onEndTimeChange: ((Date) -> Void)?
        var onIsAllDayChange: ((Bool) -> Void)?

        var dayDateBinding: Binding<Date> {
            Binding(
                get: { self.dayDate },
                set: { [weak self] in self?.onDayDateChange?($0) }
            )
        }

        var endDayDateBinding: Binding<Date> {
            Binding(
                get: { self.endDayDate },
                set: { [weak self] in self?.onEndDayDateChange?($0) }
            )
        }

        var startTimeBinding: Binding<Date> {
            Binding(
                get: { self.startTime },
                set: { [weak self] in self?.onStartTimeChange?($0) }
            )
        }

        var endTimeBinding: Binding<Date> {
            Binding(
                get: { self.endTime },
                set: { [weak self] in self?.onEndTimeChange?($0) }
            )
        }

        var isAllDayBinding: Binding<Bool> {
            Binding(
                get: { self.isAllDay },
                set: { [weak self] in self?.onIsAllDayChange?($0) }
            )
        }

        func render(
            dayDate: Date,
            endDayDate: Date,
            startTime: Date,
            endTime: Date,
            isAllDay: Bool,
            isInvalid: Bool,
            timeValidationMessage: String?
        ) {
            if self.dayDate != dayDate {
                self.dayDate = dayDate
            }
            if self.endDayDate != endDayDate {
                self.endDayDate = endDayDate
            }
            if self.startTime != startTime {
                self.startTime = startTime
            }
            if self.endTime != endTime {
                self.endTime = endTime
            }
            if self.isAllDay != isAllDay {
                self.isAllDay = isAllDay
            }
            if self.isInvalid != isInvalid {
                self.isInvalid = isInvalid
            }
            if self.timeValidationMessage != timeValidationMessage {
                self.timeValidationMessage = timeValidationMessage
            }
        }
    }

    @MainActor
    final class ReminderSectionState: ObservableObject {
        @Published private(set) var reminderEnabled = false
        @Published private(set) var reminderOffsetMinutes = ReminderPreset.default.minutes
        @Published private(set) var reminderAllDayTimeMinutes: Int?
        @Published private(set) var defaultAllDayTimeMinutes = 9 * 60
        @Published private(set) var gate: ReminderGate?

        var onReminderEnabledChange: ((Bool) -> Void)?
        var onReminderOffsetChange: ((Int) -> Void)?
        var onReminderAllDayTimeChange: ((Int?) -> Void)?

        var reminderEnabledBinding: Binding<Bool> {
            Binding(
                get: { self.reminderEnabled },
                set: { [weak self] in self?.onReminderEnabledChange?($0) }
            )
        }

        var reminderOffsetMinutesBinding: Binding<Int> {
            Binding(
                get: { self.reminderOffsetMinutes },
                set: { [weak self] in self?.setReminderOffsetFromUI($0) }
            )
        }

        var reminderAllDayTimeMinutesBinding: Binding<Int?> {
            Binding(
                get: { self.reminderAllDayTimeMinutes },
                set: { [weak self] in self?.setReminderAllDayTimeFromUI($0) }
            )
        }

        func render(
            reminderEnabled: Bool,
            reminderOffsetMinutes: Int,
            reminderAllDayTimeMinutes: Int?,
            defaultAllDayTimeMinutes: Int,
            gate: ReminderGate?
        ) {
            if self.reminderEnabled != reminderEnabled {
                self.reminderEnabled = reminderEnabled
            }
            if self.reminderOffsetMinutes != reminderOffsetMinutes {
                self.reminderOffsetMinutes = reminderOffsetMinutes
            }
            if self.reminderAllDayTimeMinutes != reminderAllDayTimeMinutes {
                self.reminderAllDayTimeMinutes = reminderAllDayTimeMinutes
            }
            if self.defaultAllDayTimeMinutes != defaultAllDayTimeMinutes {
                self.defaultAllDayTimeMinutes = defaultAllDayTimeMinutes
            }
            if self.gate != gate {
                self.gate = gate
            }
        }

        private func setReminderOffsetFromUI(_ newValue: Int) {
            let normalized = ReminderPreset.normalizeOffsetMinutes(newValue)
            guard normalized != reminderOffsetMinutes else { return }
            reminderOffsetMinutes = normalized
            onReminderOffsetChange?(normalized)
        }

        private func setReminderAllDayTimeFromUI(_ newValue: Int?) {
            guard newValue != reminderAllDayTimeMinutes else { return }
            reminderAllDayTimeMinutes = newValue
            onReminderAllDayTimeChange?(newValue)
        }
    }

    @MainActor
    final class RepeatSectionState: ObservableObject {
        @Published private(set) var repeatRule: RepeatRule = .none
        @Published private(set) var repeatIntervalDays = 2
        @Published private(set) var isInvalid = false
        @Published private(set) var validationMessage: String?

        var onRepeatRuleChange: ((RepeatRule) -> Void)?
        var onRepeatIntervalDaysChange: ((Int) -> Void)?

        var repeatRuleBinding: Binding<RepeatRule> {
            Binding(
                get: { self.repeatRule },
                set: { [weak self] in self?.onRepeatRuleChange?($0) }
            )
        }

        var repeatIntervalDaysBinding: Binding<Int> {
            Binding(
                get: { self.repeatIntervalDays },
                set: { [weak self] in self?.onRepeatIntervalDaysChange?($0) }
            )
        }

        func render(
            repeatRule: RepeatRule,
            repeatIntervalDays: Int,
            isInvalid: Bool,
            validationMessage: String?
        ) {
            if self.repeatRule != repeatRule {
                self.repeatRule = repeatRule
            }
            if self.repeatIntervalDays != repeatIntervalDays {
                self.repeatIntervalDays = repeatIntervalDays
            }
            if self.isInvalid != isInvalid {
                self.isInvalid = isInvalid
            }
            if self.validationMessage != validationMessage {
                self.validationMessage = validationMessage
            }
        }
    }

    @MainActor
    final class ColorSectionState: ObservableObject {
        @Published private(set) var color: TaskColor = .purple

        var onColorChange: ((TaskColor) -> Void)?

        var colorBinding: Binding<TaskColor> {
            Binding(
                get: { self.color },
                set: { [weak self] in self?.setColorFromUI($0) }
            )
        }

        func render(color: TaskColor) {
            guard self.color != color else { return }
            self.color = color
        }

        private func setColorFromUI(_ newValue: TaskColor) {
            guard newValue != color else { return }
            color = newValue
            onColorChange?(newValue)
        }
    }

    @MainActor
    final class PhotoSectionState: ObservableObject {
        @Published private(set) var thumbData: Data?

        var onThumbDataChange: ((Data?) -> Void)?

        var thumbDataBinding: Binding<Data?> {
            Binding(
                get: { self.thumbData },
                set: { [weak self] in self?.setThumbDataFromUI($0) }
            )
        }

        func render(thumbData: Data?) {
            guard self.thumbData != thumbData else { return }
            self.thumbData = thumbData
        }

        private func setThumbDataFromUI(_ newValue: Data?) {
            guard newValue != thumbData else { return }
            thumbData = newValue
            onThumbDataChange?(newValue)
        }
    }
}
