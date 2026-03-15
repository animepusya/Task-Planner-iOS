//
//  StatisticsRangeSheet.swift
//  Task Planner
//
//  Created by Руслан Меланин on 16.02.2026.
//

import SwiftUI

struct StatisticsRangeSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var range: StatisticsRange
    @Binding var anchorDate: Date

    let weekStartsOnMonday: Bool

    var body: some View {
        NavigationStack {
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
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(32)
        .presentationBackground(.clear)
        .animation(.easeInOut(duration: 0.2), value: range)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Period")
                .font(DS.Typography.sectionTitle)
                .foregroundStyle(DS.ColorToken.textPrimary)

            Picker("", selection: $range) {
                ForEach(StatisticsRange.allCases) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)
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
        switch range {
        case .month:
            StatisticsMonthPickerCard(
                selectedDate: $anchorDate
            )

        case .year:
            StatisticsYearPickerCard(
                selectedDate: $anchorDate
            )

        case .day:
            StatisticsDayCalendarPicker(
                selectedDate: $anchorDate,
                weekStartsOnMonday: weekStartsOnMonday
            )

        case .week:
            StatisticsWeekCalendarPicker(
                selectedDate: $anchorDate,
                weekStartsOnMonday: weekStartsOnMonday
            )
        }
    }

    private var quickActionTitle: String {
        switch range {
        case .day: return "Today"
        case .week: return "This week"
        case .month: return "This month"
        case .year: return "This year"
        }
    }

    private func applyQuickAction() {
        let cal = statisticsCalendar

        switch range {
        case .day:
            anchorDate = cal.startOfDay(for: .now)

        case .week:
            anchorDate = cal.startOfDay(for: .now)

        case .month:
            anchorDate = cal.startOfMonth(for: .now)

        case .year:
            let year = cal.component(.year, from: .now)
            anchorDate = cal.date(from: DateComponents(year: year, month: 1, day: 1)) ?? .now
        }
    }

    private var statisticsCalendar: Calendar {
        TaskOccurrence.calendar(weekStartsOnMonday: weekStartsOnMonday)
    }
}
