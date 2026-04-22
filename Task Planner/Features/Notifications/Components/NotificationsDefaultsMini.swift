//
//  NotificationsDefaultsMini.swift
//  Task Planner
//
//  Created by Руслан Меланин on 04.03.2026.
//

import SwiftUI

struct NotificationsDefaultsMini: View {
    @Environment(\.dsAdaptiveMetrics) private var dsMetrics

    @ObservedObject var viewModel: NotificationsViewModel

    @State private var showAllDayPopover = false
    @State private var tempDate: Date = .now

    var body: some View {
        VStack(alignment: .leading, spacing: dsMetrics.spacing(8)) {
            Text("Defaults")
                .font(
                    dsMetrics.font(
                        13,
                        weight: .semibold,
                        category: .micro
                    )
                )
                .foregroundStyle(DS.ColorToken.textSecondary)

            // Reminder menu (только пресеты, без Custom)
            CompactMenuRow(
                title: String(localized: "Reminder"),
                value: offsetTitle
            ) {
                ForEach(ReminderPreset.allCases) { preset in
                    Button {
                        viewModel.setDefaultOffsetMinutes(preset.minutes)
                    } label: {
                        HStack(spacing: 10) {
                            Text(preset.displayName)
                            Spacer(minLength: 12)
                            if preset.minutes == viewModel.defaultReminderOffsetMinutes {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }

            // All-day time -> popover with wheel DatePicker
            CompactTapRow(
                title: String(localized: "All-day"),
                value: TimeOfDayMinutes.format(viewModel.defaultAllDayTimeMinutes),
                onTap: openAllDayPopover
            )
            .popover(isPresented: $showAllDayPopover) {
                allDayPopover
                    .presentationCompactAdaptation(.popover)
            }
        }
        .padding(.vertical, dsMetrics.spacing(2))
        .accessibilityElement(children: .contain)
    }

    private var offsetTitle: String {
        ReminderPreset(rawValue: viewModel.defaultReminderOffsetMinutes)?.displayName
        ?? ReminderPreset.default.displayName
    }

    private func openAllDayPopover() {
        let today = Calendar.current.startOfDay(for: .now)
        tempDate = TimeOfDayMinutes.date(on: today, minutes: viewModel.defaultAllDayTimeMinutes)
        showAllDayPopover = true
    }

    private var allDayPopover: some View {
        VStack(alignment: .leading, spacing: dsMetrics.spacing(10)) {
            Text("All-day time")
                .font(
                    dsMetrics.font(
                        18,
                        weight: .semibold,
                        category: .title
                    )
                )
                .foregroundStyle(DS.ColorToken.textPrimary)

            DatePicker(
                "",
                selection: $tempDate,
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
            .datePickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .clipped()

            Text("Applies to new tasks by default.")
                .font(
                    dsMetrics.font(
                        12,
                        weight: .medium,
                        category: .caption
                    )
                )
                .foregroundStyle(DS.ColorToken.textSecondary)
        }
        .padding(dsMetrics.spacing(DS.Spacing.lg))
        .background(DS.ColorToken.appBackground)
        .onChange(of: tempDate) { _, newValue in
            viewModel.setDefaultAllDayTimeMinutes(TimeOfDayMinutes.minutes(from: newValue))
        }
    }
}
