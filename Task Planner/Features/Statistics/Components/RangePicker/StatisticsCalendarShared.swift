//
//  StatisticsCalendarShared.swift
//  Task Planner
//
//  Created by Руслан Меланин on 15.03.2026.
//

import SwiftUI

struct StatisticsCalendarHeader: View {
    @Environment(\.dsAdaptiveMetrics) private var dsMetrics

    let monthTitle: String
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack {
            Button(action: onPrevious) {
                Image(systemName: "chevron.left")
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

            Spacer()

            Text(monthTitle)
                .font(
                    dsMetrics.font(
                        18,
                        weight: .bold,
                        category: .title
                    )
                )
                .foregroundStyle(DS.ColorToken.textPrimary)

            Spacer()

            Button(action: onNext) {
                Image(systemName: "chevron.right")
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
    }
}

struct StatisticsCalendarDayCellStyle {
    let textColor: Color
    let background: AnyView
    let opacity: Double

    static func plain(isVisible: Bool) -> StatisticsCalendarDayCellStyle {
        StatisticsCalendarDayCellStyle(
            textColor: DS.ColorToken.textPrimary,
            background: AnyView(Color.clear),
            opacity: isVisible ? 1.0 : 0.0
        )
    }
}

struct StatisticsCalendarDayCell: View {
    @Environment(\.dsAdaptiveMetrics) private var dsMetrics

    let dayNumber: Int
    let isVisible: Bool
    let style: StatisticsCalendarDayCellStyle
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text("\(dayNumber)")
                .font(
                    dsMetrics.font(
                        14,
                        weight: .semibold,
                        category: .micro
                    )
                )
                .foregroundStyle(style.textColor)
                .frame(maxWidth: .infinity, minHeight: dsMetrics.controlSize(42))
                .background(style.background)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: dsMetrics.cornerRadius(12),
                        style: .continuous
                    )
                )
                .opacity(style.opacity)
        }
        .buttonStyle(.plain)
        .allowsHitTesting(isVisible)
    }
}

enum StatisticsCalendarLogic {
    static func monthTitle(for date: Date, calendar: Calendar) -> String {
        date.monthTitle(using: calendar)
    }

    static func weekRange(for date: Date, calendar: Calendar) -> ClosedRange<Date> {
        let weekStart = calendar.date(
            from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        ) ?? calendar.startOfDay(for: date)

        let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        return calendar.startOfDay(for: weekStart)...calendar.startOfDay(for: weekEnd)
    }

    static func isDate(_ date: Date, inSameWeekAs reference: Date, calendar: Calendar) -> Bool {
        weekRange(for: reference, calendar: calendar).contains(calendar.startOfDay(for: date))
    }
}
