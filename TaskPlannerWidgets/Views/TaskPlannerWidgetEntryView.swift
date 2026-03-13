//
//  TaskPlannerWidgetEntryView.swift
//  TaskPlannerWidgetsExtension
//
//  Created by Руслан Меланин on 13.03.2026.
//

import SwiftUI
import WidgetKit

struct TaskPlannerWidgetEntryView: View {
    let entry: TaskPlannerHomeEntry

    @Environment(\.widgetRenderingMode) private var widgetRenderingMode

    private var isAccented: Bool {
        widgetRenderingMode == .accented || widgetRenderingMode == .vibrant
    }

    // MARK: - Compact fixed layout metrics
    private let outerPadding: CGFloat = 14
    private let contentSpacing: CGFloat = 10
    private let taskRowSpacing: CGFloat = 8
    private let taskRowHeight: CGFloat = 56
    private let taskFooterHeight: CGFloat = 18

    private var taskAreaHeight: CGFloat {
        (taskRowHeight * 3) + (taskRowSpacing * 2) + taskFooterHeight
    }

    var body: some View {
        ZStack {
            if !isAccented {
                DS.ColorToken.appBackground
            }

            VStack(alignment: .leading, spacing: contentSpacing) {
                header
                    .frame(height: 32)

                TaskPlannerWidgetDayStrip(
                    days: entry.visibleDays,
                    selectedDayKey: entry.selectedDayKey,
                    isAccented: isAccented
                )
                .frame(height: 72)

                fixedTaskArea
                    .frame(maxWidth: .infinity)
                    .frame(height: taskAreaHeight, alignment: .top)

                Spacer(minLength: 0)
            }
            .padding(outerPadding)
        }
        .containerBackground(for: .widget) {
            if isAccented {
                Color.clear
            } else {
                DS.ColorToken.appBackground
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            Text(entry.selectedDay?.titleText ?? "Today")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(
                    isAccented
                    ? AnyShapeStyle(.primary)
                    : AnyShapeStyle(DS.ColorToken.textPrimary)
                )
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 10)

            Link(destination: WidgetRoute.createTask(day: entry.selectedDay?.date ?? .now).url) {
                ZStack {
                    Circle()
                        .fill(
                            isAccented
                            ? AnyShapeStyle(Color.white.opacity(0.18))
                            : AnyShapeStyle(DS.GradientToken.brand)
                        )
                        .widgetAccentable(isAccented)

                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(
                            isAccented
                            ? AnyShapeStyle(.primary)
                            : AnyShapeStyle(Color.white)
                        )
                }
                .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Create Task")
        }
    }

    @ViewBuilder
    private var fixedTaskArea: some View {
        if let selectedDay = entry.selectedDay {
            if selectedDay.tasks.isEmpty {
                VStack(alignment: .leading, spacing: taskRowSpacing) {
                    TaskPlannerWidgetEmptyState(
                        text: "No tasks for this day",
                        isAccented: isAccented
                    )
                    .frame(height: (taskRowHeight * 3) + (taskRowSpacing * 2), alignment: .top)

                    footer(hiddenCount: 0)
                        .frame(height: taskFooterHeight)
                }
            } else {
                let visibleRows = Array(selectedDay.tasks.prefix(3))
                let hiddenCount = max(0, selectedDay.tasks.count - visibleRows.count)

                VStack(alignment: .leading, spacing: taskRowSpacing) {
                    ForEach(0..<3, id: \.self) { index in
                        if index < visibleRows.count {
                            let row = visibleRows[index]

                            Link(destination: WidgetRoute.planner(day: selectedDay.date).url) {
                                TaskPlannerWidgetTaskRow(
                                    task: row,
                                    isAccented: isAccented
                                )
                            }
                            .buttonStyle(.plain)
                        } else {
                            placeholderRow
                        }
                    }

                    footer(hiddenCount: hiddenCount)
                        .frame(height: taskFooterHeight)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: taskRowSpacing) {
                TaskPlannerWidgetEmptyState(
                    text: "No tasks for this day",
                    isAccented: isAccented
                )
                .frame(height: (taskRowHeight * 3) + (taskRowSpacing * 2), alignment: .top)

                footer(hiddenCount: 0)
                    .frame(height: taskFooterHeight)
            }
        }
    }
    
    private var placeholderRow: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.clear)
            .frame(height: taskRowHeight)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private func footer(hiddenCount: Int) -> some View {
        if hiddenCount > 0 {
            HStack(spacing: 6) {
                Circle()
                    .fill(isAccented ? Color.white.opacity(0.75) : DS.ColorToken.purple.opacity(0.92))
                    .frame(width: 5, height: 5)
                    .widgetAccentable(isAccented)

                Text("+\(hiddenCount) more")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .frame(height: taskFooterHeight)
            .background(
                Capsule(style: .continuous)
                    .fill(isAccented ? Color.white.opacity(0.10) : Color.white.opacity(0.58))
            )
        } else {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityHidden(true)
        }
    }
}
