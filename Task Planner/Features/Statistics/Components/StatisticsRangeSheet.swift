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

    let onPickMonthYear: (_ newAnchor: Date) -> Void

    @State private var showMonthYearPicker = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Period")
                    .font(DS.Typography.sectionTitle)
                    .foregroundStyle(DS.ColorToken.textPrimary)

                Picker("", selection: $range) {
                    ForEach(StatisticsRange.allCases) { r in
                        Text(r.title).tag(r)
                    }
                }
                .pickerStyle(.segmented)

                Button {
                    setToday()
                    dismiss()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text(todayTitle)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(DS.ColorToken.purple))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)

                if range == .month {
                    Button {
                        showMonthYearPicker = true
                    } label: {
                        HStack {
                            Text("Pick month & year")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                            Spacer()
                            Image(systemName: "calendar")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(DS.ColorToken.textPrimary)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 14)
                        .background(
                            RoundedRectangle(cornerRadius: DS.Radius.md)
                                .fill(Color.white.opacity(0.95))
                        )
                    }
                    .buttonStyle(.plain)
                    .sheet(isPresented: $showMonthYearPicker) {
                        MonthYearPickerSheet(
                            initialAnchor: Calendar.current.startOfMonth(for: anchorDate),
                            yearRange: defaultYearRange(),
                            quickActionTitle: "Current month",
                            onQuickAction: {
                                anchorDate = Calendar.current.startOfMonth(for: .now)
                                onPickMonthYear(anchorDate)
                                showMonthYearPicker = false
                            },
                            onDone: { month, year in
                                let cal = Calendar.current
                                var comps = DateComponents()
                                comps.year = year
                                comps.month = month
                                comps.day = 1

                                let date = cal.date(from: comps) ?? anchorDate
                                let newAnchor = cal.startOfMonth(for: date)

                                anchorDate = newAnchor
                                onPickMonthYear(newAnchor)
                                showMonthYearPicker = false
                            },
                            onCancel: { showMonthYearPicker = false }
                        )
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(DS.Spacing.lg)
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var todayTitle: String {
        switch range {
        case .day: return "Today"
        case .week: return "This week"
        case .month: return "This month"
        case .year: return "This year"
        }
    }

    private func setToday() {
        let cal = Calendar.current
        switch range {
        case .day:
            anchorDate = cal.startOfDay(for: .now)
        case .week:
            anchorDate = cal.startOfDay(for: .now)
        case .month:
            anchorDate = cal.startOfMonth(for: .now)
        case .year:
            anchorDate = cal.startOfDay(for: .now)
        }
    }

    private func defaultYearRange() -> ClosedRange<Int> {
        let currentYear = Calendar.current.component(.year, from: .now)
        return (currentYear - 10)...(currentYear + 10)
    }
}

// MARK: - Month/Year Picker (local reusable)

private struct MonthYearPickerSheet: View {
    let initialAnchor: Date
    let yearRange: ClosedRange<Int>

    let quickActionTitle: String
    let onQuickAction: (() -> Void)?
    let onDone: (_ month: Int, _ year: Int) -> Void
    let onCancel: () -> Void

    @State private var selectedMonth: Int
    @State private var selectedYear: Int

    init(
        initialAnchor: Date,
        yearRange: ClosedRange<Int>,
        quickActionTitle: String,
        onQuickAction: (() -> Void)?,
        onDone: @escaping (_ month: Int, _ year: Int) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.initialAnchor = initialAnchor
        self.yearRange = yearRange
        self.quickActionTitle = quickActionTitle
        self.onQuickAction = onQuickAction
        self.onDone = onDone
        self.onCancel = onCancel

        let cal = Calendar.current
        let comps = cal.dateComponents([.month, .year], from: initialAnchor)
        _selectedMonth = State(initialValue: comps.month ?? 1)
        _selectedYear = State(initialValue: comps.year ?? cal.component(.year, from: .now))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    Picker("Month", selection: $selectedMonth) {
                        ForEach(1...12, id: \.self) { month in
                            Text(monthName(for: month)).tag(month)
                        }
                    }
                    .pickerStyle(.wheel)

                    Picker("Year", selection: $selectedYear) {
                        ForEach(Array(yearRange), id: \.self) { year in
                            Text("\(year)").tag(year)
                        }
                    }
                    .pickerStyle(.wheel)
                }
                .frame(height: 180)
                .clipped()

                if let onQuickAction {
                    Button {
                        onQuickAction()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 13, weight: .semibold))
                            Text(quickActionTitle)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(DS.ColorToken.purple)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .background(Capsule().fill(DS.ColorToken.purple.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .navigationTitle("Select month")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { onDone(selectedMonth, selectedYear) }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func monthName(for month: Int) -> String {
        var comps = DateComponents()
        comps.year = 2000
        comps.month = month
        comps.day = 1

        let cal = Calendar.current
        let date = cal.date(from: comps) ?? .now

        let f = DateFormatter()
        f.calendar = cal
        f.locale = .current
        f.dateFormat = "LLLL"
        return f.string(from: date)
    }
}
