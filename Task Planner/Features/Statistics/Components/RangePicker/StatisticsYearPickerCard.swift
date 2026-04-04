//
//  StatisticsYearPickerCard.swift
//  Task Planner
//
//  Created by Руслан Меланин on 15.03.2026.
//

import SwiftUI

struct StatisticsYearPickerCard: View {
    @Binding var selectedDate: Date

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Choose year")
                .font(DS.Typography.subtitle)
                .foregroundStyle(DS.ColorToken.textSecondary)

            LazyVGrid(columns: columns, spacing: 10) {
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
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(isSelected ? .white : DS.ColorToken.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(isSelected ? DS.ColorToken.purple : DS.Surface.chrome)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(isSelected ? Color.clear : DS.Border.subtle, lineWidth: 1)
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
