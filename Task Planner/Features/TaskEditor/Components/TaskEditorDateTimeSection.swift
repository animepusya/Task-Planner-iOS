//
//  TaskEditorDateTimeSection.swift
//  Task Planner
//
//  Created by Руслан Меланин on 11.02.2026.
//

import SwiftUI

struct TaskEditorDateTimeSection: View {
    @ObservedObject var state: TaskEditorViewModel.DateTimeSectionState

    let onApplyDuration: (Int) -> Void

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
            HStack(spacing: DS.Spacing.md) {
                TaskEditorPillField(title: String(localized: "Start"), icon: "calendar", trailingWidth: 110) {
                    DatePicker("", selection: state.dayDateBinding, displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                }

                timePill(icon: "clock", selection: state.startTimeBinding)
            }

            HStack(spacing: DS.Spacing.md) {
                TaskEditorPillField(title: String(localized: "End"), icon: "calendar.badge.clock", trailingWidth: 110) {
                    DatePicker("", selection: state.endDayDateBinding, displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                }

                timePill(icon: "clock.fill", selection: state.endTimeBinding)
            }
        }
    }

    private func timePill(icon: String, selection: Binding<Date>) -> some View {
        TaskEditorPillField(title: nil, icon: icon, trailingWidth: 60) {
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
                    .fill(Color.white.opacity(0.35))
                    .allowsHitTesting(false)
            }
        }
    }
}
