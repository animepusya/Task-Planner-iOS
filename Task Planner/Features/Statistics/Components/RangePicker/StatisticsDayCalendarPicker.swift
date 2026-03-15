//
//  StatisticsDayCalendarPicker.swift
//  Task Planner
//
//  Created by Руслан Меланин on 15.03.2026.
//

import SwiftUI

struct StatisticsDayCalendarPicker: View {
    @Binding var selectedDate: Date
    let weekStartsOnMonday: Bool

    @State private var displayedMonth: Date

    init(selectedDate: Binding<Date>, weekStartsOnMonday: Bool) {
        self._selectedDate = selectedDate
        self.weekStartsOnMonday = weekStartsOnMonday
        _displayedMonth = State(initialValue: Calendar.current.startOfMonth(for: selectedDate.wrappedValue))
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Choose day")
                .font(DS.Typography.subtitle)
                .foregroundStyle(DS.ColorToken.textSecondary)

            StatisticsCalendarHeader(
                monthTitle: StatisticsCalendarLogic.monthTitle(for: displayedMonth, calendar: calendar),
                onPrevious: { shiftMonth(-1) },
                onNext: { shiftMonth(1) }
            )

            WeekdaysRowView(
                symbols: CalendarGridBuilder.weekdaySymbols(
                    weekStartsOnMonday: weekStartsOnMonday,
                    calendar: calendar
                )
            )

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(monthItems, id: \.id) { item in
                    StatisticsCalendarDayCell(
                        dayNumber: item.dayNumber,
                        isVisible: item.isInDisplayedMonth,
                        style: dayStyle(for: item),
                        onTap: {
                            selectedDate = calendar.startOfDay(for: item.date)
                        }
                    )
                }
            }
        }
        .dsCard(padding: DS.Spacing.md)
        .onChange(of: selectedDate) { _, newValue in
            displayedMonth = calendar.startOfMonth(for: newValue)
        }
    }

    private var calendar: Calendar {
        TaskOccurrence.calendar(weekStartsOnMonday: weekStartsOnMonday)
    }

    private var monthItems: [DayItem] {
        CalendarGridBuilder.makeMonthGrid(
            monthAnchor: displayedMonth,
            weekStartsOnMonday: weekStartsOnMonday,
            calendar: calendar
        )
    }

    private func shiftMonth(_ delta: Int) {
        guard let newDate = calendar.date(byAdding: .month, value: delta, to: displayedMonth) else { return }
        displayedMonth = calendar.startOfMonth(for: newDate)
    }

    private func dayStyle(for item: DayItem) -> StatisticsCalendarDayCellStyle {
        let isSelected = calendar.isDate(item.date, inSameDayAs: selectedDate)

        return StatisticsCalendarDayCellStyle(
            textColor: isSelected ? .white : DS.ColorToken.textPrimary,
            background: AnyView(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(DS.ColorToken.purple)
                    } else {
                        Color.clear
                    }
                }
            ),
            opacity: item.isInDisplayedMonth ? 1.0 : 0.0
        )
    }
}
