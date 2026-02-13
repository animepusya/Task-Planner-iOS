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

    let onPrev: () -> Void
    let onNext: () -> Void
    let onSelectMonthAnchor: (Date) -> Void
    let onToday: () -> Void

    @State private var isPickerPresented = false

    var body: some View {
        HStack {
            navButton(systemName: "chevron.left", action: onPrev)

            Spacer()

            Button {
                isPickerPresented = true
            } label: {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(DS.ColorToken.textPrimary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Select month and year")

            Spacer()

            navButton(systemName: "chevron.right", action: onNext)
        }
        .sheet(isPresented: $isPickerPresented) {
            let currentYear = Calendar.current.component(.year, from: .now)

            MonthYearPickerSheet(
                initialAnchor: monthAnchor,
                yearRange: (currentYear - 10)...(currentYear + 10),
                onToday: {
                    // ✅ 1) перейти в текущий месяц
                    let cal = Calendar.current
                    let today = cal.startOfDay(for: .now)
                    onSelectMonthAnchor(cal.startOfMonth(for: today))

                    // ✅ 2) выбрать сегодняшний день в календаре
                    onToday()
                },
                onDone: { month, year in
                    let cal = Calendar.current
                    var comps = DateComponents()
                    comps.year = year
                    comps.month = month
                    comps.day = 1

                    let date = cal.date(from: comps) ?? monthAnchor
                    onSelectMonthAnchor(cal.startOfMonth(for: date))
                },
                onClose: {
                    isPickerPresented = false
                }
            )
        }
    }

    private func navButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(DS.ColorToken.textSecondary)
                .frame(width: 34, height: 34)
                .background(Color.white.opacity(0.9))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
