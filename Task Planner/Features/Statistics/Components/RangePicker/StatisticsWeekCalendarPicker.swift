//
//  StatisticsWeekCalendarPicker.swift
//  Task Planner
//
//  Created by Руслан Меланин on 15.03.2026.
//

import SwiftUI

struct StatisticsWeekCalendarPicker: View {
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
            Text("Choose week")
                .font(DS.Typography.subtitle)
                .foregroundStyle(DS.ColorToken.textSecondary)

            StatisticsCalendarHeader(
                monthTitle: StatisticsCalendarLogic.monthTitle(for: displayedMonth, calendar: calendar),
                onPrevious: { shiftMonth(-1) },
                onNext: { shiftMonth(1) }
            )

            selectedWeekCaption

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

    private var selectedWeekCaption: some View {
        let range = StatisticsCalendarLogic.weekRange(for: selectedDate, calendar: calendar)

        return Text(
            String.localizedStringWithFormat(
                String(localized: "%@ – %@"),
                range.lowerBound.dayTitleShort(using: calendar),
                range.upperBound.dayTitleShort(using: calendar)
            )
        )
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(DS.ColorToken.purple)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(DS.ColorToken.purple.opacity(0.12))
            )
    }

    private func shiftMonth(_ delta: Int) {
        guard let newDate = calendar.date(byAdding: .month, value: delta, to: displayedMonth) else { return }
        displayedMonth = calendar.startOfMonth(for: newDate)
    }

    private func dayStyle(for item: DayItem) -> StatisticsCalendarDayCellStyle {
        let isInSelectedWeek = StatisticsCalendarLogic.isDate(
            item.date,
            inSameWeekAs: selectedDate,
            calendar: calendar
        )

        let isWeekStart = calendar.isDate(
            item.date,
            inSameDayAs: StatisticsCalendarLogic.weekRange(for: selectedDate, calendar: calendar).lowerBound
        )

        let isWeekEnd = calendar.isDate(
            item.date,
            inSameDayAs: StatisticsCalendarLogic.weekRange(for: selectedDate, calendar: calendar).upperBound
        )

        return StatisticsCalendarDayCellStyle(
            textColor: isInSelectedWeek ? .white : DS.ColorToken.textPrimary,
            background: AnyView(
                Group {
                    if isInSelectedWeek {
                        RoundedRectangle(cornerRadius: weekCornerRadius(isStart: isWeekStart, isEnd: isWeekEnd), style: .continuous)
                            .fill(DS.ColorToken.purple)
                    } else {
                        Color.clear
                    }
                }
            ),
            opacity: item.isInDisplayedMonth ? 1.0 : 0.0
        )
    }

    private func weekCornerRadius(isStart: Bool, isEnd: Bool) -> CGFloat {
        if isStart || isEnd { return 12 }
        return 4
    }
}

private extension Date {
    func dayTitleShort(using calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = .current
        formatter.dateFormat = "d MMM"
        return formatter.string(from: self)
    }
}
