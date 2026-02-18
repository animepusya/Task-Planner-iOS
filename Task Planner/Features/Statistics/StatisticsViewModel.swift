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
    
    func setWeekStartsOnMonday(_ value: Bool) {
            guard value != weekStartsOnMonday else { return }
            weekStartsOnMonday = value
            refresh()
        }

    func openSettings() { onOpenSettings() }

    // MARK: - Navigation

    func goToPrevious() {
        switch range {
        case .day:
            anchorDate = Calendar.current.date(byAdding: .day, value: -1, to: anchorDate) ?? anchorDate
        case .week:
            anchorDate = Calendar.current.date(byAdding: .day, value: -7, to: anchorDate) ?? anchorDate
        case .month:
            anchorDate = anchorDate.addingMonths(-1)
        case .year:
            anchorDate = Calendar.current.date(byAdding: .year, value: -1, to: anchorDate) ?? anchorDate
        }
    }

    func goToNext() {
        switch range {
        case .day:
            anchorDate = Calendar.current.date(byAdding: .day, value: 1, to: anchorDate) ?? anchorDate
        case .week:
            anchorDate = Calendar.current.date(byAdding: .day, value: 7, to: anchorDate) ?? anchorDate
        case .month:
            anchorDate = anchorDate.addingMonths(1)
        case .year:
            anchorDate = Calendar.current.date(byAdding: .year, value: 1, to: anchorDate) ?? anchorDate
        }
    }

    func refresh() {
        displayedTitle = makeDisplayedTitle()
        computeStats()
    }

    // Existing API (kept)
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

    // MARK: - Computation (WITH repeats)

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

            var perCategory: [String: (minutes: Int, colorRaw: String)] = [:]

            var perTask: [String: (title: String, minutes: Int, colorRaw: String)] = [:]

            var total = 0

            for day in enumerateDays(from: start, to: end, calendar: cal) {
                for task in candidates {
                    let minutes = TaskDayOverlap.minutesOnDay(
                        task: task,
                        day: day,
                        weekStartsOnMonday: weekStartsOnMonday
                    )
                    guard minutes > 0 else { continue }

                    total += minutes

                    let categoryName = normalizedCategoryTitle(task.categoryTitle)
                    let colorRaw = task.color.rawValue
                    if var existing = perCategory[categoryName] {
                        existing.minutes += minutes
                        perCategory[categoryName] = existing
                    } else {
                        perCategory[categoryName] = (minutes: minutes, colorRaw: colorRaw)
                    }

                    let taskID = String(describing: task.persistentModelID)
                    let title = task.title.trimmingCharacters(in: .whitespacesAndNewlines)
                    let displayTitle = title.isEmpty ? "Untitled" : title

                    if var existingTask = perTask[taskID] {
                        existingTask.minutes += minutes
                        perTask[taskID] = existingTask
                    } else {
                        perTask[taskID] = (title: displayTitle, minutes: minutes, colorRaw: colorRaw)
                    }
                }
            }

            totalMinutes = total

            categoryStats = perCategory
                .map { CategoryStat(name: $0.key, minutes: $0.value.minutes, colorRaw: $0.value.colorRaw) }
                .sorted { $0.minutes > $1.minutes }

            taskStats = makeTopTasks(from: perTask)

        } catch {
            totalMinutes = 0
            categoryStats = []
            taskStats = []
            assertionFailure("Statistics compute failed: \(error)")
        }
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

    // (оставил как было — если не используется, можно удалить позже)
    private func durationMinutes(task: TaskEntity) -> Int {
        let deltaSeconds = task.endTime.timeIntervalSince(task.startTime)
        let minutes = Int((deltaSeconds / 60.0).rounded())
        return Swift.max(0, minutes)
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
        let cal = Calendar.current
        switch range {
        case .day:
            return anchorDate.dayTitle()

        case .week:
            let (start, end) = dateRange(using: cal)
            let f = DateFormatter()
            f.dateFormat = "d MMM"
            return "\(f.string(from: start)) – \(f.string(from: end))"

        case .month:
            return anchorDate.monthTitle()

        case .year:
            let f = DateFormatter()
            f.dateFormat = "yyyy"
            return f.string(from: anchorDate)
        }
    }

    private func normalizedCategoryTitle(_ raw: String?) -> String {
        let trimmed = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Work" : trimmed
    }
}
