//
//  CalendarGridView.swift
//  Task Planner
//
//  Created by Руслан Меланин on 09.02.2026.
//

import SwiftUI

struct CalendarGridView: View {
    let days: [PlannerMonthDayViewData]
    let onSelectDay: (Date) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(days) { day in
                DayCellView(
                    dayNumber: day.dayNumber,
                    date: day.date,
                    isSelected: day.isSelected,
                    indicatorColors: day.indicatorColors,
                    onTap: { onSelectDay(day.date) }
                )
                .opacity(day.isInDisplayedMonth ? 1.0 : 0.0)
                .allowsHitTesting(day.isInDisplayedMonth)
            }
        }
        .padding(.top, 6)
    }
}
