//
//  StatisticsView.swift
//  Task Planner
//
//  Created by Руслан Меланин on 09.02.2026.
//

import SwiftUI

struct StatisticsView: View {
    @StateObject var viewModel: StatisticsViewModel
    @State private var isRangeSheetPresented = false
    
    var body: some View {
        ZStack {
            AppBackgroundView(
                    gradient: DS.GradientToken.pinkPurpleSoft,
                    gradientOpacity: 0.55,
                    blurRadius: 22
                )
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    header
                    periodCard
                    donutCard
                    totalCard
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.lg)
                .padding(.bottom, 24)
            }
            .background(Color.clear)
            .contentMargins(.bottom, DS.Layout.tabBarHeight + DS.Layout.tabBarBottomPadding, for: .scrollContent)
        }
        .navigationBarHidden(true)
        .onAppear { viewModel.refresh() }
        .sheet(isPresented: $isRangeSheetPresented) {
            StatisticsRangeSheet(
                range: $viewModel.range,
                anchorDate: $viewModel.anchorDate,
                onPickMonthYear: { newAnchor in
                    viewModel.anchorDate = Calendar.current.startOfMonth(for: newAnchor)
                }
            )
        }
    }

    // MARK: - Header

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

    // MARK: - Period card (like Figma)

    private var periodCard: some View {
        HStack {
            navCircle("chevron.left", action: viewModel.goToPrevious)

            Spacer()

            Button {
                isRangeSheetPresented = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "calendar")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DS.ColorToken.purple)

                    Text(viewModel.displayedTitle)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(DS.ColorToken.textPrimary)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 12)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Select period")

            Spacer()

            navCircle("chevron.right", action: viewModel.goToNext)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.95))
        .cornerRadius(DS.Radius.md)
        .shadow(color: DS.Shadow.soft, radius: 14, x: 0, y: 10)
    }

    private func navCircle(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(DS.ColorToken.textSecondary)
                .frame(width: 36, height: 36)
                .background(Color.white.opacity(0.9))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Donut card

    private var donutCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {

            // centered title like Figma + small switch button
            HStack(alignment: .center) {
                Spacer()

                Text(titleForBreakdown)
                    .font(DS.Typography.sectionTitle)
                    .foregroundColor(DS.ColorToken.textPrimary)

                Spacer()

                breakdownMiniButton
            }

            ZStack {
                donut
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 6)
            .padding(.bottom, 2)
        }
        .dsCard(padding: DS.Spacing.lg)
        .cornerRadius(DS.Radius.lg)
    }

    private var breakdownMiniButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.breakdown = (viewModel.breakdown == .category) ? .task : .category
            }
        } label: {
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DS.ColorToken.textSecondary)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color.white.opacity(0.9)))
                .overlay(Circle().stroke(Color.black.opacity(0.06), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Switch breakdown")
    }

    private var donut: some View {
        let slices = activeDonutSlices()

        return ZStack {
            DonutChartView(slices: normalizedSlices(slices), lineWidth: 20)
                .frame(width: 220, height: 220)

            VStack(spacing: 4) {
                Text(viewModel.totalMinutes.formattedHoursMinutes())
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(DS.ColorToken.textPrimary)

                Text("Total")
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.ColorToken.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Total card (like Figma)

    private var totalCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {

            HStack(spacing: 14) {
                Circle()
                    .fill(DS.ColorToken.purple.opacity(0.12))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "clock")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(DS.ColorToken.purple)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Total Hours")
                        .font(DS.Typography.subtitle)
                        .foregroundStyle(DS.ColorToken.textSecondary)

                    // если ты хочешь именно число вроде 124.5 — замени на отдельный formatter.
                    Text(viewModel.totalMinutes.formattedHoursMinutes())
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(DS.ColorToken.textPrimary)
                }

                Spacer()
            }

            Divider().opacity(0.15)

            if activeCount == 0 {
                Text("Add some tasks to see totals.")
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.ColorToken.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 12) {
                    ForEach(activeTotalRows) { row in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(row.color)
                                .frame(width: 12, height: 12)

                            Text(row.name)
                                .font(DS.Typography.body)
                                .foregroundColor(DS.ColorToken.textPrimary)
                                .lineLimit(1)

                            Spacer()

                            Text("\(row.minutes.formattedHoursMinutes()) (\(percentString(row.percent)))")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(DS.ColorToken.textPrimary)
                        }
                    }
                }
            }
        }
        .dsCard(padding: DS.Spacing.lg)
        .cornerRadius(DS.Radius.lg)
    }

    // MARK: - Stats mapping (category/task)

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

    private struct TotalRowModel: Identifiable {
        let id: String
        let name: String
        let minutes: Int
        let color: Color
        let percent: Double
    }

    private var activeTotalRows: [TotalRowModel] {
        switch viewModel.breakdown {
        case .category:
            return viewModel.categoryStats.map { stat in
                TotalRowModel(
                    id: stat.id,
                    name: stat.name,
                    minutes: stat.minutes,
                    color: categoryColor(stat),
                    percent: viewModel.percent(for: stat)
                )
            }
        case .task:
            return viewModel.taskStats.map { stat in
                TotalRowModel(
                    id: stat.id,
                    name: stat.title,
                    minutes: stat.minutes,
                    color: taskColor(stat),
                    percent: viewModel.percent(for: stat)
                )
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
