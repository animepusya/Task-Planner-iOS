//
//  TaskEditorReminderSection.swift
//  Task Planner
//
//  Created by Руслан Меланин on 03.03.2026.
//

import SwiftUI

struct TaskEditorReminderSection: View {
    @ObservedObject var state: TaskEditorViewModel.ReminderSectionState
    @ObservedObject var dateTimeState: TaskEditorViewModel.DateTimeSectionState

    let onOpenNotificationsCenter: (() -> Void)?
    let onOpenSystemSettings: (() -> Void)?

    @State private var showAllDayTimePopover = false
    @State private var allDayTempDate: Date = .now

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Reminder")
                .font(DS.Typography.sectionTitle)
                .foregroundStyle(DS.ColorToken.textPrimary)

            Toggle(isOn: state.reminderEnabledBinding) {
                Text("Reminder")
                    .font(DS.Typography.body)
                    .foregroundStyle(DS.ColorToken.textPrimary)
            }
            .tint(DS.ColorToken.lavender)

            if let gate = state.gate {
                gateInline(gate)
            }

            DSRowMenu(
                title: "Remind",
                value: offsetTitle
            ) {
                ForEach(ReminderPreset.allCases) { preset in
                    Button {
                        state.reminderOffsetMinutesBinding.wrappedValue = preset.minutes
                    } label: {
                        HStack(spacing: 10) {
                            Text(preset.displayName)
                            Spacer(minLength: 12)
                            if preset.minutes == state.reminderOffsetMinutes {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
            .disabled(!state.reminderEnabled)
            .opacity(state.reminderEnabled ? 1.0 : 0.55)

            if dateTimeState.isAllDay {
                DSRowButton(
                    title: "Time",
                    value: TimeOfDayMinutes.format(state.reminderAllDayTimeMinutes ?? state.defaultAllDayTimeMinutes),
                    onTap: openAllDayPopover
                )
                .disabled(!state.reminderEnabled)
                .opacity(state.reminderEnabled ? 1.0 : 0.55)
                .popover(isPresented: $showAllDayTimePopover) {
                    allDayTimePopoverContent
                        .presentationCompactAdaptation(.popover)
                }

                Button {
                    state.reminderAllDayTimeMinutesBinding.wrappedValue = nil
                } label: {
                    Text("Use default time")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.ColorToken.purple)
                        .padding(.top, 2)
                }
                .buttonStyle(.plain)
                .disabled(!state.reminderEnabled || state.reminderAllDayTimeMinutes == nil)
                .opacity((state.reminderEnabled && state.reminderAllDayTimeMinutes != nil) ? 1.0 : 0.0)
                .frame(height: (state.reminderEnabled && state.reminderAllDayTimeMinutes != nil) ? nil : 0)
                .clipped()
                .accessibilityHidden(!(state.reminderEnabled && state.reminderAllDayTimeMinutes != nil))
            }
        }
        .dsCard(style: .outlined)
    }

    @ViewBuilder
    private func gateInline(_ gate: TaskEditorViewModel.ReminderGate) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(gate.message)
                .font(DS.Typography.caption)
                .foregroundStyle(DS.ColorToken.textSecondary)

            switch gate.action {
            case .none:
                EmptyView()

            case .openNotificationsCenter:
                if let onOpenNotificationsCenter {
                    Button(action: onOpenNotificationsCenter) {
                        Text("Open Notifications Center")
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.ColorToken.purple)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("Go to Notifications screen.")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.ColorToken.textSecondary)
                }

            case .openSystemSettings:
                if let onOpenSystemSettings {
                    Button(action: onOpenSystemSettings) {
                        Text("Open Settings")
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.ColorToken.purple)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.top, 2)
    }

    private var offsetTitle: String {
        ReminderPreset(rawValue: state.reminderOffsetMinutes)?.displayName
        ?? ReminderPreset.default.displayName
    }

    private func openAllDayPopover() {
        let minutes = state.reminderAllDayTimeMinutes ?? state.defaultAllDayTimeMinutes
        let today = Calendar.current.startOfDay(for: .now)
        allDayTempDate = TimeOfDayMinutes.date(on: today, minutes: minutes)
        showAllDayTimePopover = true
    }

    private var allDayTimePopoverContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Time")
                .font(DS.Typography.sectionTitle)
                .foregroundStyle(DS.ColorToken.textPrimary)

            DatePicker(
                "",
                selection: $allDayTempDate,
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
            .datePickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .clipped()
        }
        .padding(DS.Spacing.lg)
        .background(DS.ColorToken.appBackground)
        .onChange(of: allDayTempDate) { _, newValue in
            let minutes = TimeOfDayMinutes.minutes(from: newValue)
            state.reminderAllDayTimeMinutesBinding.wrappedValue = minutes
        }
    }
}
