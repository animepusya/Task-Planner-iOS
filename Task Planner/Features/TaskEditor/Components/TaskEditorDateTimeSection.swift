//
//  TaskEditorDateTimeSection.swift
//  Task Planner
//
//  Created by Руслан Меланин on 11.02.2026.
//

import SwiftUI

struct TaskEditorDateTimeSection: View {
    @Binding var dayDate: Date
    @Binding var endDayDate: Date
    @Binding var startTime: Date
    @Binding var endTime: Date

    let timeValidationMessage: String?
    let onApplyDuration: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Date & Time")
                .font(DS.Typography.sectionTitle)
                .foregroundStyle(DS.ColorToken.textPrimary)

            VStack(spacing: DS.Spacing.md) {

                HStack(spacing: DS.Spacing.md) {
                    TaskEditorPillField(title: "Start", icon: "calendar", trailingWidth: 140) {
                        DatePicker("", selection: $dayDate, displayedComponents: .date)
                            .labelsHidden()
                            .datePickerStyle(.compact)
                    }

                    TaskEditorPillField(title: nil, icon: "clock", trailingWidth: 90) {
                        DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .datePickerStyle(.compact)
                    }
                }

                HStack(spacing: DS.Spacing.md) {
                    TaskEditorPillField(title: "End", icon: "calendar.badge.clock", trailingWidth: 140) {
                        DatePicker("", selection: $endDayDate, displayedComponents: .date)
                            .labelsHidden()
                            .datePickerStyle(.compact)
                    }

                    TaskEditorPillField(title: nil, icon: "clock.fill", trailingWidth: 90) {
                        DatePicker("", selection: $endTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .datePickerStyle(.compact)
                    }
                }
            }

            TaskEditorChipGroup(
                title: "Duration",
                chips: [
                    .init(title: "15m") { onApplyDuration(15) },
                    .init(title: "30m") { onApplyDuration(30) },
                    .init(title: "60m") { onApplyDuration(60) },
                    .init(title: "2h")  { onApplyDuration(120) },
                    .init(title: "4h")  { onApplyDuration(240) },
                    .init(title: "8h")  { onApplyDuration(480) },
                    .init(title: "12h") { onApplyDuration(720) }
                ]
            )

            if let msg = timeValidationMessage {
                Text(msg)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .dsCard()
    }
}
