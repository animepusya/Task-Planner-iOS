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
    @Binding var isAllDay: Bool

    let timeValidationMessage: String?
    let onApplyDuration: (Int) -> Void

    private let anim: Animation = .easeInOut(duration: 0.18)

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Date & Time")
                .font(DS.Typography.sectionTitle)
                .foregroundStyle(DS.ColorToken.textPrimary)

            Toggle(isOn: $isAllDay) {
                Text("All day")
                    .font(DS.Typography.body)
                    .foregroundStyle(DS.ColorToken.textPrimary)
            }
            .tint(DS.ColorToken.lavender)
            .onChange(of: isAllDay) { _, _ in
                // важно: именно withAnimation надёжно триггерит анимацию изменений layout
                withAnimation(anim) { }
            }

            ViewThatFits(in: .horizontal) {
                regularPickers
                compactPickers
            }
            .animation(anim, value: isAllDay)

            // Duration — можно “скрывать”, но для плавности лучше тоже не удалять полностью
            TaskEditorChipGroup(
                title: "Duration",
                chips: [
                    .init(title: "15m") { onApplyDuration(15) },
                    .init(title: "30m") { onApplyDuration(30) },
                    .init(title: "60m") { onApplyDuration(60) },
                    .init(title: "2h")  { onApplyDuration(120) },
                    .init(title: "4h")  { onApplyDuration(240) },
                    .init(title: "8h")  { onApplyDuration(480) },
                    .init(title: "9h")  { onApplyDuration(540) },
                    .init(title: "12h") { onApplyDuration(720) }
                ]
            )
            .opacity(isAllDay ? 0 : 1)
            .frame(height: isAllDay ? 0 : nil)
            .clipped()
            .allowsHitTesting(!isAllDay)

            if let msg = timeValidationMessage {
                Text(msg)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .opacity(isAllDay ? 0 : 1)
                    .frame(height: isAllDay ? 0 : nil)
                    .clipped()
            }
        }
        .dsCard()
        .animation(anim, value: isAllDay)
    }

    // MARK: - Regular

    private var regularPickers: some View {
        VStack(spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.md) {
                TaskEditorPillField(title: "Start", icon: "calendar", trailingWidth: 110) {
                    DatePicker("", selection: $dayDate, displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                }

                timePill(icon: "clock", selection: $startTime)
            }

            HStack(spacing: DS.Spacing.md) {
                TaskEditorPillField(title: "End", icon: "calendar.badge.clock", trailingWidth: 110) {
                    DatePicker("", selection: $endDayDate, displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                }

                timePill(icon: "clock.fill", selection: $endTime)
            }
        }
    }

    private func timePill(icon: String, selection: Binding<Date>) -> some View {
        TaskEditorPillField(title: nil, icon: icon, trailingWidth: 90) {
            DatePicker("", selection: selection, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .datePickerStyle(.compact)
                .opacity(isAllDay ? 0 : 1)
                .frame(width: isAllDay ? 0 : nil)   // схлопываем место
                .clipped()
                .allowsHitTesting(!isAllDay)
        }
        .opacity(isAllDay ? 0 : 1)
        .frame(width: isAllDay ? 0 : nil)
        .clipped()
        .allowsHitTesting(!isAllDay)
    }

    // MARK: - Compact

    private var compactPickers: some View {
        VStack(spacing: DS.Spacing.md) {
            combinedRow(title: "Start", date: $dayDate, time: $startTime)
            combinedRow(title: "End", date: $endDayDate, time: $endTime)
        }
    }

    private func combinedRow(
        title: String,
        date: Binding<Date>,
        time: Binding<Date>
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(DS.Typography.caption)
                .foregroundStyle(DS.ColorToken.textSecondary)

            HStack(spacing: DS.Spacing.sm) {
                DatePicker("", selection: date, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(1)

                // ВАЖНО: не удаляем DatePicker, а анимируем его
                DatePicker("", selection: time, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .frame(width: isAllDay ? 0 : 40, alignment: .trailing)
                    .opacity(isAllDay ? 0 : 1)
                    .clipped()
                    .allowsHitTesting(!isAllDay)
            }
            .padding(10)
            .background(Color.black.opacity(0.04))
            .cornerRadius(DS.Radius.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
