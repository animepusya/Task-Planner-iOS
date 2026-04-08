//
//  StatisticsView.swift
//  Task Planner
//
//  Created by Руслан Меланин on 09.02.2026.
//

import SwiftData
import SwiftUI

struct StatisticsView: View {
    @StateObject private var viewModel: StatisticsViewModel
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var subscriptionStore: SubscriptionStore

    @State private var isRangeSheetPresented = false
    @State private var isComparisonPresented = false
    @State private var isComparisonPaywallPresented = false
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
        let snapshot = viewModel.snapshot
        let breakdownSnapshot = snapshot.breakdownSnapshot(for: viewModel.breakdown)

        ZStack {
            AppBackgroundView(
                gradient: DS.GradientToken.pinkPurpleSoft,
                gradientOpacity: 0.55,
                blurRadius: 22
            )

            VStack(spacing: 0) {
                header

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                        periodCard(displayedTitle: snapshot.displayedTitle)
                        donutCard(
                            snapshot: breakdownSnapshot,
                            totalMinutesText: snapshot.totalMinutesText
                        )
                        totalCard(
                            snapshot: breakdownSnapshot,
                            totalMinutesText: snapshot.totalMinutesText
                        )
                        comparisonPreviewCard(snapshot: snapshot.comparison)
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.top, DS.Spacing.lg)
                    .padding(.bottom, 24)
                }
                .background(Color.clear)
                .contentMargins(.bottom, DS.Layout.tabBarReservedScrollSpace, for: .scrollContent)
            }
        }
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $isComparisonPresented) {
            StatisticsComparisonView(viewModel: viewModel)
        }
        .navigationDestination(isPresented: $isComparisonPaywallPresented) {
            PaywallView(entryPoint: .statisticsComparison)
                .environmentObject(subscriptionStore)
        }
        .onAppear {
            viewModel.onViewAppear()
        }
        .onChange(of: viewModel.breakdown) { _, _ in
            selectedSliceId = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { note in
            guard let context = note.object as? ModelContext, context == modelContext else { return }
            viewModel.handleModelContextDidSave()
        }
        .sheet(isPresented: $isRangeSheetPresented) {
            StatisticsRangeSheet(
                range: $viewModel.range,
                anchorDate: $viewModel.anchorDate,
                weekStartsOnMonday: viewModel.weekStartsOnMonday
            )
            .environmentObject(subscriptionStore)
        }
    }

    private func comparisonPreviewCard(
        snapshot: StatisticsComparisonSnapshot
    ) -> some View {
        StatisticsComparisonPreviewCard(snapshot: snapshot) {
            if subscriptionStore.hasAccess(to: .statisticsComparison) {
                isComparisonPresented = true
            } else {
                isComparisonPaywallPresented = true
            }
        }
    }

    private var header: some View {
        ScreenTopSection(title: String(localized: "Statistics")) {
            IconCircleButton(systemName: "gearshape") {
                viewModel.openSettings()
            }
            .accessibilityLabel("Settings")
        }
    }

    private func periodCard(displayedTitle: String) -> some View {
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

                    Text(displayedTitle)
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
        .dsSurface(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous),
            fill: DS.Surface.chrome
        )
    }

    private func navCircle(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(DS.ColorToken.textSecondary)
                .frame(width: 36, height: 36)
                .dsSurface(Circle(), fill: DS.Surface.chrome)
        }
        .buttonStyle(.plain)
    }

    private func donutCard(
        snapshot: StatisticsBreakdownSnapshot,
        totalMinutesText: String
    ) -> some View {
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
                donut(
                    snapshot: snapshot,
                    totalMinutesText: totalMinutesText
                )
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 6)
            .padding(.bottom, 2)
        }
        .dsCard(padding: DS.Spacing.lg, cornerRadius: DS.Radius.lg)
    }

    private func donut(
        snapshot: StatisticsBreakdownSnapshot,
        totalMinutesText: String
    ) -> some View {
        let activeSelectedSliceId = snapshot.containsSlice(id: selectedSliceId) ? selectedSliceId : nil
        let selectedCenter = snapshot.centerData(for: activeSelectedSliceId)
        let selectionBinding = Binding<String?>(
            get: { activeSelectedSliceId },
            set: { selectedSliceId = $0 }
        )

        return ZStack {
            DonutChartView(
                slices: snapshot.donutSlices,
                innerRadiusRatio: 0.7,
                gapDegrees: 4,
                cornerRadius: 6,
                selectedSliceId: selectionBinding
            )
            .frame(width: 260, height: 260)

            VStack(spacing: 6) {
                Text(snapshot.isEmpty ? "Total" : selectedCenter.title)
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.ColorToken.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(snapshot.isEmpty ? totalMinutesText : selectedCenter.valueText)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(DS.ColorToken.textPrimary)
            }
            .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity)
    }

    private func totalCard(
        snapshot: StatisticsBreakdownSnapshot,
        totalMinutesText: String
    ) -> some View {
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

                    Text(totalMinutesText)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(DS.ColorToken.textPrimary)
                }

                Spacer()
            }

            Divider().opacity(0.15)

            if snapshot.isEmpty {
                Text(snapshot.emptyMessage)
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.ColorToken.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 12) {
                    ForEach(snapshot.rows) { row in
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

                            Text(row.valueText)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(DS.ColorToken.textPrimary)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }
            }
        }
        .dsCard(padding: DS.Spacing.lg, cornerRadius: DS.Radius.lg)
    }
}
