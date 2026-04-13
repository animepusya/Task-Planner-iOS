//
//  CalendarSyncService.swift
//  Task Planner
//
//  Created by Руслан Меланин on 01.03.2026.
//

import Foundation
import EventKit
import SwiftData

@MainActor
final class CalendarSyncService {

    enum SyncError: LocalizedError {
        case accessDenied
        case fullAccessRequired
        case restricted
        case calendarCreateFailed
        case calendarNotFound
        case eventSaveFailed
        case eventRemoveFailed

        var errorDescription: String? {
            switch self {
            case .accessDenied:
                return String(localized: "Calendar access is denied. Allow it in Settings > Privacy > Calendars.")
            case .fullAccessRequired:
                return String(localized: "Full Calendar access is required to sync tasks and show Apple Calendar events. Allow it in Settings.")
            case .restricted:
                return String(localized: "Calendar access is restricted by the system.")
            case .calendarCreateFailed:
                return String(localized: "Couldn't create the Task Planner calendar.")
            case .calendarNotFound:
                return String(localized: "The Task Planner calendar couldn't be found.")
            case .eventSaveFailed:
                return String(localized: "Couldn't save the event to Calendar.")
            case .eventRemoveFailed:
                return String(localized: "Couldn't remove the event from Calendar.")
            }
        }
    }

    private let eventStore = EKEventStore()
    private let calendarTitle = "Task Planner"
    private let eventMarker = "[Task Planner]"

    private let preferencesRepository: PreferencesRepository
    private let modelContext: ModelContext

    init(preferencesRepository: PreferencesRepository, modelContext: ModelContext) {
        self.preferencesRepository = preferencesRepository
        self.modelContext = modelContext
    }

    // MARK: - Permission

