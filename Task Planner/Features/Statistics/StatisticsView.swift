//
//  StatisticsView.swift
//  Task Planner
//
//  Created by Руслан Меланин on 09.02.2026.
//

import SwiftUI
import SwiftData

struct StatisticsView: View {
    @StateObject private var viewModel: StatisticsViewModel
    @State private var isRangeSheetPresented = false
    @State private var selectedSliceId: String? = nil

    init(viewModel: StatisticsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    init(
        taskRepository: TaskRepository,
        preferencesRepository: PreferencesRepository,
        onOpenSettings: @escaping () -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: StatisticsViewModel(
                taskRepository: taskRepository,
                preferencesRepository: preferencesRepository,
                onOpenSettings: onOpenSettings
            )
        )
    }
    
    var body: some View {
        ZStack {
            AppBackgroundView(
                gradient: DS.GradientToken.pinkPurpleSoft,
                gradientOpacity: 0.55,
                blurRadius: 22
            )
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    periodCard
                    donutCard
                    totalCard
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.lg)
                .padding(.bottom, 24)
            }
            .background(Color.clear)
            .contentMargins(.bottom, DS.Layout.tabBarReservedScrollSpace, for: .scrollContent)
        }
        .navigationBarHidden(true)
        .safeAreaInset(edge: .top, spacing: 0) {
            header
        }
        .onAppear {
            viewModel.reloadPreferencesAndRefresh()
        }
        .onChange(of: viewModel.breakdown) { _, _ in
            withAnimation(.easeInOut(duration: 0.16)) {
                selectedSliceId = nil
            }
        }
        .sheet(isPresented: $isRangeSheetPresented) {
            StatisticsRangeSheet(
                range: $viewModel.range,
                anchorDate: $viewModel.anchorDate,
                weekStartsOnMonday: viewModel.weekStartsOnMonday
            )
        }
    }
    
    private var header: some View {
        ScreenTopSection(title: "Statistics") {
            IconCircleButton(systemName: "gearshape") {
                viewModel.openSettings()
            }
            .accessibilityLabel("Settings")
        }
    }
    
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
    
    private var donutCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(alignment: .center, spacing: 12) {
                Text("Time")
                    .font(DS.Typography.sectionTitle)
                    .foregroundColor(DS.ColorToken.textPrimary)
                    .lineLimit(1)
                
                Spacer(minLength: 8)
                
                StatisticsBreakdownSegmentedControl(selection: $viewModel.breakdown)
                    .fixedSize(horizontal: false, vertical: true)
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
    
    private var donut: some View {
        let slices = activeDonutSlices()
        let normalized = normalizedSlices(slices)
        
        let selectedRow: TotalRowModel? = {
            guard let id = selectedSliceId else { return nil }
            return activeTotalRows.first(where: { $0.id == id })
        }()
        
        return ZStack {
            DonutChartView(
                slices: normalized,
                innerRadiusRatio: 0.7,
                gapDegrees: 4,
                cornerRadius: 6,
                selectedSliceId: $selectedSliceId
            )
            .frame(width: 260, height: 260)
            
            VStack(spacing: 6) {
                Text(selectedRow?.name ?? "Total")
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.ColorToken.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                Text((selectedRow?.minutes ?? viewModel.totalMinutes).formattedHoursMinutes())
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(DS.ColorToken.textPrimary)
            }
            .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity)
    }
    
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
                                .minimumScaleFactor(0.85)
                            
                            Spacer(minLength: 12)
                            
                            Text("\(row.minutes.formattedHoursMinutes()) (\(percentString(row.percent)))")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(DS.ColorToken.textPrimary)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }
            }
        }
        .dsCard(padding: DS.Spacing.lg)
        .cornerRadius(DS.Radius.lg)
    }
    
    private var activeCount: Int {
        switch viewModel.breakdown {
        case .category:
            return viewModel.categoryStats.count
        case .task:
            return viewModel.taskStats.count
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
        
        return slices.map {
            DonutChartSlice(
                id: $0.id,
                fraction: $0.fraction / sum,
                color: $0.color
            )
        }
    }
    
    private func categoryColor(_ stat: CategoryStat) -> Color {
        stat.taskColor?.uiColor ?? DS.ColorToken.textSecondary
    }
    
    private func taskColor(_ stat: TaskStat) -> Color {
        stat.taskColor?.uiColor ?? DS.ColorToken.textSecondary
    }
    
    private func percentString(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }
}
