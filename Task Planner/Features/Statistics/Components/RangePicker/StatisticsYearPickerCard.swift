//
//  StatisticsYearPickerCard.swift
//  Task Planner
//
//  Created by Руслан Меланин on 15.03.2026.
//

import SwiftUI

struct StatisticsYearPickerCard: View {
    @Environment(\.dsAdaptiveMetrics) private var dsMetrics

    @Binding var selectedDate: Date

    var body: some View {
        let adaptiveColumns = [
            GridItem(.flexible(), spacing: dsMetrics.spacing(10)),
            GridItem(.flexible(), spacing: dsMetrics.spacing(10)),
            GridItem(.flexible(), spacing: dsMetrics.spacing(10))
        ]

        VStack(alignment: .leading, spacing: dsMetrics.spacing(DS.Spacing.md)) {
            Text("Choose year")
                .font(
                    dsMetrics.font(
                        15,
                        weight: .medium,
                        category: .body
                    )
                )
                .foregroundStyle(DS.ColorToken.textSecondary)

            LazyVGrid(columns: adaptiveColumns, spacing: dsMetrics.spacing(10)) {
                ForEach(yearItems, id: \.self) { year in
                    yearButton(year)
                }
            }
        }
        .dsCard(padding: DS.Spacing.md)
    }

    private func yearButton(_ year: Int) -> some View {
        let isSelected = year == selectedYear

        return Button {
            selectYear(year)
        } label: {
            Text(String(format: "%d", year))
                .font(
                    dsMetrics.font(
                        15,
                        weight: .semibold,
                        category: .body
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

    private var calendar: Calendar {
        Calendar.current
    }

    private var selectedYear: Int {
        calendar.component(.year, from: selectedDate)
    }

    private var yearItems: [Int] {
        let current = selectedYear
        return Array((current - 6)...(current + 5))
    }

    private func selectYear(_ year: Int) {
        let comps = DateComponents(year: year, month: 1, day: 1)
        selectedDate = calendar.date(from: comps) ?? selectedDate
    }
}
