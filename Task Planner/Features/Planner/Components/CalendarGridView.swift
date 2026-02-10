//
//  CalendarGridView.swift
//  Task Planner
//
//  Created by Руслан Меланин on 09.02.2026.
//

import SwiftUI
import SwiftData

struct CalendarGridView: View {
    let monthAnchor: Date
    let weekStartsOnMonday: Bool
    let selectedDay: Date

    // можно оставить tasks тут, но теперь мы не считаем count внутри
    let tasks: [TaskEntity]

    let indicatorColors: (Date) -> [TaskColor]

    let onSelectDay: (Date) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

    var body: some View {
        let items = CalendarGridBuilder.makeMonthGrid(
            monthAnchor: monthAnchor,
            weekStartsOnMonday: weekStartsOnMonday
        )

        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(items, id: \.id) { item in
                DayCellView(
                    dayNumber: item.dayNumber,
                    date: item.date,
                    isSelected: Calendar.current.isDate(item.date, inSameDayAs: selectedDay),
                    indicatorColors: indicatorColors(item.date),
                    onTap: { onSelectDay(item.date) }
                )
                .opacity(item.isInDisplayedMonth ? 1.0 : 0.0)
                .allowsHitTesting(item.isInDisplayedMonth)
            }
        }
        .padding(.top, 6)
    }
}


