//
//  StatisticsViewModel.swift
//  Task Planner
//
//  Created by Руслан Меланин on 09.02.2026.
//

import Foundation
import SwiftData
import Combine

@MainActor
final class StatisticsViewModel: ObservableObject {
    private let taskRepository: TaskRepository
    private let preferencesRepository: PreferencesRepository
    private let onOpenSettings: () -> Void

    @Published var range: StatisticsRange = .month {
        didSet { refresh() }
    }

    @Published var anchorDate: Date = Calendar.current.startOfDay(for: .now) {
        didSet { refresh() }
    }

    @Published var breakdown: StatisticsBreakdown = .category

    // Output
    @Published private(set) var displayedTitle: String = Calendar.current.startOfDay(for: .now).monthTitle()
    @Published private(set) var totalMinutes: Int = 0
    @Published private(set) var categoryStats: [CategoryStat] = []
    @Published private(set) var taskStats: [TaskStat] = []
    @Published private(set) var weekStartsOnMonday: Bool = true

    init(
        taskRepository: TaskRepository,
        preferencesRepository: PreferencesRepository,
        onOpenSettings: @escaping () -> Void
    ) {
        self.taskRepository = taskRepository
        self.preferencesRepository = preferencesRepository
        self.onOpenSettings = onOpenSettings
        loadPreferences()
        refresh()
    }

    private func loadPreferences() {
        do {
            let prefs = try preferencesRepository.getOrCreate()
            weekStartsOnMonday = prefs.weekStartsOnMonday
        } catch {
            weekStartsOnMonday = true
        }
    }

    func reloadPreferencesAndRefresh() {
        loadPreferences()
        refresh()
    }

    func openSettings() { onOpenSettings() }

    // MARK: - Navigation

    func goToPrevious() {
        let cal = TaskOccurrence.calendar(weekStartsOnMonday: weekStartsOnMonday)
        switch range {
        case .day:
            anchorDate = cal.date(byAdding: .day, value: -1, to: anchorDate) ?? anchorDate
        case .week:
            anchorDate = cal.date(byAdding: .day, value: -7, to: anchorDate) ?? anchorDate
        case .month:
            anchorDate = anchorDate.addingMonths(-1)
        case .year:
            anchorDate = cal.date(byAdding: .year, value: -1, to: anchorDate) ?? anchorDate
        }
    }

    func goToNext() {
        let cal = TaskOccurrence.calendar(weekStartsOnMonday: weekStartsOnMonday)
        switch range {
        case .day:
            anchorDate = cal.date(byAdding: .day, value: 1, to: anchorDate) ?? anchorDate
        case .week:
            anchorDate = cal.date(byAdding: .day, value: 7, to: anchorDate) ?? anchorDate
        case .month:
            anchorDate = anchorDate.addingMonths(1)
        case .year:
            anchorDate = cal.date(byAdding: .year, value: 1, to: anchorDate) ?? anchorDate
        }
    }

    func refresh() {
        displayedTitle = makeDisplayedTitle()
        computeStats()
    }

    func percent(for stat: CategoryStat) -> Double {
        percent(forMinutes: stat.minutes)
    }

    func percent(for stat: TaskStat) -> Double {
        percent(forMinutes: stat.minutes)
    }

    private func percent(forMinutes minutes: Int) -> Double {
        guard totalMinutes > 0 else { return 0 }
        return Double(minutes) / Double(totalMinutes)
    }

    // MARK: - Computation (series-consistent)

