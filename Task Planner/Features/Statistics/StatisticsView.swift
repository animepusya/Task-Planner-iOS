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
                timeByCategoryCard
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

    private var timeByCategoryCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Time by Category")
                .font(DS.Typography.sectionTitle)
                .foregroundColor(DS.ColorToken.textPrimary)

            HStack(alignment: .center, spacing: DS.Spacing.lg) {
                donut
                    .frame(width: 140, height: 140)

                VStack(alignment: .leading, spacing: 10) {
                    if viewModel.categoryStats.isEmpty {
                        Text("No data for this period yet.")
                            .font(DS.Typography.caption)
                            .foregroundColor(DS.ColorToken.textSecondary)
                    } else {
                        ForEach(viewModel.categoryStats) { stat in
                            CategoryLegendRow(
                                name: stat.name,
                                percentText: percentString(viewModel.percent(for: stat)),
                                color: categoryColor(stat)
                            )
                        }
                    }
                }
            }
        }
        .dsCard()
    }

    private var donut: some View {
        let slices: [DonutChartSlice] = viewModel.categoryStats.map { stat in
            DonutChartSlice(
                id: stat.id,
                fraction: viewModel.percent(for: stat),
                color: categoryColor(stat)
            )
        }

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

            if viewModel.categoryStats.isEmpty {
                Text("Add some tasks to see totals.")
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.ColorToken.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 10) {
                    ForEach(viewModel.categoryStats) { stat in
                        HStack {
                            Circle()
                                .fill(categoryColor(stat))
                                .frame(width: 10, height: 10)

                            Text(stat.name)
                                .font(DS.Typography.body)
                                .foregroundColor(DS.ColorToken.textPrimary)

                            Spacer()

                            Text(stat.minutes.formattedHoursMinutes())
                                .font(DS.Typography.body)
                                .foregroundColor(DS.ColorToken.textSecondary)
                        }
                    }
                }
            }
        }
        .dsCard()
    }

    private func categoryColor(_ stat: CategoryStat) -> Color {
        stat.taskColor?.uiColor ?? DS.ColorToken.textSecondary
    }

    private func percentString(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }
}

private struct CategoryLegendRow: View {
    let name: String
    let percentText: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(name)
                .font(DS.Typography.body)
                .foregroundColor(DS.ColorToken.textPrimary)
            Spacer()
            Text(percentText)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(DS.ColorToken.textSecondary)
        }
    }
}
