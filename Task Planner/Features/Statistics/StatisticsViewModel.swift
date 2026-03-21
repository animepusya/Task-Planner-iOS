//
//  StatisticsViewModel.swift
//  Task Planner
//
//  Created by Руслан Меланин on 09.02.2026.
//

import Foundation
import SwiftData
import SwiftUI
import Combine

@MainActor
final class StatisticsViewModel: ObservableObject {
    private let taskRepository: TaskRepository
    private let preferencesRepository: PreferencesRepository
    private let onOpenSettings: () -> Void

    private let computationCache = StatisticsComputationCache()

    private var taskSources: [StatisticsTaskSource] = []
    private var refreshTask: Task<StatisticsComputedResult, Never>?
    private var isUpdatingInputs = false
    private var didScheduleInitialLoad = false

    @Published var range: StatisticsRange = .month {
        didSet {
            guard isUpdatingInputs == false else { return }
            handleInputChange()
        }
    }

    @Published var anchorDate: Date = Calendar.current.startOfDay(for: .now) {
        didSet {
            guard isUpdatingInputs == false else { return }
            handleInputChange()
        }
    }

    @Published var breakdown: StatisticsBreakdown = .category
    @Published private(set) var weekStartsOnMonday: Bool = true
    @Published private(set) var snapshot: StatisticsScreenSnapshot
    
    init(
        taskRepository: TaskRepository,
        preferencesRepository: PreferencesRepository,
        onOpenSettings: @escaping () -> Void
    ) {
        self.taskRepository = taskRepository
        self.preferencesRepository = preferencesRepository
        self.onOpenSettings = onOpenSettings
        
        let initialWeekStartsOnMonday: Bool
        do {
            let prefs = try preferencesRepository.getOrCreate()
            initialWeekStartsOnMonday = prefs.weekStartsOnMonday
        } catch {
            initialWeekStartsOnMonday = true
        }
        
        self.weekStartsOnMonday = initialWeekStartsOnMonday
        
        let initialRange: StatisticsRange = .month
        let initialAnchor = StatisticsViewModel.normalizedAnchorDate(
            for: initialRange,
            anchorDate: Calendar.current.startOfDay(for: .now),
            weekStartsOnMonday: initialWeekStartsOnMonday
        )
        self.anchorDate = initialAnchor
        
        self.snapshot = .placeholder(
            displayedTitle: StatisticsViewModel.makeDisplayedTitle(
                for: initialRange,
                anchorDate: initialAnchor,
                weekStartsOnMonday: initialWeekStartsOnMonday
            )
        )
        
        self.range = initialRange
        self.breakdown = .category
    }

    func onViewAppear() {
        scheduleInitialLoadIfNeeded()
    }

    func handleModelContextDidSave() {
        reloadStoreInputsAndRefresh(force: false)
    }

    func openSettings() {
        onOpenSettings()
    }

    func goToPrevious() {
        let calendar = TaskOccurrence.calendar(weekStartsOnMonday: weekStartsOnMonday)

        switch range {
        case .day:
            anchorDate = calendar.date(byAdding: .day, value: -1, to: anchorDate) ?? anchorDate

        case .week:
            anchorDate = calendar.date(byAdding: .day, value: -7, to: anchorDate) ?? anchorDate

        case .month:
            let previous = calendar.date(byAdding: .month, value: -1, to: anchorDate) ?? anchorDate
            anchorDate = calendar.startOfMonth(for: previous)

        case .year:
            anchorDate = calendar.date(byAdding: .year, value: -1, to: anchorDate) ?? anchorDate
        }
    }

    func goToNext() {
        let calendar = TaskOccurrence.calendar(weekStartsOnMonday: weekStartsOnMonday)

        switch range {
        case .day:
            anchorDate = calendar.date(byAdding: .day, value: 1, to: anchorDate) ?? anchorDate

        case .week:
            anchorDate = calendar.date(byAdding: .day, value: 7, to: anchorDate) ?? anchorDate

        case .month:
            let next = calendar.date(byAdding: .month, value: 1, to: anchorDate) ?? anchorDate
            anchorDate = calendar.startOfMonth(for: next)

        case .year:
            anchorDate = calendar.date(byAdding: .year, value: 1, to: anchorDate) ?? anchorDate
        }
    }

