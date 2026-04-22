//
//  StatisticsMonthPickerCard.swift
//  Task Planner
//
//  Created by Руслан Меланин on 15.03.2026.
//

import SwiftUI

struct StatisticsMonthPickerCard: View {
    @Environment(\.dsAdaptiveMetrics) private var dsMetrics

    @Binding var selectedDate: Date

    var body: some View {
        let adaptiveColumns = [
            GridItem(.flexible(), spacing: dsMetrics.spacing(10)),
            GridItem(.flexible(), spacing: dsMetrics.spacing(10)),
            GridItem(.flexible(), spacing: dsMetrics.spacing(10))
        ]

        VStack(alignment: .leading, spacing: dsMetrics.spacing(DS.Spacing.md)) {
            Text("Choose month")
                .font(
                    dsMetrics.font(
                        15,
                        weight: .medium,
                        category: .body
                    )
                )
                .foregroundStyle(DS.ColorToken.textSecondary)

            yearStepper

            LazyVGrid(columns: adaptiveColumns, spacing: dsMetrics.spacing(10)) {
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
                .font(
                    dsMetrics.font(
                        22,
                        weight: .bold,
                        category: .display
                    )
                )
                .foregroundStyle(DS.ColorToken.textPrimary)

            Spacer()

            HStack(spacing: dsMetrics.spacing(8)) {
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
                .font(
                    dsMetrics.font(
                        14,
                        weight: .semibold,
                        category: .micro
                    )
                )
                .foregroundStyle(isSelected ? .white : DS.ColorToken.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, dsMetrics.spacing(12))
                .background(
                    RoundedRectangle(
                        cornerRadius: dsMetrics.cornerRadius(14),
                        style: .continuous
                    )
                        .fill(isSelected ? DS.ColorToken.purple : DS.Surface.chrome)
                )
                .overlay(
                    RoundedRectangle(
                        cornerRadius: dsMetrics.cornerRadius(14),
                        style: .continuous
                    )
                        .stroke(
                            isSelected ? Color.clear : DS.Border.subtle,
                            lineWidth: dsMetrics.strokeWidth(1)
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private func navButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
                Image(systemName: systemName)
                    .font(
                        dsMetrics.font(
                            13,
                            weight: .semibold,
                            category: .micro
                        )
                    )
                    .foregroundStyle(DS.ColorToken.textSecondary)
                    .frame(
                        width: dsMetrics.controlSize(34),
                        height: dsMetrics.controlSize(34)
                    )
                    .background(Circle().fill(DS.Surface.chrome))
                    .overlay(
                        Circle().stroke(
                            DS.Border.subtle,
                            lineWidth: dsMetrics.strokeWidth(1)
                        )
                    )
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
        return (1...12).map { month in
            let date = calendar.date(from: DateComponents(year: 2000, month: month, day: 1)) ?? .now
            return date.monthShortName(using: calendar)
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