    private func computeStats() {
        do {
            let allTasks = try taskRepository.fetchAll()
            let cal = TaskOccurrence.calendar(weekStartsOnMonday: weekStartsOnMonday)
            let (start, end) = dateRange(using: cal)

            let candidates = allTasks.filter { task in
                if task.repeatRule == .none {
                    return task.dayDate <= end && task.endTime >= start
                } else {
                    return task.dayDate <= end
                }
            }

            var perCategory: [String: (totalMinutes: Int, colorMinutes: [String: Int])] = [:]
            var perTask: [String: (title: String, minutes: Int, colorRaw: String)] = [:]
            var total = 0

            for day in enumerateDays(from: start, to: end, calendar: cal) {
                let occs = TaskDaySegment.occurrences(
                    for: day,
                    from: candidates,
                    weekStartsOnMonday: weekStartsOnMonday
                )

                for occ in occs {
                    let minutes = minutes(for: occ)
                    guard minutes > 0 else { continue }

                    total += minutes

                    let categoryName = normalizedCategoryTitle(occ.categoryTitle)
                    let colorRaw = occ.color.rawValue

                    if var existing = perCategory[categoryName] {
                        existing.totalMinutes += minutes
                        existing.colorMinutes[colorRaw, default: 0] += minutes
                        perCategory[categoryName] = existing
                    } else {
                        perCategory[categoryName] = (
                            totalMinutes: minutes,
                            colorMinutes: [colorRaw: minutes]
                        )
                    }

                    let taskID = String(describing: occ.task.persistentModelID)
                    let rawTitle = occ.title.trimmingCharacters(in: .whitespacesAndNewlines)
                    let displayTitle = rawTitle.isEmpty ? "Untitled" : rawTitle

                    if var existingTask = perTask[taskID] {
                        existingTask.minutes += minutes
                        existingTask.title = displayTitle
                        existingTask.colorRaw = colorRaw
                        perTask[taskID] = existingTask
                    } else {
                        perTask[taskID] = (
                            title: displayTitle,
                            minutes: minutes,
                            colorRaw: colorRaw
                        )
                    }
                }
            }

            totalMinutes = total

            categoryStats = perCategory
                .map { (categoryName, payload) in
                    let dominantColorRaw = payload.colorMinutes.max(by: { $0.value < $1.value })?.key ?? ""

                    return CategoryStat(
                        name: categoryName,
                        minutes: payload.totalMinutes,
                        colorRaw: dominantColorRaw
                    )
                }
                .sorted { $0.minutes > $1.minutes }

            taskStats = makeTopTasks(from: perTask)

        } catch {
            totalMinutes = 0
            categoryStats = []
            taskStats = []
            assertionFailure("Statistics compute failed: \(error)")
        }
    }

    private func minutes(for occurrence: DayOccurrence) -> Int {
        let delta = occurrence.displayEnd.timeIntervalSince(occurrence.displayStart)
        guard delta > 0 else { return 0 }
        return Int((delta / 60.0).rounded(.toNearestOrAwayFromZero))
    }

    private func makeTopTasks(from perTask: [String: (title: String, minutes: Int, colorRaw: String)]) -> [TaskStat] {
        let sorted = perTask
            .map { TaskStat(id: $0.key, title: $0.value.title, minutes: $0.value.minutes, colorRaw: $0.value.colorRaw) }
            .sorted { $0.minutes > $1.minutes }

        let topLimit = 10
        guard sorted.count > topLimit else { return sorted }

        let top = Array(sorted.prefix(topLimit))
        let rest = sorted.dropFirst(topLimit)
        let otherMinutes = rest.reduce(0) { $0 + $1.minutes }

        if otherMinutes <= 0 { return top }

        let other = TaskStat(id: "other", title: "Other", minutes: otherMinutes, colorRaw: "")
        return top + [other]
    }

    private func enumerateDays(from start: Date, to end: Date, calendar: Calendar) -> [Date] {
        let s = calendar.startOfDay(for: start)
        let e = calendar.startOfDay(for: end)
        guard s <= e else { return [] }

        var result: [Date] = []
        var cursor = s
        while cursor <= e {
            result.append(cursor)
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? cursor.addingTimeInterval(86400)
        }
        return result
    }

    // MARK: - Date range + title

    private func dateRange(using cal: Calendar) -> (Date, Date) {
        switch range {
        case .day:
            let day = cal.startOfDay(for: anchorDate)
            return (day, day)

        case .week:
            let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: anchorDate))
                ?? cal.startOfDay(for: anchorDate)
            let weekEnd = cal.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
            return (cal.startOfDay(for: weekStart), cal.startOfDay(for: weekEnd))

        case .month:
            let start = cal.startOfMonth(for: anchorDate)
            let end = cal.endOfMonth(for: anchorDate)
            return (cal.startOfDay(for: start), cal.startOfDay(for: end))

        case .year:
            let comps = cal.dateComponents([.year], from: anchorDate)
            let start = cal.date(from: comps) ?? cal.startOfDay(for: anchorDate)
            let end = cal.date(byAdding: DateComponents(year: 1, day: -1), to: start) ?? start
            return (cal.startOfDay(for: start), cal.startOfDay(for: end))
        }
    }

    private func makeDisplayedTitle() -> String {
        let cal = TaskOccurrence.calendar(weekStartsOnMonday: weekStartsOnMonday)
        switch range {
        case .day:
            return anchorDate.dayTitle(using: cal)
        case .week:
            let (start, end) = dateRange(using: cal)
            let f = DateFormatter()
            f.calendar = cal
            f.dateFormat = "d MMM"
            return "\(f.string(from: start)) – \(f.string(from: end))"
        case .month:
            return anchorDate.monthTitle(using: cal)
        case .year:
            let f = DateFormatter()
            f.calendar = cal
            f.dateFormat = "yyyy"
            return f.string(from: anchorDate)
        }
    }

    private func normalizedCategoryTitle(_ raw: String?) -> String {
        let trimmed = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Work" : trimmed
    }
}
