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
        NavigationStack(path: $navigationPath) {
            ZStack {
                AppBackgroundView(
                    gradient: DS.GradientToken.pinkPurpleSoft,
                    gradientOpacity: 0.55,
                    blurRadius: 22
                )
                .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                        headerSection
                        quickActionButton
                        pickerContent
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.top, DS.Spacing.lg)
                    .padding(.bottom, DS.Spacing.xl)
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
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(32)
        .presentationBackground(.clear)
        .animation(.easeInOut(duration: 0.2), value: draftRange)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Period")
                .font(DS.Typography.sectionTitle)
                .foregroundStyle(DS.ColorToken.textPrimary)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10)
                ],
                spacing: 10
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
            HStack(spacing: 10) {
                Image(systemName: "location.fill")
                    .font(.system(size: 14, weight: .semibold))

                Text(quickActionTitle)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))

                Spacer()
            }
            .foregroundStyle(.white)
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
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
            HStack(spacing: 8) {
                Text(item.title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(isSelected ? Color.white : DS.ColorToken.textPrimary)

                if isLocked {
                    ProBadge(size: .small)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .fill(isSelected ? AnyShapeStyle(DS.GradientToken.brand) : AnyShapeStyle(DS.Surface.card))
            )
            .overlay {
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .stroke(isSelected ? DS.ColorToken.purple.opacity(0.10) : DS.Border.subtle, lineWidth: 1)
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
