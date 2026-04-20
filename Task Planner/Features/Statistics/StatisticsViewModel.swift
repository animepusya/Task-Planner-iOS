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
    private let comparisonMode: StatisticsComparisonMode = .previousEquivalent

    private let computationCache = StatisticsComputationCache()

    private var taskSources: [StatisticsTaskSource] = []
    private var refreshTask: Task<StatisticsRefreshPayload, Never>?
    private var isUpdatingInputs = false
    private var didScheduleInitialLoad = false
    private var isViewActive = false
    private var needsStoreReloadOnActivate = false
    private var needsPreferenceReloadOnActivate = false
    private var cancellables: Set<AnyCancellable> = []

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
        preferencesRepository: PreferencesRepository
    ) {
        self.taskRepository = taskRepository
        self.preferencesRepository = preferencesRepository
        
        let initialWeekStartsOnMonday: Bool
        do {
            let prefs = try preferencesRepository.getOrCreate()
            initialWeekStartsOnMonday = prefs.weekStartsOnMonday
        } catch {
            initialWeekStartsOnMonday = true
        }
        
        self.weekStartsOnMonday = initialWeekStartsOnMonday

        let initialRange: StatisticsRange = .month
        let initialAnchor = StatisticsPeriodContextBuilder.normalizedAnchorDate(
            for: initialRange,
            anchorDate: Calendar.current.startOfDay(for: .now),
            weekStartsOnMonday: initialWeekStartsOnMonday
        )
        let initialContext = StatisticsPeriodContextBuilder.make(
            range: initialRange,
            anchorDate: initialAnchor,
            weekStartsOnMonday: initialWeekStartsOnMonday
        )
        let comparedContext = StatisticsPeriodContextBuilder.comparisonContext(
            for: initialContext,
            mode: comparisonMode
        )
        self.anchorDate = initialAnchor

        self.snapshot = .placeholder(
            currentContext: initialContext,
            comparedContext: comparedContext,
            comparisonMode: comparisonMode
        )

        self.range = initialRange
        self.breakdown = .category

        bindTaskRepositoryChanges()
    }

    func onViewAppear() {
        isViewActive = true
        scheduleInitialLoadIfNeeded()

        if needsPreferenceReloadOnActivate {
            needsPreferenceReloadOnActivate = false
            reloadPreferenceInputsAndRefresh(force: false)
        }

        if needsStoreReloadOnActivate {
            needsStoreReloadOnActivate = false
            reloadStoreInputsAndRefresh(force: false)
        }
    }

    func onViewDisappear() {
        isViewActive = false
        refreshTask?.cancel()
        refreshTask = nil
    }

    func handleModelContextDidSave() {
        guard isViewActive else {
            needsPreferenceReloadOnActivate = true
            return
        }

        reloadPreferenceInputsAndRefresh(force: false)
    }

    func goToPrevious() {
        anchorDate = StatisticsPeriodContextBuilder.shiftedAnchorDate(
            for: range,
            anchorDate: anchorDate,
            weekStartsOnMonday: weekStartsOnMonday,
            direction: .previous
        )
    }

    func goToNext() {
        anchorDate = StatisticsPeriodContextBuilder.shiftedAnchorDate(
            for: range,
            anchorDate: anchorDate,
            weekStartsOnMonday: weekStartsOnMonday,
            direction: .next
        )
    }

    private func scheduleInitialLoadIfNeeded() {
        guard didScheduleInitialLoad == false else { return }
        didScheduleInitialLoad = true

        Task { [weak self] in
            guard let self else { return }
            self.reloadStoreInputsAndRefresh(force: true)
        }
    }

    private func bindTaskRepositoryChanges() {
        taskRepository.changePublisher
            .sink { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in
                    guard self.isViewActive else {
                        self.needsStoreReloadOnActivate = true
                        return
                    }

                    self.reloadStoreInputsAndRefresh(force: false)
                }
            }
            .store(in: &cancellables)
    }

    private func handleInputChange() {
        let normalizedAnchor = StatisticsPeriodContextBuilder.normalizedAnchorDate(
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
        let previousTaskSources = taskSources

        let newTaskSources: [StatisticsTaskSource]
        do {
            newTaskSources = try taskRepository.fetchAll().map { StatisticsTaskSource(task: $0) }
        } catch {
            assertionFailure("Statistics fetch failed: \(error)")
            newTaskSources = []
        }

        let didChange = previousTaskSources != newTaskSources
        if didChange {
            taskSources = newTaskSources
            computationCache.invalidateAll()
        }

        return didChange
    }

    private func reloadPreferenceInputsAndRefresh(force: Bool) {
        let didChange = reloadPreferenceInputs()
        guard force || didChange else { return }
        computationCache.invalidateAll()
        refresh(force: true)
    }

    private func reloadPreferenceInputs() -> Bool {
        let previousWeekStartsOnMonday = weekStartsOnMonday
        let previousAnchorDate = anchorDate

        loadPreferences()

        let normalizedAnchor = StatisticsPeriodContextBuilder.normalizedAnchorDate(
            for: range,
            anchorDate: anchorDate,
            weekStartsOnMonday: weekStartsOnMonday
        )
        if normalizedAnchor != anchorDate {
            isUpdatingInputs = true
            anchorDate = normalizedAnchor
            isUpdatingInputs = false
        }

        return previousWeekStartsOnMonday != weekStartsOnMonday || previousAnchorDate != anchorDate
    }

    private func refresh(force: Bool = false) {
        let currentContext = StatisticsPeriodContextBuilder.make(
            range: range,
            anchorDate: anchorDate,
            weekStartsOnMonday: weekStartsOnMonday
        )
        let comparedContext = StatisticsPeriodContextBuilder.comparisonContext(
            for: currentContext,
            mode: comparisonMode
        )
        let currentKey = currentContext.computationKey
        let comparedKey = comparedContext.computationKey

        if
            force == false,
            let currentCached = computationCache.value(for: currentKey),
            let comparedCached = computationCache.value(for: comparedKey)
        {
            apply(
                currentResult: currentCached,
                currentContext: currentContext,
                comparedResult: comparedCached,
                comparedContext: comparedContext
            )
            return
        }

        refreshTask?.cancel()
        snapshot = .placeholder(
            currentContext: currentContext,
            comparedContext: comparedContext,
            comparisonMode: comparisonMode
        )

        let taskSources = self.taskSources
        let cachedCurrent = force ? nil : computationCache.value(for: currentKey)
        let cachedCompared = force ? nil : computationCache.value(for: comparedKey)
        let computeTask = Task.detached(priority: .userInitiated) {
            let currentResult = cachedCurrent
                ?? StatisticsComputationBuilder.build(tasks: taskSources, key: currentKey)
            let comparedResult = cachedCompared
                ?? StatisticsComputationBuilder.build(tasks: taskSources, key: comparedKey)

            return StatisticsRefreshPayload(
                currentKey: currentKey,
                currentContext: currentContext,
                currentResult: currentResult,
                comparedKey: comparedKey,
                comparedContext: comparedContext,
                comparedResult: comparedResult
            )
        }
        refreshTask = computeTask

        Task { [weak self] in
            let payload = await computeTask.value
            guard let self else { return }
            guard computeTask.isCancelled == false else { return }

            self.computationCache.insert(payload.currentResult, for: payload.currentKey)
            self.computationCache.insert(payload.comparedResult, for: payload.comparedKey)

            let currentKey = StatisticsPeriodContextBuilder.make(
                range: self.range,
                anchorDate: self.anchorDate,
                weekStartsOnMonday: self.weekStartsOnMonday
            )
            .computationKey
            guard currentKey == payload.currentKey else { return }

            self.apply(
                currentResult: payload.currentResult,
                currentContext: payload.currentContext,
                comparedResult: payload.comparedResult,
                comparedContext: payload.comparedContext
            )
        }
    }

    private func apply(
        currentResult: StatisticsComputedResult,
        currentContext: StatisticsPeriodContext,
        comparedResult: StatisticsComputedResult,
        comparedContext: StatisticsPeriodContext
    ) {
        let totalMinutesText = currentResult.totalMinutes.formattedHoursMinutes()

        snapshot = StatisticsScreenSnapshot(
            displayedTitle: currentContext.displayedTitle,
            totalMinutes: currentResult.totalMinutes,
            totalMinutesText: totalMinutesText,
            comparison: StatisticsComparisonBuilder.build(
                currentResult: currentResult,
                previousResult: comparedResult,
                currentContext: currentContext,
                comparedContext: comparedContext,
                mode: comparisonMode
            ),
            category: makeBreakdownSnapshot(
                totalMinutes: currentResult.totalMinutes,
                breakdown: .category,
                rows: currentResult.categoryStats.map {
                    StatisticsBreakdownRowSource(
                        id: $0.id,
                        name: $0.name,
                        minutes: $0.minutes,
                        colorRaw: $0.colorRaw
                    )
                }
            ),
            task: makeBreakdownSnapshot(
                totalMinutes: currentResult.totalMinutes,
                breakdown: .task,
                rows: currentResult.taskStats.map {
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
        breakdown: StatisticsBreakdown,
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
                color: StatisticsPresentationColor.color(forRawValue: row.colorRaw)
            )
        }

        let donutSlices = Self.normalizedDonutSlices(
            preparedRows.enumerated().map { index, row in
                DonutChartSlice(
                    id: Self.makeDonutSliceID(
                        breakdown: breakdown,
                        rowID: row.id
                    ),
                    renderKey: Self.makeDonutRenderKey(slot: index),
                    fraction: Double(row.minutes),
                    color: row.color
                )
            }
        )

        let centersBySliceID: [String: StatisticsDonutCenterData] = Dictionary(
            uniqueKeysWithValues: preparedRows.map { row in
                let sliceID = Self.makeDonutSliceID(
                    breakdown: breakdown,
                    rowID: row.id
                )

                return (
                    sliceID,
                    StatisticsDonutCenterData(
                        title: row.name,
                        valueText: row.minutesText
                    )
                )
            }
        )

        return StatisticsBreakdownSnapshot(
            rows: preparedRows,
            donutSlices: donutSlices,
            defaultCenter: StatisticsDonutCenterData(
                title: String(localized: "Total"),
                valueText: totalMinutesText
            ),
            emptyMessage: String(localized: "Add a few tasks to see totals."),
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

    private static func makeDonutSliceID(
        breakdown: StatisticsBreakdown,
        rowID: String
    ) -> String {
        "\(breakdown.rawValue):\(rowID)"
    }

    private static func makeDonutRenderKey(slot: Int) -> String {
        "slot:\(slot)"
    }

    private static func normalizedDonutSlices(_ slices: [DonutChartSlice]) -> [DonutChartSlice] {
        let sanitizedSlices = slices.compactMap { slice -> DonutChartSlice? in
            guard slice.fraction.isFinite, slice.fraction > 0 else { return nil }
            return slice
        }

        let total = sanitizedSlices.reduce(0.0) { $0 + $1.fraction }
        guard total.isFinite, total > 0 else { return [] }

        return sanitizedSlices.map { slice in
            DonutChartSlice(
                id: slice.id,
                renderKey: slice.renderKey,
                fraction: slice.fraction / total,
                color: slice.color
            )
        }
    }

    private static func percentText(_ value: Double) -> String {
        guard value.isFinite else { return "0%" }

        let roundedPercent = (value * 100).rounded()
        guard roundedPercent.isFinite else { return "0%" }

        return "\(Int(roundedPercent))%"
    }
}

private struct StatisticsBreakdownRowSource {
    let id: String
    let name: String
    let minutes: Int
    let colorRaw: String
}

private struct StatisticsRefreshPayload: Sendable {
    let currentKey: StatisticsComputationKey
    let currentContext: StatisticsPeriodContext
    let currentResult: StatisticsComputedResult
    let comparedKey: StatisticsComputationKey
    let comparedContext: StatisticsPeriodContext
    let comparedResult: StatisticsComputedResult
}