    private func scheduleInitialLoadIfNeeded() {
        guard didScheduleInitialLoad == false else { return }
        didScheduleInitialLoad = true

        Task { [weak self] in
            guard let self else { return }
            self.reloadStoreInputsAndRefresh(force: true)
        }
    }

    private func handleInputChange() {
        let normalizedAnchor = Self.normalizedAnchorDate(
            for: range,
            anchorDate: anchorDate,
            weekStartsOnMonday: weekStartsOnMonday
        )

        if normalizedAnchor != anchorDate {
            isUpdatingInputs = true
            anchorDate = normalizedAnchor
            isUpdatingInputs = false
        }

        refresh()
    }

    private func reloadStoreInputsAndRefresh(force: Bool) {
        let didChange = reloadStoreInputs()
        guard force || didChange else { return }
        refresh(force: true)
    }

    private func reloadStoreInputs() -> Bool {
        let previousWeekStartsOnMonday = weekStartsOnMonday
        let previousTaskSources = taskSources

        loadPreferences()

        let normalizedAnchor = Self.normalizedAnchorDate(
            for: range,
            anchorDate: anchorDate,
            weekStartsOnMonday: weekStartsOnMonday
        )
        if normalizedAnchor != anchorDate {
            isUpdatingInputs = true
            anchorDate = normalizedAnchor
            isUpdatingInputs = false
        }

        let newTaskSources: [StatisticsTaskSource]
        do {
            newTaskSources = try taskRepository.fetchAll().map { StatisticsTaskSource(task: $0) }
        } catch {
            assertionFailure("Statistics fetch failed: \(error)")
            newTaskSources = []
        }

        let didChange = previousWeekStartsOnMonday != weekStartsOnMonday || previousTaskSources != newTaskSources
        if didChange {
            taskSources = newTaskSources
            computationCache.invalidateAll()
        }

        return didChange
    }

    private func refresh(force: Bool = false) {
        let key = StatisticsComputationKey(
            range: range,
            anchorDate: anchorDate,
            weekStartsOnMonday: weekStartsOnMonday
        )
        let displayedTitle = Self.makeDisplayedTitle(
            for: key.range,
            anchorDate: key.anchorDate,
            weekStartsOnMonday: key.weekStartsOnMonday
        )

        if force == false, let cached = computationCache.value(for: key) {
            apply(result: cached, displayedTitle: displayedTitle)
            return
        }

        refreshTask?.cancel()
        snapshot = .placeholder(displayedTitle: displayedTitle)

        let taskSources = self.taskSources
        let computeTask = Task.detached(priority: .userInitiated) {
            StatisticsComputationBuilder.build(tasks: taskSources, key: key)
        }
        refreshTask = computeTask

        Task { [weak self] in
            let result = await computeTask.value
            guard let self else { return }
            guard computeTask.isCancelled == false else { return }

            self.computationCache.insert(result, for: key)

            let currentKey = StatisticsComputationKey(
                range: self.range,
                anchorDate: self.anchorDate,
                weekStartsOnMonday: self.weekStartsOnMonday
            )
            guard currentKey == key else { return }

            self.apply(result: result, displayedTitle: displayedTitle)
        }
    }

    private func apply(result: StatisticsComputedResult, displayedTitle: String) {
        let totalMinutesText = result.totalMinutes.formattedHoursMinutes()

        snapshot = StatisticsScreenSnapshot(
            displayedTitle: displayedTitle,
            totalMinutes: result.totalMinutes,
            totalMinutesText: totalMinutesText,
            category: makeBreakdownSnapshot(
                totalMinutes: result.totalMinutes,
                rows: result.categoryStats.map {
                    StatisticsBreakdownRowSource(
                        id: $0.id,
                        name: $0.name,
                        minutes: $0.minutes,
                        colorRaw: $0.colorRaw
                    )
                }
            ),
            task: makeBreakdownSnapshot(
                totalMinutes: result.totalMinutes,
                rows: result.taskStats.map {
                    StatisticsBreakdownRowSource(
                        id: $0.id,
                        name: $0.title,
                        minutes: $0.minutes,
                        colorRaw: $0.colorRaw
                    )
                }
            )
        )
    }

