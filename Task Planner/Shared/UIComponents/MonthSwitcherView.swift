//
//  MonthSwitcherView.swift
//  Task Planner
//
//  Created by Руслан Меланин on 09.02.2026.
//

import SwiftUI

struct MonthSwitcherView: View {
    let title: String
    let monthAnchor: Date
    let isNavigationLocked: Bool

    let onPrev: () -> Void
    let onNext: () -> Void
    let onSelectMonthAnchor: (Date) -> Void
    let onToday: (() -> Void)?
    let todayTitle: String?

    @State private var isPickerPresented = false

    init(
        title: String,
        monthAnchor: Date,
        isNavigationLocked: Bool = false,
        onPrev: @escaping () -> Void,
        onNext: @escaping () -> Void,
        onSelectMonthAnchor: @escaping (Date) -> Void,
        onToday: (() -> Void)? = nil,
        todayTitle: String? = nil
    ) {
        self.title = title
        self.monthAnchor = monthAnchor
        self.isNavigationLocked = isNavigationLocked
        self.onPrev = onPrev
        self.onNext = onNext
        self.onSelectMonthAnchor = onSelectMonthAnchor
        self.onToday = onToday
        self.todayTitle = todayTitle
    }

    var body: some View {
        HStack {
            navButton(systemName: "chevron.left", action: onPrev)

            Spacer()

            Button {
                isPickerPresented = true
            } label: {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(DS.ColorToken.textPrimary)
            }
            .buttonStyle(.plain)
            .disabled(isNavigationLocked)
            .opacity(isNavigationLocked ? 0.58 : 1.0)
            .animation(PlannerViewModel.monthTransitionAnimation, value: isNavigationLocked)
            .accessibilityLabel("Select month and year")

            Spacer()

            navButton(systemName: "chevron.right", action: onNext)
        }
        .sheet(isPresented: $isPickerPresented) {
            let currentYear = Calendar.current.component(.year, from: .now)

            MonthYearPickerSheet(
                initialAnchor: monthAnchor,
                yearRange: (currentYear - 10)...(currentYear + 10),
                quickActionTitle: resolvedTodayTitle,
                onQuickAction: onToday == nil ? nil : { handleToday() },
                onDone: { month, year in
                    let cal = Calendar.current
                    var comps = DateComponents()
                    comps.year = year
                    comps.month = month
                    comps.day = 1

                    let date = cal.date(from: comps) ?? monthAnchor
                    onSelectMonthAnchor(cal.startOfMonth(for: date))
                    isPickerPresented = false
                },
                onCancel: {
                    isPickerPresented = false
                }
            )
        }
    }

    private var resolvedTodayTitle: String {
        todayTitle ?? "Today"
    }

    private func handleToday() {
        isPickerPresented = false

        if let onToday {
            onToday()
        } else {
            let cal = Calendar.current
            let today = cal.startOfDay(for: .now)
            onSelectMonthAnchor(cal.startOfMonth(for: today))
        }
    }

    private func navButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(
                    DS.ColorToken.textSecondary.opacity(isNavigationLocked ? 0.55 : 1.0)
                )
                .frame(width: 34, height: 34)
                .dsSurface(
                    Circle(),
                    fill: isNavigationLocked ? DS.Surface.frosted : DS.Surface.chrome,
                    stroke: isNavigationLocked ? DS.Border.muted : DS.Border.subtle
                )
                .opacity(isNavigationLocked ? 0.72 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(isNavigationLocked)
        .animation(PlannerViewModel.monthTransitionAnimation, value: isNavigationLocked)
    }
}

// MARK: - Sheet

private struct MonthYearPickerSheet: View {
    let initialAnchor: Date
    let yearRange: ClosedRange<Int>

    let quickActionTitle: String
    let onQuickAction: (() -> Void)?          // ✅ optional
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
                        .background(
                            Capsule().fill(DS.ColorToken.purple.opacity(0.12))
                        )
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
        return date.monthName(using: cal)
    }
}
