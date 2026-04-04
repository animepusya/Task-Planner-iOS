//
//  TaskEditorDateTimeSection.swift
//  Task Planner
//
//  Created by Руслан Меланин on 11.02.2026.
//

import SwiftUI

struct TaskEditorDateTimeSection: View {
    @ObservedObject var state: TaskEditorViewModel.DateTimeSectionState

    let availableWidth: CGFloat
    let onApplyDuration: (Int) -> Void

    private enum Layout {
        static let contentInset: CGFloat = DS.Spacing.xs
        static let rowSpacing: CGFloat = DS.Spacing.xs
        static let dateFieldMinimumWidth: CGFloat = 150
        static let datePickerMinimumWidth: CGFloat = 118
        static let timeFieldReservedWidth: CGFloat = 96
        static let timePickerMinimumWidth: CGFloat = 50
    }

    private struct RowMetrics {
        let usesVerticalLayout: Bool
    }

    private static let durationOptions: [(title: String, minutes: Int)] = [
        ("15m", 15),
        ("30m", 30),
        ("60m", 60),
        ("2h", 120),
        ("4h", 240),
        ("8h", 480),
        ("9h", 540),
        ("12h", 720)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Date & Time")
                .font(DS.Typography.sectionTitle)
                .foregroundStyle(state.isInvalid ? .red : DS.ColorToken.textPrimary)

            Toggle(isOn: state.isAllDayBinding) {
                Text("All day")
                    .font(DS.Typography.body)
                    .foregroundStyle(DS.ColorToken.textPrimary)
            }
            .tint(DS.ColorToken.lavender)

            pickerRows

            if !state.isAllDay {
                TaskEditorChipGroup(
                    title: String(localized: "Duration"),
                    chips: Self.durationOptions.map { option in
                        .init(id: option.title, title: option.title) {
                            onApplyDuration(option.minutes)
                        }
                    }
                )
            }

            if let message = state.timeValidationMessage {
                Text(message)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .dsCard(style: .outlined)
        .overlay {
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .stroke(state.isInvalid ? Color.red.opacity(0.35) : .clear, lineWidth: 1.25)
        }
    }

    private var pickerRows: some View {
        VStack(spacing: DS.Spacing.md) {
            pickerRow(
                title: String(localized: "Start"),
                dateIcon: "calendar",
                dateSelection: state.dayDateBinding,
                timeIcon: "clock",
                timeSelection: state.startTimeBinding
            )

            pickerRow(
                title: String(localized: "End"),
                dateIcon: "calendar.badge.clock",
                dateSelection: state.endDayDateBinding,
                timeIcon: "clock.fill",
                timeSelection: state.endTimeBinding
            )
        }
    }

    private var rowMetrics: RowMetrics {
        let contentWidth = max(0, availableWidth - Layout.contentInset * 2)
        let minimumHorizontalWidth = Layout.dateFieldMinimumWidth + Layout.timeFieldReservedWidth + Layout.rowSpacing
        return RowMetrics(usesVerticalLayout: contentWidth < minimumHorizontalWidth)
    }

    private func pickerRow(
        title: String,
        dateIcon: String,
        dateSelection: Binding<Date>,
        timeIcon: String,
        timeSelection: Binding<Date>
    ) -> some View {
        Group {
            if rowMetrics.usesVerticalLayout {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    datePill(title: title, icon: dateIcon, selection: dateSelection)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    timePill(icon: timeIcon, selection: timeSelection, reservesTitleSpace: false)
                        .fixedSize(horizontal: true, vertical: false)
                }
            } else {
                HStack(alignment: .top, spacing: Layout.rowSpacing) {
                    datePill(title: title, icon: dateIcon, selection: dateSelection)
                        .frame(minWidth: Layout.dateFieldMinimumWidth, maxWidth: .infinity, alignment: .leading)
                        .layoutPriority(1)

                    timePill(icon: timeIcon, selection: timeSelection)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
        }
    }

    private func datePill(title: String, icon: String, selection: Binding<Date>) -> some View {
        TaskEditorPillField(
            title: title,
            icon: icon,
            trailingMinWidth: Layout.datePickerMinimumWidth,
            trailingAlignment: .leading,
            expandsTrailing: true
        ) {
            DatePicker("", selection: selection, displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.compact)
        }
    }

    private func timePill(
        icon: String,
        selection: Binding<Date>,
        reservesTitleSpace: Bool = true
    ) -> some View {
        TaskEditorPillField(
            title: nil,
            icon: icon,
            trailingMinWidth: Layout.timePickerMinimumWidth,
            trailingAlignment: .leading,
            reservesTitleSpace: reservesTitleSpace
        ) {
            DatePicker("", selection: selection, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .datePickerStyle(.compact)
                .disabled(state.isAllDay)
                .opacity(state.isAllDay ? 0.45 : 1.0)
        }
        .disabled(state.isAllDay)
        .opacity(state.isAllDay ? 0.85 : 1.0)
        .overlay {
            if state.isAllDay {
                RoundedRectangle(cornerRadius: DS.Radius.sm)
                    .fill(DS.ColorToken.disabledOverlay)
                    .allowsHitTesting(false)
            }
        }
    }
}