    private func makeBreakdownSnapshot(
        totalMinutes: Int,
        rows: [StatisticsBreakdownRowSource]
    ) -> StatisticsBreakdownSnapshot {
        let totalMinutesText = totalMinutes.formattedHoursMinutes()
        guard totalMinutes > 0, rows.isEmpty == false else {
            return .empty(totalMinutesText: totalMinutesText)
        }

        let preparedRows = rows.map { row in
            let percent = Double(row.minutes) / Double(totalMinutes)
            let percentText = Self.percentText(percent)
            let minutesText = row.minutes.formattedHoursMinutes()

            return StatisticsTotalRowViewData(
                id: row.id,
                name: row.name,
                minutes: row.minutes,
                minutesText: minutesText,
                percentText: percentText,
                valueText: "\(minutesText) (\(percentText))",
                color: Self.color(forRawValue: row.colorRaw)
            )
        }

        let donutSlices = Self.normalizedDonutSlices(
            preparedRows.map { row in
                DonutChartSlice(
                    id: row.id,
                    fraction: Double(row.minutes),
                    color: row.color
                )
            }
        )

        let centersBySliceID = Dictionary(uniqueKeysWithValues: preparedRows.map { row in
            (
                row.id,
                StatisticsDonutCenterData(
                    title: row.name,
                    valueText: row.minutesText
                )
            )
        })

        return StatisticsBreakdownSnapshot(
            rows: preparedRows,
            donutSlices: donutSlices,
            defaultCenter: StatisticsDonutCenterData(
                title: "Total",
                valueText: totalMinutesText
            ),
            emptyMessage: "Add some tasks to see totals.",
            centersBySliceID: centersBySliceID
        )
    }

    private func loadPreferences() {
        do {
            let prefs = try preferencesRepository.getOrCreate()
            weekStartsOnMonday = prefs.weekStartsOnMonday
        } catch {
            weekStartsOnMonday = true
        }
    }

    private static func color(forRawValue rawValue: String) -> Color {
        TaskColor(rawValue: rawValue)?.uiColor ?? DS.ColorToken.textSecondary
    }

    private static func normalizedDonutSlices(_ slices: [DonutChartSlice]) -> [DonutChartSlice] {
        let total = slices.reduce(0.0) { $0 + max(0, $1.fraction) }
        guard total > 0 else { return [] }

        return slices.map { slice in
            DonutChartSlice(
                id: slice.id,
                fraction: max(0, slice.fraction) / total,
                color: slice.color
            )
        }
    }

    private static func percentText(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private static func normalizedAnchorDate(
        for range: StatisticsRange,
        anchorDate: Date,
        weekStartsOnMonday: Bool
    ) -> Date {
        let calendar = TaskOccurrence.calendar(weekStartsOnMonday: weekStartsOnMonday)

        switch range {
        case .day, .week:
            return calendar.startOfDay(for: anchorDate)

        case .month:
            return calendar.startOfMonth(for: anchorDate)

        case .year:
            let year = calendar.component(.year, from: anchorDate)
            return calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? anchorDate
        }
    }

    private static func makeDisplayedTitle(
        for range: StatisticsRange,
        anchorDate: Date,
        weekStartsOnMonday: Bool
    ) -> String {
        let calendar = TaskOccurrence.calendar(weekStartsOnMonday: weekStartsOnMonday)

        switch range {
        case .day:
            return anchorDate.dayTitle(using: calendar)

        case .week:
            let weekStart = calendar.date(
                from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: anchorDate)
            ) ?? calendar.startOfDay(for: anchorDate)
            let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart

            let formatter = DateFormatter()
            formatter.calendar = calendar
            formatter.dateFormat = "d MMM"
            return "\(formatter.string(from: weekStart)) – \(formatter.string(from: weekEnd))"

        case .month:
            return anchorDate.monthTitle(using: calendar)

        case .year:
            let formatter = DateFormatter()
            formatter.calendar = calendar
            formatter.dateFormat = "yyyy"
            return formatter.string(from: anchorDate)
        }
    }
}

private struct StatisticsBreakdownRowSource {
    let id: String
    let name: String
    let minutes: Int
    let colorRaw: String
}
