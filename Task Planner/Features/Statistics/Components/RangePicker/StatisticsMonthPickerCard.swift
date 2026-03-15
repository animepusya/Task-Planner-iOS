//
//  StatisticsMonthPickerCard.swift
//  Task Planner
//
//  Created by Руслан Меланин on 15.03.2026.
//

import SwiftUI

struct StatisticsMonthPickerCard: View {
    @Binding var selectedDate: Date

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Choose month")
                .font(DS.Typography.subtitle)
                .foregroundStyle(DS.ColorToken.textSecondary)

            yearStepper

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(Array(monthItems.enumerated()), id: \.offset) { index, monthName in
                    monthButton(
                        title: monthName,
                        month: index + 1
                    )
                }
            }
        }
        .dsCard(padding: DS.Spacing.md)
    }

    private var yearStepper: some View {
        HStack {
            Text(String(format: "%d", selectedYear))
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(DS.ColorToken.textPrimary)

            Spacer()

            HStack(spacing: 8) {
                navButton(systemName: "chevron.left") {
                    shiftYear(-1)
                }

                navButton(systemName: "chevron.right") {
                    shiftYear(1)
                }
            }
        }
    }

    private func monthButton(title: String, month: Int) -> some View {
        let isSelected = month == selectedMonth

        return Button {
            selectMonth(month)
        } label: {
            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(isSelected ? .white : DS.ColorToken.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(isSelected ? DS.ColorToken.purple : Color.white.opacity(0.9))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.black.opacity(isSelected ? 0.0 : 0.06), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func navButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DS.ColorToken.textSecondary)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Color.white.opacity(0.95)))
                .overlay(Circle().stroke(Color.black.opacity(0.06), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var calendar: Calendar {
        Calendar.current
    }

    private var selectedYear: Int {
        calendar.component(.year, from: selectedDate)
    }

    private var selectedMonth: Int {
        calendar.component(.month, from: selectedDate)
    }

    private var monthItems: [String] {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.calendar = calendar
        formatter.dateFormat = "LLL"

        return (1...12).map { month in
            let date = calendar.date(from: DateComponents(year: 2000, month: month, day: 1)) ?? .now
            return formatter.string(from: date)
        }
    }

    private func selectMonth(_ month: Int) {
        let day = 1
        let comps = DateComponents(year: selectedYear, month: month, day: day)
        let newDate = calendar.date(from: comps) ?? selectedDate
        selectedDate = calendar.startOfMonth(for: newDate)
    }

    private func shiftYear(_ delta: Int) {
        guard let updated = calendar.date(byAdding: .year, value: delta, to: selectedDate) else { return }
        selectedDate = calendar.startOfMonth(for: updated)
    }
}
