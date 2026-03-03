//
//  TaskEditorReminderSection.swift
//  Task Planner
//
//  Created by Руслан Меланин on 03.03.2026.
//

import SwiftUI

struct TaskEditorReminderSection: View {
    @Binding var reminderEnabled: Bool
    @Binding var reminderOffsetMinutes: Int
    @Binding var reminderAllDayTimeMinutes: Int?

    let isAllDay: Bool
    let defaultAllDayTimeMinutes: Int

    @State private var showOffsetSheet = false
    @State private var showAllDayTimeSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Reminder")
                .font(DS.Typography.sectionTitle)
                .foregroundStyle(DS.ColorToken.textPrimary)

            Toggle(isOn: $reminderEnabled) {
                Text("Reminder")
                    .font(DS.Typography.body)
                    .foregroundStyle(DS.ColorToken.textPrimary)
            }
            .tint(DS.ColorToken.lavender)

            DSRowButton(
                title: "Remind",
                value: offsetTitle,
                onTap: { showOffsetSheet = true }
            )
            .disabled(!reminderEnabled)
            .opacity(reminderEnabled ? 1.0 : 0.55)

            if isAllDay {
                DSRowButton(
                    title: "Time",
                    value: TimeOfDayMinutes.format(reminderAllDayTimeMinutes ?? defaultAllDayTimeMinutes),
                    onTap: { showAllDayTimeSheet = true }
                )
                .disabled(!reminderEnabled)
                .opacity(reminderEnabled ? 1.0 : 0.55)

                Button {
                    reminderAllDayTimeMinutes = nil
                } label: {
                    Text("Use default time")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.ColorToken.purple)
                        .padding(.top, 2)
                }
                .buttonStyle(.plain)
                .disabled(!reminderEnabled || reminderAllDayTimeMinutes == nil)
                .opacity((reminderEnabled && reminderAllDayTimeMinutes != nil) ? 1.0 : 0.0)
                .frame(height: (reminderEnabled && reminderAllDayTimeMinutes != nil) ? nil : 0)
                .clipped()
                .accessibilityHidden(!(reminderEnabled && reminderAllDayTimeMinutes != nil))
            }
        }
        .dsCard()
        .sheet(isPresented: $showOffsetSheet) {
            NotificationsOffsetPickerSheet(
                selectedMinutes: reminderOffsetMinutes,
                onSelect: { minutes in
                    reminderOffsetMinutes = minutes
                    showOffsetSheet = false
                },
                onClose: { showOffsetSheet = false }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAllDayTimeSheet) {
            NotificationsAllDayTimeSheet(
                selectedMinutes: reminderAllDayTimeMinutes ?? defaultAllDayTimeMinutes,
                onSelect: { minutes in
                    reminderAllDayTimeMinutes = minutes
                    showAllDayTimeSheet = false
                },
                onClose: { showAllDayTimeSheet = false }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    private var offsetTitle: String {
        let preset = ReminderPreset.fromOffsetMinutes(reminderOffsetMinutes)
        if preset == .customMinutes {
            return "\(preset.title) (\(reminderOffsetMinutes)m)"
        }
        return preset.title
    }
}
