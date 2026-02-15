//
//  StatisticsView.swift
//  Task Planner
//
//  Created by Руслан Меланин on 09.02.2026.
//

import SwiftUI

struct StatisticsView: View {
    @StateObject var viewModel: StatisticsViewModel

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                header
                rangePickerCard
                periodSelectorCard

                // ✅ NEW: breakdown picker card (segmented)
                breakdownPickerCard

                timeBreakdownCard
                totalHoursCard
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.top, DS.Spacing.lg)
            .padding(.bottom, 24)
        }
        .background(DS.ColorToken.appBackground.ignoresSafeArea())
        .navigationBarHidden(true)
        .onAppear { viewModel.refresh() }
    }

    private var header: some View {
        HStack(alignment: .center) {
            Text("Statistics")
                .font(DS.Typography.title)
                .foregroundColor(DS.ColorToken.textPrimary)

            Spacer()

            Button(action: viewModel.openSettings) {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(DS.ColorToken.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(Color.white)
                    .clipShape(Circle())
                    .shadow(color: DS.Shadow.soft, radius: 10, x: 0, y: 6)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Profile")
        }
    }

    private var rangePickerCard: some View {
        Picker("", selection: $viewModel.range) {
            ForEach(StatisticsRange.allCases) { r in
                Text(r.title).tag(r)
            }
        }
        .pickerStyle(.segmented)
        .dsCard(padding: DS.Spacing.md)
    }

    private var periodSelectorCard: some View {
        Group {
            if viewModel.range == .month {
                MonthSwitcherView(
                    title: viewModel.displayedTitle,
                    monthAnchor: Calendar.current.startOfMonth(for: viewModel.anchorDate),
                    onPrev: viewModel.goToPrevious,
                    onNext: viewModel.goToNext,
                    onSelectMonthAnchor: { newAnchor in
                        viewModel.anchorDate = Calendar.current.startOfMonth(for: newAnchor)
                    },
                    onToday: {
                        viewModel.anchorDate = Calendar.current.startOfMonth(for: .now)
                    },
                    todayTitle: "Current month"
                )
                .dsCard()
            } else {
                HStack {
                    Button(action: viewModel.goToPrevious) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(DS.ColorToken.textSecondary)
                            .frame(width: 34, height: 34)
                            .background(Color.white.opacity(0.9))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text(viewModel.displayedTitle)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(DS.ColorToken.textPrimary)

                    Spacer()

                    Button(action: viewModel.goToNext) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(DS.ColorToken.textSecondary)
                            .frame(width: 34, height: 34)
                            .background(Color.white.opacity(0.9))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .dsCard()
            }
        }
    }

    // ✅ NEW
    private var breakdownPickerCard: some View {
        Picker("", selection: $viewModel.breakdown) {
            ForEach(StatisticsBreakdown.allCases) { b in
                Text(b.title).tag(b)
            }
        }
        .pickerStyle(.segmented)
        .dsCard(padding: DS.Spacing.md)
    }

    // ✅ Replaces old timeByCategoryCard
    private var timeBreakdownCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(titleForBreakdown)
                .font(DS.Typography.sectionTitle)
                .foregroundColor(DS.ColorToken.textPrimary)

            HStack(alignment: .center, spacing: DS.Spacing.lg) {
                donut
                    .frame(width: 140, height: 140)

                VStack(alignment: .leading, spacing: 10) {
                    if activeCount == 0 {
                        Text("No data for this period yet.")
                            .font(DS.Typography.caption)
                            .foregroundColor(DS.ColorToken.textSecondary)
                    } else {
                        ForEach(activeLegendRows) { row in
                            LegendRow(
                                name: row.name,
                                percentText: percentString(row.percent),
                                color: row.color
                            )
                        }
                    }
                }
            }
        }
        .dsCard()
    }

    private var donut: some View {
        let slices = activeDonutSlices()

        return ZStack {
            DonutChartView(slices: normalizedSlices(slices), lineWidth: 18)
            VStack(spacing: 2) {
                Text(viewModel.totalMinutes.formattedHoursMinutes())
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(DS.ColorToken.textPrimary)
                Text("Total")
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.ColorToken.textSecondary)
            }
        }
    }

    private func activeDonutSlices() -> [DonutChartSlice] {
        switch viewModel.breakdown {
        case .category:
            return viewModel.categoryStats.map { stat in
                DonutChartSlice(
                    id: stat.id,
                    fraction: viewModel.percent(for: stat),
                    color: categoryColor(stat)
                )
            }

        case .task:
            return viewModel.taskStats.map { stat in
                DonutChartSlice(
                    id: stat.id,
                    fraction: viewModel.percent(for: stat),
                    color: taskColor(stat)
                )
            }
        }
    }

    private func normalizedSlices(_ slices: [DonutChartSlice]) -> [DonutChartSlice] {
        let sum = slices.reduce(0) { $0 + $1.fraction }
        guard sum > 0 else { return [] }
        return slices.map { DonutChartSlice(id: $0.id, fraction: $0.fraction / sum, color: $0.color) }
    }

    private var totalHoursCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack {
                Text("Total Hours")
                    .font(DS.Typography.sectionTitle)
                    .foregroundColor(DS.ColorToken.textPrimary)

                Spacer()

                Text(viewModel.totalMinutes.formattedHoursMinutes())
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(DS.ColorToken.purple)
            }

            if activeCount == 0 {
                Text("Add some tasks to see totals.")
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.ColorToken.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 10) {
                    ForEach(activeTotalRows) { row in
                        HStack {
                            Circle()
                                .fill(row.color)
                                .frame(width: 10, height: 10)

                            Text(row.name)
                                .font(DS.Typography.body)
                                .foregroundColor(DS.ColorToken.textPrimary)

                            Spacer()

                            Text(row.minutes.formattedHoursMinutes())
                                .font(DS.Typography.body)
                                .foregroundColor(DS.ColorToken.textSecondary)
                        }
                    }
                }
            }
        }
        .dsCard()
    }

    // MARK: - Active rows mapping (category/task)

    private var titleForBreakdown: String {
        switch viewModel.breakdown {
        case .category: return "Time by Category"
        case .task:     return "Time by Task"
        }
    }

    private var activeCount: Int {
        switch viewModel.breakdown {
        case .category: return viewModel.categoryStats.count
        case .task:     return viewModel.taskStats.count
        }
    }

    private struct LegendRowModel: Identifiable {
        let id: String
        let name: String
        let percent: Double
        let color: Color
    }

    private struct TotalRowModel: Identifiable {
        let id: String
        let name: String
        let minutes: Int
        let color: Color
    }

    private var activeLegendRows: [LegendRowModel] {
        switch viewModel.breakdown {
        case .category:
            return viewModel.categoryStats.map { stat in
                LegendRowModel(
                    id: stat.id,
                    name: stat.name,
                    percent: viewModel.percent(for: stat),
                    color: categoryColor(stat)
                )
            }
        case .task:
            return viewModel.taskStats.map { stat in
                LegendRowModel(
                    id: stat.id,
                    name: stat.title,
                    percent: viewModel.percent(for: stat),
                    color: taskColor(stat)
                )
            }
        }
    }

    private var activeTotalRows: [TotalRowModel] {
        switch viewModel.breakdown {
        case .category:
            return viewModel.categoryStats.map { stat in
                TotalRowModel(
                    id: stat.id,
                    name: stat.name,
                    minutes: stat.minutes,
                    color: categoryColor(stat)
                )
            }
        case .task:
            return viewModel.taskStats.map { stat in
                TotalRowModel(
                    id: stat.id,
                    name: stat.title,
                    minutes: stat.minutes,
                    color: taskColor(stat)
                )
            }
        }
    }

    // MARK: - Colors

    private func categoryColor(_ stat: CategoryStat) -> Color {
        stat.taskColor?.uiColor ?? DS.ColorToken.textSecondary
    }

    private func taskColor(_ stat: TaskStat) -> Color {
        stat.taskColor?.uiColor ?? DS.ColorToken.textSecondary
    }

    // MARK: - Formatting

    private func percentString(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }
}

private struct LegendRow: View {
    let name: String
    let percentText: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(name)
                .font(DS.Typography.body)
                .foregroundColor(DS.ColorToken.textPrimary)
                .lineLimit(1)

            Spacer()
            
            Text(percentText)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(DS.ColorToken.textSecondary)
        }
    }
}
