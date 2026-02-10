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
    private let onOpenSettings: () -> Void

    // Input
    @Published var range: StatisticsRange = .month {
        didSet { refresh() }
    }

    @Published var anchorDate: Date = Calendar.current.startOfDay(for: .now) {
        didSet { refresh() }
    }

    // Output
    @Published private(set) var displayedTitle: String = Calendar.current.startOfDay(for: .now).monthTitle()
    @Published private(set) var totalMinutes: Int = 0
    @Published private(set) var categoryStats: [CategoryStat] = []

    init(taskRepository: TaskRepository, onOpenSettings: @escaping () -> Void) {
        self.taskRepository = taskRepository
        self.onOpenSettings = onOpenSettings
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

    func percent(for stat: CategoryStat) -> Double {
        guard totalMinutes > 0 else { return 0 }
        return Double(stat.minutes) / Double(totalMinutes)
    }

    // MARK: - Computation (WITH repeats)

    private func computeStats() {
        do {
            let allTasks = try taskRepository.fetchAll()

            let cal = Calendar.current
            let (start, end) = dateRange(using: cal)

            // Важно: для повторяющихся задач dayDate может быть ДО start,
            // поэтому фильтруем так:
            // - none: только если dayDate ∈ [start; end]
            // - repeating: если dayDate <= end (может "проецироваться" в окно)
            let candidates = allTasks.filter { task in
                if task.repeatRule == .none {
                    return task.dayDate >= start && task.dayDate <= end
                } else {
                    return task.dayDate <= end
                }
            }

            var perCategory: [String: (minutes: Int, colorRaw: String)] = [:]
            var total = 0

            // Итерируем дни в окне и начисляем длительность за каждое виртуальное появление
            for day in enumerateDays(from: start, to: end, calendar: cal) {
                for task in candidates where occurs(task, on: day, calendar: cal) {
                    let minutes = durationMinutes(task: task)
                    guard minutes > 0 else { continue }

                    let name = normalizedCategoryTitle(task.categoryTitle)
                    let colorRaw = task.color.rawValue

                    total += minutes
                    if var existing = perCategory[name] {
                        existing.minutes += minutes
                        perCategory[name] = existing
                    } else {
                        perCategory[name] = (minutes: minutes, colorRaw: colorRaw)
                    }
                }
            }

            totalMinutes = total
            categoryStats = perCategory
                .map { CategoryStat(name: $0.key, minutes: $0.value.minutes, colorRaw: $0.value.colorRaw) }
                .sorted { $0.minutes > $1.minutes }

        } catch {
            totalMinutes = 0
            categoryStats = []
            assertionFailure("Statistics compute failed: \(error)")
        }
    }

    private func durationMinutes(task: TaskEntity) -> Int {
        // start/end НЕ optional
        let deltaSeconds = task.endTime.timeIntervalSince(task.startTime)
        let minutes = Int((deltaSeconds / 60.0).rounded()) // ✅ округляем до минуты
        return Swift.max(0, minutes)
    }

    // MARK: - Repeat logic (same semantics as Planner MVP)

    private func occurs(_ task: TaskEntity, on day: Date, calendar: Calendar) -> Bool {
        let targetDay = calendar.startOfDay(for: day)
        let baseDay = calendar.startOfDay(for: task.dayDate)

        // никогда не показываем (и не считаем) раньше даты создания/базы
        guard targetDay >= baseDay else { return false }

        switch task.repeatRule {
        case .none:
            return calendar.isDate(targetDay, inSameDayAs: baseDay)

        case .daily:
            return true

        case .weekly:
            let baseWeekday = calendar.component(.weekday, from: baseDay)
            let targetWeekday = calendar.component(.weekday, from: targetDay)
            return baseWeekday == targetWeekday

        case .monthly:
            let baseDayOfMonth = calendar.component(.day, from: baseDay)
            let targetDayOfMonth = calendar.component(.day, from: targetDay)
            return baseDayOfMonth == targetDayOfMonth
        }
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

