//
//  CalendarGridView.swift
//  Task Planner
//
//  Created by Руслан Меланин on 09.02.2026.
//

import SwiftUI

struct CalendarGridView: View {
    @Environment(\.dsAdaptiveMetrics) private var dsMetrics

    let days: [PlannerMonthDayViewData]
    let onSelectDay: (Date) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

    var body: some View {
        let rowSpacing = dsMetrics.spacing(10)
        let topPadding = dsMetrics.spacing(6)
        let rowHeight = dsMetrics.controlSize(44)
        let adaptiveColumns = Array(
            repeating: GridItem(.flexible(), spacing: rowSpacing),
            count: columns.count
        )

        LazyVGrid(columns: adaptiveColumns, spacing: rowSpacing) {
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
        .padding(.top, topPadding)
        .frame(
            minHeight: topPadding + (rowHeight * 6) + (rowSpacing * 5),
            alignment: .top
        )
    }
}
