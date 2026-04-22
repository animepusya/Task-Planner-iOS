//
//  StatisticsRangeSheet.swift
//  Task Planner
//
//  Created by Руслан Меланин on 16.02.2026.
//

import SwiftUI

struct StatisticsRangeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var subscriptionStore: SubscriptionStore
    @Environment(\.dsAdaptiveMetrics) private var dsMetrics

    @Binding var range: StatisticsRange
    @Binding var anchorDate: Date

    let weekStartsOnMonday: Bool

    @State private var draftRange: StatisticsRange
    @State private var draftAnchorDate: Date
    @State private var navigationPath: [StatisticsRangeRoute] = []

    init(
        range: Binding<StatisticsRange>,
        anchorDate: Binding<Date>,
        weekStartsOnMonday: Bool
    ) {
        self._range = range
        self._anchorDate = anchorDate
        self.weekStartsOnMonday = weekStartsOnMonday
        self._draftRange = State(initialValue: range.wrappedValue)
        self._draftAnchorDate = State(initialValue: anchorDate.wrappedValue)
    }

    var body: some View {
        DSAdaptiveLayoutScope { metrics in
            NavigationStack(path: $navigationPath) {
                ZStack {
                    AppBackgroundView(
                        gradient: DS.GradientToken.pinkPurpleSoft,
                        gradientOpacity: 0.55,
                        blurRadius: 22
                    )
                    .ignoresSafeArea()

                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: metrics.spacing(DS.Spacing.lg)) {
                            headerSection
                            quickActionButton
                            pickerContent
                        }
                        .padding(.horizontal, metrics.screenPadding(DS.Spacing.lg))
                        .padding(.top, metrics.spacing(DS.Spacing.lg))
                        .padding(.bottom, metrics.spacing(DS.Spacing.xl))
                        .dsContentFrame(.modal)
                    }
                }
                .navigationTitle("Filters")
                .navigationBarTitleDisplayMode(.inline)
                .navigationDestination(for: StatisticsRangeRoute.self) { route in
                    switch route {
                    case .paywall(let entryPoint):
                        PaywallView(entryPoint: entryPoint)
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Close") { dismiss() }
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            applySelection()
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(
            UIDevice.current.userInterfaceIdiom == .pad ? 44 : 32
        )
        .presentationBackground(.clear)
        .animation(.easeInOut(duration: 0.2), value: draftRange)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: dsMetrics.spacing(14)) {
            Text("Period")
                .font(
                    dsMetrics.font(
                        18,
                        weight: .semibold,
                        category: .title
                    )
                )
                .foregroundStyle(DS.ColorToken.textPrimary)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: dsMetrics.spacing(10)),
                    GridItem(.flexible(), spacing: dsMetrics.spacing(10))
                ],
                spacing: dsMetrics.spacing(10)
            ) {
                ForEach(StatisticsRange.allCases) { item in
                    rangeButton(for: item)
                }
            }
        }
    }

    private var quickActionButton: some View {
        Button {
            applyQuickAction()
        } label: {
            HStack(spacing: dsMetrics.spacing(10)) {
                Image(systemName: "location.fill")
                    .font(
                        dsMetrics.font(
                            14,
                            weight: .semibold,
                            category: .micro
                        )
                    )

                Text(quickActionTitle)
                    .font(
                        dsMetrics.font(
                            15,
                            weight: .semibold,
                            category: .body
                        )
                    )

                Spacer()
            }
            .foregroundStyle(.white)
            .padding(.vertical, dsMetrics.spacing(12))
            .padding(.horizontal, dsMetrics.spacing(14))
            .background(
                Capsule()
                    .fill(DS.ColorToken.purple)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var pickerContent: some View {
        switch draftRange {
        case .month:
            StatisticsMonthPickerCard(
                selectedDate: $draftAnchorDate
            )

        case .year:
            StatisticsYearPickerCard(
                selectedDate: $draftAnchorDate
            )

        case .day:
            StatisticsDayCalendarPicker(
                selectedDate: $draftAnchorDate,
                weekStartsOnMonday: weekStartsOnMonday
            )

        case .week:
            StatisticsWeekCalendarPicker(
                selectedDate: $draftAnchorDate,
                weekStartsOnMonday: weekStartsOnMonday
            )
        }
    }

    private var quickActionTitle: String {
        switch draftRange {
        case .day: return String(localized: "Today")
        case .week: return String(localized: "This week")
        case .month: return String(localized: "This month")
        case .year: return String(localized: "This year")
        }
    }

    private func rangeButton(for item: StatisticsRange) -> some View {
        let isSelected = draftRange == item
        let lockedFeature = item.requiredProFeature
        let isLocked = lockedFeature.map { subscriptionStore.isLocked($0) } ?? false

        return Button {
            draftRange = item
        } label: {
            HStack(spacing: dsMetrics.spacing(8)) {
                Text(item.title)
                    .font(
                        dsMetrics.font(
                            14,
                            weight: .semibold,
                            category: .micro
                        )
                    )
                    .foregroundStyle(isSelected ? Color.white : DS.ColorToken.textPrimary)

                if isLocked {
                    ProBadge(size: .small)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, dsMetrics.spacing(14))
            .padding(.vertical, dsMetrics.spacing(12))
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(
                    cornerRadius: dsMetrics.cornerRadius(DS.Radius.md),
                    style: .continuous
                )
                    .fill(isSelected ? AnyShapeStyle(DS.GradientToken.brand) : AnyShapeStyle(DS.Surface.card))
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: dsMetrics.cornerRadius(DS.Radius.md),
                    style: .continuous
                )
                    .stroke(
                        isSelected ? DS.ColorToken.purple.opacity(0.10) : DS.Border.subtle,
                        lineWidth: dsMetrics.strokeWidth(1)
                    )
            }
        }
        .buttonStyle(.plain)
    }

    private func applyQuickAction() {
        let cal = statisticsCalendar

        switch draftRange {
        case .day:
            draftAnchorDate = cal.startOfDay(for: .now)

        case .week:
            draftAnchorDate = cal.startOfDay(for: .now)

        case .month:
            draftAnchorDate = cal.startOfMonth(for: .now)

        case .year:
            let year = cal.component(.year, from: .now)
            draftAnchorDate = cal.date(from: DateComponents(year: year, month: 1, day: 1)) ?? .now
        }
    }

    private func applySelection() {
        if let lockedFeature = draftRange.requiredProFeature, subscriptionStore.isLocked(lockedFeature) {
            navigationPath.append(.paywall(.statisticsRange(lockedFeature)))
            return
        }

        range = draftRange
        anchorDate = draftAnchorDate
        dismiss()
    }

    private var statisticsCalendar: Calendar {
        TaskOccurrence.calendar(weekStartsOnMonday: weekStartsOnMonday)
    }
}

private enum StatisticsRangeRoute: Hashable {
    case paywall(PaywallEntryPoint)
}
