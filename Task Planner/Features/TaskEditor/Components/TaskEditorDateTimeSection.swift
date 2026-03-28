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

    let isInvalid: Bool
    let timeValidationMessage: String?
    let onApplyDuration: (Int) -> Void

    private let anim: Animation = .easeInOut(duration: 0.18)

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Date & Time")
                .font(DS.Typography.sectionTitle)
                .foregroundStyle(isInvalid ? .red : DS.ColorToken.textPrimary)

            Toggle(isOn: $isAllDay) {
                Text("All day")
                    .font(DS.Typography.body)
                    .foregroundStyle(DS.ColorToken.textPrimary)
            }
            .tint(DS.ColorToken.lavender)
            .onChange(of: isAllDay) { _, _ in
                withAnimation(anim) { }
            }

            regularPickers
                .animation(anim, value: isAllDay)

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
            .modifier(VerticalCollapsible(isCollapsed: isAllDay, anim: anim))

            if let msg = timeValidationMessage {
                Text(msg)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .dsCard(style: .outlined)
        .overlay {
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .stroke(isInvalid ? Color.red.opacity(0.35) : .clear, lineWidth: 1.25)
        }
        .animation(anim, value: isAllDay)
        .animation(anim, value: isInvalid)
    }


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
        TaskEditorPillField(title: nil, icon: icon, trailingWidth: 60) {
            DatePicker("", selection: selection, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .datePickerStyle(.compact)

                .disabled(isAllDay)
                .opacity(isAllDay ? 0.45 : 1.0)
        }
        .disabled(isAllDay)
        .opacity(isAllDay ? 0.85 : 1.0)
        .overlay {
            if isAllDay {
                RoundedRectangle(cornerRadius: DS.Radius.sm)
                    .fill(Color.white.opacity(0.35))
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
    }
}

// MARK: - Helpers

private struct VerticalCollapsible: ViewModifier {
    let isCollapsed: Bool
    let anim: Animation

    func body(content: Content) -> some View {
        content
            .opacity(isCollapsed ? 0 : 1)
            .frame(height: isCollapsed ? 0 : nil)
            .clipped()
            .allowsHitTesting(!isCollapsed)
            .accessibilityHidden(isCollapsed)
            .animation(anim, value: isCollapsed)
    }
}