    var authorizationStatus: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }

    // Export sync reads and deletes previously created events, so full access is required.
    func requestAccessIfNeeded(canPrompt: Bool = false) async throws {
        switch authorizationStatus {
        case .authorized, .fullAccess:
            return
        case .writeOnly:
            guard canPrompt else { throw SyncError.fullAccessRequired }
            let granted = try await eventStore.requestFullAccessToEvents()
            guard granted, isFullAccessGranted else {
                throw SyncError.fullAccessRequired
            }
        case .notDetermined:
            guard canPrompt else { throw SyncError.fullAccessRequired }
            let granted = try await eventStore.requestFullAccessToEvents()
            if !granted { throw SyncError.accessDenied }
        case .denied:
            throw SyncError.accessDenied
        case .restricted:
            throw SyncError.restricted
        @unknown default:
            throw SyncError.accessDenied
        }
    }

    // MARK: - Calendar

    func ensureTaskPlannerCalendarExists(canPrompt: Bool = false) async throws -> EKCalendar {
        try await requestAccessIfNeeded(canPrompt: canPrompt)

        let prefs = try preferencesRepository.getOrCreate()

        // 1) If we have identifier saved — try find
        if let id = prefs.taskPlannerCalendarIdentifier,
           let cal = eventStore.calendar(withIdentifier: id) {
            return cal
        }

        // 2) Search by title
        if let found = eventStore.calendars(for: .event).first(where: { $0.title == calendarTitle }) {
            prefs.taskPlannerCalendarIdentifier = found.calendarIdentifier
            try preferencesRepository.save()
            return found
        }

        // 3) Create new calendar
        let newCal = EKCalendar(for: .event, eventStore: eventStore)
        newCal.title = calendarTitle

        // choose a reasonable source (iCloud if possible, else local)
        let sources = eventStore.sources
        if let icloud = sources.first(where: { $0.sourceType == .calDAV && $0.title.lowercased().contains("icloud") }) {
            newCal.source = icloud
        } else if let local = sources.first(where: { $0.sourceType == .local }) {
            newCal.source = local
        } else if let fallback = eventStore.defaultCalendarForNewEvents?.source {
            newCal.source = fallback
        } else {
            throw SyncError.calendarCreateFailed
        }

        do {
            try eventStore.saveCalendar(newCal, commit: true)
            prefs.taskPlannerCalendarIdentifier = newCal.calendarIdentifier
            try preferencesRepository.save()
            return newCal
        } catch {
            throw SyncError.calendarCreateFailed
        }
    }

    // MARK: - Export (one-way)

    /// Export all tasks (simple & robust). Updates task.appleEventIdentifier if needed.
    func exportAllTasks(_ tasks: [TaskEntity], canPrompt: Bool = false) async throws {
        let prefs = try preferencesRepository.getOrCreate()
        guard prefs.showTasksInAppleCalendar else { return }

        let taskPlannerCalendar = try await ensureTaskPlannerCalendarExists(canPrompt: canPrompt)

        var didChangeAnyIdentifier = false

        for task in tasks {
            let updatedId = try upsertEvent(for: task, in: taskPlannerCalendar)
            if task.appleEventIdentifier != updatedId {
                task.appleEventIdentifier = updatedId
                didChangeAnyIdentifier = true
            }
        }

        // Save SwiftData if we updated any identifiers
        if didChangeAnyIdentifier, modelContext.hasChanges {
            try modelContext.save()
        }
    }

    func deleteExportedEventIfNeeded(for task: TaskEntity, canPrompt: Bool = false) async throws {
        let prefs = try preferencesRepository.getOrCreate()
        guard prefs.showTasksInAppleCalendar else { return }
        guard let id = task.appleEventIdentifier else { return }

        try await requestAccessIfNeeded(canPrompt: canPrompt)

        guard let event = eventStore.event(withIdentifier: id) else { return }
        do {
            try eventStore.remove(event, span: .futureEvents, commit: true)
        } catch {
            throw SyncError.eventRemoveFailed
        }
    }

    @discardableResult
    func removeAllExportedEvents(
        tasks: [TaskEntity] = [],
        canPrompt: Bool = false
    ) async throws -> Int {
        try await requestAccessIfNeeded(canPrompt: canPrompt)

        var removedKeys: Set<String> = []
        var removedCount = 0

        for task in tasks {
            guard let id = task.appleEventIdentifier,
                  let event = eventStore.event(withIdentifier: id) else { continue }

            let removalKey = eventRemovalKey(for: event)
            guard removedKeys.insert(removalKey).inserted else { continue }

            do {
                try eventStore.remove(event, span: .futureEvents, commit: false)
                removedCount += 1
            } catch {
                throw SyncError.eventRemoveFailed
            }
        }

        if let cal = try findTaskPlannerCalendarIfExists() {
            let start = Calendar.current.date(byAdding: .year, value: -10, to: .now) ?? .distantPast
            let end = Calendar.current.date(byAdding: .year, value: 10, to: .now) ?? .distantFuture

            let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: [cal])
            let events = eventStore.events(matching: predicate)

            for event in events where isManagedTaskPlannerEvent(event) {
                let removalKey = eventRemovalKey(for: event)
                guard removedKeys.insert(removalKey).inserted else { continue }

                do {
                    try eventStore.remove(event, span: .futureEvents, commit: false)
                    removedCount += 1
                } catch {
                    throw SyncError.eventRemoveFailed
                }
            }
        }

        guard removedCount > 0 else { return 0 }

        do {
            try eventStore.commit()
            return removedCount
        } catch {
            throw SyncError.eventRemoveFailed
        }
    }

    // MARK: - Import (read-only)

    /// Fetch Apple Calendar events for range (read-only, not persisted).
    /// By default excludes our own "Task Planner" calendar to avoid duplicates with tasks.
    func fetchReadOnlyEvents(
        start: Date,
        end: Date,
        excludeTaskPlannerCalendar: Bool = true,
        canPrompt: Bool = false
    ) async throws -> [ExternalCalendarEvent] {
        let prefs = try preferencesRepository.getOrCreate()
        guard prefs.showAppleCalendarEventsInPlanner else { return [] }

        try await requestAccessIfNeeded(canPrompt: canPrompt)

        var calendars = eventStore.calendars(for: .event)

        if excludeTaskPlannerCalendar,
           let id = prefs.taskPlannerCalendarIdentifier,
           let tp = eventStore.calendar(withIdentifier: id) {
            calendars.removeAll { $0.calendarIdentifier == tp.calendarIdentifier }
        } else if excludeTaskPlannerCalendar {
            calendars.removeAll { $0.title == calendarTitle }
        }

        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: calendars)
        let events = eventStore.events(matching: predicate)

        // Basic filtering: ignore cancelled / empty titles if needed (optional)
        return events.map { ExternalCalendarEvent(event: $0) }
            .sorted { $0.startDate < $1.startDate }
    }

    // MARK: - Internals

    private func upsertEvent(for task: TaskEntity, in calendar: EKCalendar) throws -> String {
        let event: EKEvent
        if let id = task.appleEventIdentifier,
           let existing = eventStore.event(withIdentifier: id) {
            event = existing
        } else {
            event = EKEvent(eventStore: eventStore)
            event.calendar = calendar
        }

        apply(task: task, to: event, calendar: calendar)

        do {
            try eventStore.save(event, span: .futureEvents, commit: true)
            guard let id = event.eventIdentifier else { throw SyncError.eventSaveFailed }
            return id
        } catch {
            throw SyncError.eventSaveFailed
        }
    }

    private func apply(task: TaskEntity, to event: EKEvent, calendar: EKCalendar) {
        event.calendar = calendar
        event.title = task.title

        let notesPart = task.notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let notesPart, !notesPart.isEmpty {
            event.notes = "\(eventMarker)\n\(notesPart)"
        } else {
            event.notes = eventMarker
        }

        if task.isAllDay {
            let dayStart = Calendar.current.startOfDay(for: task.dayDate)
            event.isAllDay = true
            event.startDate = dayStart
            event.endDate = Calendar.current.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(86400)
        } else {
            event.isAllDay = false
            // In your app startTime/endTime are real Dates already — use them directly.
            event.startDate = task.startTime
            event.endDate = task.endTime
        }

        let prefs = try? preferencesRepository.getOrCreate()
        let weekStartsOnMonday = prefs?.weekStartsOnMonday ?? true
        event.recurrenceRules = makeRecurrenceRules(for: task, weekStartsOnMonday: weekStartsOnMonday)
    }

    private var isFullAccessGranted: Bool {
        switch authorizationStatus {
        case .authorized, .fullAccess:
            return true
        case .writeOnly, .notDetermined, .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    private func findTaskPlannerCalendarIfExists() throws -> EKCalendar? {
        let prefs = try preferencesRepository.getOrCreate()

        if let id = prefs.taskPlannerCalendarIdentifier,
           let cal = eventStore.calendar(withIdentifier: id) {
            return cal
        }

        if let found = eventStore.calendars(for: .event).first(where: { $0.title == calendarTitle }) {
            prefs.taskPlannerCalendarIdentifier = found.calendarIdentifier
            try preferencesRepository.save()
            return found
        }

        return nil
    }

    private func isManagedTaskPlannerEvent(_ event: EKEvent) -> Bool {
        guard let notes = event.notes?.trimmingCharacters(in: .whitespacesAndNewlines),
              notes.isEmpty == false else {
            return false
        }

        return notes.contains(eventMarker)
    }

    private func eventRemovalKey(for event: EKEvent) -> String {
        event.calendarItemIdentifier
    }

    private func makeRecurrenceRules(for task: TaskEntity, weekStartsOnMonday: Bool) -> [EKRecurrenceRule]? {
        let rule = task.repeatRule
        switch rule {
        case .none:
            return nil

        case .daily:
            return [EKRecurrenceRule(
                recurrenceWith: .daily,
                interval: 1,
                end: nil
            )]

        case .weekly:
            return [EKRecurrenceRule(
                recurrenceWith: .weekly,
                interval: 1,
                end: nil
            )]

        case .monthly:
            return [EKRecurrenceRule(
                recurrenceWith: .monthly,
                interval: 1,
                end: nil
            )]

        case .everyNDays:
            let n = max(1, task.repeatIntervalDays ?? 1)
            return [EKRecurrenceRule(
                recurrenceWith: .daily,
                interval: n,
                end: nil
            )]

        case .weekdays:
            let days: [EKRecurrenceDayOfWeek] = weekStartsOnMonday
            ? [.init(.monday), .init(.tuesday), .init(.wednesday), .init(.thursday), .init(.friday)]
            : [.init(.sunday), .init(.monday), .init(.tuesday), .init(.wednesday), .init(.thursday)]

            return [EKRecurrenceRule(
                recurrenceWith: .weekly,
                interval: 1,
                daysOfTheWeek: days,
                daysOfTheMonth: nil,
                monthsOfTheYear: nil,
                weeksOfTheYear: nil,
                daysOfTheYear: nil,
                setPositions: nil,
                end: nil
            )]

        case .weekends:
            let days: [EKRecurrenceDayOfWeek] = weekStartsOnMonday
            ? [.init(.saturday), .init(.sunday)]
            : [.init(.friday), .init(.saturday)]

            return [EKRecurrenceRule(
                recurrenceWith: .weekly,
                interval: 1,
                daysOfTheWeek: days,
                daysOfTheMonth: nil,
                monthsOfTheYear: nil,
                weeksOfTheYear: nil,
                daysOfTheYear: nil,
                setPositions: nil,
                end: nil
            )]
        }
    }
}
