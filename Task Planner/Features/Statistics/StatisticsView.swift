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
    @Environment(\.dsAdaptiveMetrics) private var dsMetrics

    @State private var isViewVisible = false
    @State private var selectedSliceId: String? = nil
    @State private var headerCollapseProgress: CGFloat = 0
    @State private var headerReservedHeight: CGFloat = 0

    private let isActive: Bool
    private let onOpenSettings: () -> Void
    private let onOpenComparison: (StatisticsViewModel) -> Void
    private let onOpenPaywall: (PaywallEntryPoint) -> Void

    init(
        taskRepository: TaskRepository,
        preferencesRepository: PreferencesRepository,
        isActive: Bool = true,
        onOpenSettings: @escaping () -> Void,
        onOpenComparison: @escaping (StatisticsViewModel) -> Void,
        onOpenPaywall: @escaping (PaywallEntryPoint) -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: StatisticsViewModel(
                taskRepository: taskRepository,
                preferencesRepository: preferencesRepository
            )
        )
        self.isActive = isActive
        self.onOpenSettings = onOpenSettings
        self.onOpenComparison = onOpenComparison
        self.onOpenPaywall = onOpenPaywall
    }

    var body: some View {
        let snapshot = viewModel.snapshot
        let breakdownSnapshot = snapshot.breakdownSnapshot(for: viewModel.breakdown)

        ZStack(alignment: .top) {
            AppBackgroundView(
                gradient: DS.GradientToken.pinkPurpleSoft,
                gradientOpacity: 0.55,
                blurRadius: 22,
                showsTopScrim: false
            )

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    topContentSpacer

                    VStack(alignment: .leading, spacing: dsMetrics.spacing(DS.Spacing.lg)) {
                        StatisticsPeriodCard(viewModel: viewModel)
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
                    .padding(.horizontal, dsMetrics.screenPadding(DS.Spacing.lg))
                    .padding(.top, dsMetrics.spacing(DS.Spacing.sm))
                    .padding(.bottom, dsMetrics.spacing(24))
                    .dsContentFrame(.screen)
                }
            }
            .background(Color.clear)
            .contentMargins(.bottom, dsMetrics.tabBarReservedScrollSpace, for: .scrollContent)

            headerOverlay
        }
        .navigationBarHidden(true)
        .onAppear {
            handleVisibilityChange(isActive)
        }
        .onChange(of: isActive) { _, newValue in
            handleVisibilityChange(newValue)
        }
        .onDisappear {
            handleVisibilityChange(false)
        }
        .onChange(of: viewModel.breakdown) { _, _ in
            selectedSliceId = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { note in
            guard let context = note.object as? ModelContext, context == modelContext else { return }
            viewModel.handleModelContextDidSave()
        }
    }

    private func comparisonPreviewCard(
        snapshot: StatisticsComparisonSnapshot
    ) -> some View {
        StatisticsComparisonPreviewCard(snapshot: snapshot) {
            if subscriptionStore.hasAccess(to: .statisticsComparison) {
                onOpenComparison(viewModel)
            } else {
                onOpenPaywall(.statisticsComparison)
            }
        }
    }

    private var header: some View {
        ScreenTopSection(
            title: String(localized: "Statistics"),
            collapseProgress: headerCollapseProgress,
            style: .statistics
        ) {
            IconCircleButton(
                systemName: "gearshape",
                backgroundColor: DS.Surface.card
            ) {
                onOpenSettings()
            }
            .accessibilityLabel("Settings")
        }
    }

    private var resolvedHeaderReservedHeight: CGFloat {
        headerReservedHeight > 0 ? headerReservedHeight : dsMetrics.controlSize(72)
    }

    private var topContentSpacer: some View {
        Color.clear
            .frame(height: resolvedHeaderReservedHeight)
            .frame(maxWidth: .infinity)
            .background {
                // Keep the observer attached even while the tab is inactive so the header
                // stays synchronized with the scroll view's real geometry across tab
                // switches and window/layout changes.
                ScrollViewOffsetReader { offset in
                    updateHeaderCollapse(offset, style: .statistics)
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var headerOverlay: some View {
        ZStack(alignment: .top) {
            header

            header
                .hidden()
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .background {
                    GeometryReader { proxy in
                        let nextHeight = ceil(proxy.size.height)

                        Color.clear
                            .task(id: nextHeight) {
                                updateHeaderReservedHeight(nextHeight)
                            }
                    }
                }
        }
    }

    private func updateHeaderReservedHeight(_ height: CGFloat) {
        guard height > 0 else { return }
        guard abs(height - headerReservedHeight) > 0.5 else { return }
        headerReservedHeight = height
    }

    private func handleVisibilityChange(_ shouldBeVisible: Bool) {
        guard shouldBeVisible != isViewVisible else { return }
        isViewVisible = shouldBeVisible

        if shouldBeVisible {
            viewModel.onViewAppear()
        } else {
            viewModel.onViewDisappear()
        }
    }

    private func donutCard(
        snapshot: StatisticsBreakdownSnapshot,
        totalMinutesText: String
    ) -> some View {
        VStack(alignment: .leading, spacing: dsMetrics.spacing(DS.Spacing.md)) {
            HStack(alignment: .center, spacing: dsMetrics.spacing(12)) {
                Text("Time")
                    .font(
                        dsMetrics.font(
                            18,
                            weight: .semibold,
                            category: .title
                        )
                    )
                    .foregroundColor(DS.ColorToken.textPrimary)
                    .lineLimit(1)

                Spacer(minLength: dsMetrics.spacing(8))

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
            .padding(.top, dsMetrics.spacing(6))
            .padding(.bottom, dsMetrics.spacing(2))
        }
        .dsPrimaryCard(padding: DS.Spacing.lg, cornerRadius: DS.Radius.lg)
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
            .frame(
                width: dsMetrics.spacing(260),
                height: dsMetrics.spacing(260)
            )

            VStack(spacing: dsMetrics.spacing(6)) {
                Text(snapshot.isEmpty ? "Total" : selectedCenter.title)
                    .font(
                        dsMetrics.font(
                            12,
                            weight: .medium,
                            category: .caption
                        )
                    )
                    .foregroundColor(DS.ColorToken.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(snapshot.isEmpty ? totalMinutesText : selectedCenter.valueText)
                    .font(
                        dsMetrics.font(
                            22,
                            weight: .bold,
                            category: .display
                        )
                    )
                    .foregroundColor(DS.ColorToken.textPrimary)
            }
            .padding(.horizontal, dsMetrics.spacing(16))
        }
        .frame(maxWidth: .infinity)
    }

    private func totalCard(
        snapshot: StatisticsBreakdownSnapshot,
        totalMinutesText: String
    ) -> some View {
        VStack(alignment: .leading, spacing: dsMetrics.spacing(DS.Spacing.md)) {
            HStack(spacing: dsMetrics.spacing(14)) {
                Circle()
                    .fill(DS.ColorToken.purple.opacity(0.12))
                    .frame(
                        width: dsMetrics.controlSize(44),
                        height: dsMetrics.controlSize(44)
                    )
                    .overlay(
                        Image(systemName: "clock")
                            .font(
                                dsMetrics.font(
                                    16,
                                    weight: .semibold,
                                    category: .micro
                                )
                            )
                            .foregroundStyle(DS.ColorToken.purple)
                    )

                VStack(alignment: .leading, spacing: dsMetrics.spacing(2)) {
                    Text("Total Hours")
                        .font(
                            dsMetrics.font(
                                15,
                                weight: .medium,
                                category: .body
                            )
                        )
                        .foregroundStyle(DS.ColorToken.textSecondary)

                    Text(totalMinutesText)
                        .font(
                            dsMetrics.font(
                                26,
                                weight: .bold,
                                category: .display
                            )
                        )
                        .foregroundStyle(DS.ColorToken.textPrimary)
                }

                Spacer()
            }

            Divider().opacity(0.15)

            if snapshot.isEmpty {
                Text(snapshot.emptyMessage)
                    .font(
                        dsMetrics.font(
                            12,
                            weight: .medium,
                            category: .caption
                        )
                    )
                    .foregroundColor(DS.ColorToken.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: dsMetrics.spacing(12)) {
                    ForEach(snapshot.rows) { row in
                        HStack(spacing: dsMetrics.spacing(10)) {
                            Circle()
                                .fill(row.color)
                                .frame(
                                    width: dsMetrics.spacing(12),
                                    height: dsMetrics.spacing(12)
                                )

                            Text(row.name)
                                .font(
                                    dsMetrics.font(
                                        15,
                                        weight: .regular,
                                        category: .body
                                    )
                                )
                                .foregroundColor(DS.ColorToken.textPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)

                            Spacer(minLength: dsMetrics.spacing(12))

                            Text(row.valueText)
                                .font(
                                    dsMetrics.font(
                                        15,
                                        weight: .semibold,
                                        category: .body
                                    )
                                )
                                .foregroundStyle(DS.ColorToken.textPrimary)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }
            }
        }
        .dsPrimaryCard(padding: DS.Spacing.lg, cornerRadius: DS.Radius.lg)
    }

    private func updateHeaderCollapse(
        _ scrollOffset: CGFloat,
        style: ScreenTopSectionStyle
    ) {
        let nextProgress = style.collapseProgress(for: scrollOffset)
        guard abs(nextProgress - headerCollapseProgress) > 0.001 else { return }
        headerCollapseProgress = nextProgress
    }
}
