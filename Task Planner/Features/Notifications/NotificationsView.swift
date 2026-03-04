//
//  NotificationsView.swift
//  Task Planner
//
//  Created by Руслан Меланин on 03.03.2026.
//

import SwiftUI
import SwiftData

struct NotificationsView: View {
    @Environment(\.dismiss) private var dismiss

    @StateObject var viewModel: NotificationsViewModel

    @Query(sort: [SortDescriptor(\TaskEntity.dayDate, order: .forward)])
    private var tasks: [TaskEntity]

    @State private var showAllDayTimePopover = false
    @State private var allDayTempDate: Date = .now

    var body: some View {
        VStack(spacing: 0) {
            topBar

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    heroCard
                    defaultsCard
                    scheduledSection
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.lg)
                .padding(.bottom, 28)
            }
        }
        .background(DS.ColorToken.appBackground.ignoresSafeArea())
        .onAppear { viewModel.onAppear() }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DS.ColorToken.textPrimary)
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")

            Spacer()

            Text("Notifications")
                .font(DS.Typography.sectionTitle)
                .foregroundStyle(DS.ColorToken.textPrimary)

            Spacer()

            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, 10)
    }

    // MARK: - Hero

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(alignment: .center) {
                Text("Notifications")
                    .font(DS.Typography.sectionTitle)
                    .foregroundStyle(DS.ColorToken.textPrimary)

                Spacer()

                StatusPill(
                    title: viewModel.notificationsEnabled ? "Enabled" : "Disabled",
                    isOn: viewModel.notificationsEnabled
                )
            }

            Text(systemStatusText)
                .font(DS.Typography.body)
                .foregroundStyle(DS.ColorToken.textSecondary)

            HStack(spacing: 10) {
                Toggle(isOn: Binding(
                    get: { viewModel.notificationsEnabled },
                    set: { viewModel.setNotificationsEnabled($0) }
                )) {
                    Text("App notifications")
                        .font(DS.Typography.body)
                        .foregroundStyle(DS.ColorToken.textPrimary)
                }
                .tint(DS.ColorToken.lavender)

                Spacer()
            }

            if let actionTitle = primaryActionTitle {
                Button(action: viewModel.primaryActionTapped) {
                    HStack {
                        Spacer()
                        Text(actionTitle)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    .padding(.vertical, 12)
                    .background(DS.GradientToken.brand)
                    .cornerRadius(DS.Radius.sm)
                    .shadow(color: DS.Shadow.soft, radius: 14, x: 0, y: 10)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isLoading)
                .opacity(viewModel.isLoading ? 0.6 : 1.0)
            } else {
                Text("You’re all set.")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.ColorToken.textSecondary)
            }
        }
        .dsCard()
    }

    private var systemStatusText: String {
        switch viewModel.systemStatus {
        case .notDetermined:
            return "System permission: Not determined"
        case .denied:
            return "System permission: Denied (enable in Settings)"
        case .authorized:
            return "System permission: Allowed"
        }
    }

    private var primaryActionTitle: String? {
        switch viewModel.systemStatus {
        case .notDetermined:
            return "Enable notifications"
        case .denied:
            return "Open Settings"
        case .authorized:
            return nil
        }
    }

    // MARK: - Defaults

    private var defaultsCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Defaults")
                .font(DS.Typography.sectionTitle)
                .foregroundStyle(DS.ColorToken.textPrimary)

            DSRowMenu(
                title: "Default reminder",
                value: defaultOffsetTitle
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

            DSRowButton(
                title: "All-day time",
                value: TimeOfDayMinutes.format(viewModel.defaultAllDayTimeMinutes),
                onTap: openAllDayPopover
            )
            .popover(isPresented: $showAllDayTimePopover) {
                allDayTimePopoverContent
                    .presentationCompactAdaptation(.popover)
            }

            Text("These defaults apply to new tasks. Each task can override.")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.ColorToken.textSecondary)
        }
        .dsCard()
    }

    private var defaultOffsetTitle: String {
        ReminderPreset(rawValue: viewModel.defaultReminderOffsetMinutes)?.displayName
        ?? ReminderPreset.default.displayName
    }

    private func openAllDayPopover() {
        let today = Calendar.current.startOfDay(for: .now)
        allDayTempDate = TimeOfDayMinutes.date(on: today, minutes: viewModel.defaultAllDayTimeMinutes)
        showAllDayTimePopover = true
    }

    private var allDayTimePopoverContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("All-day time")
                .font(DS.Typography.sectionTitle)
                .foregroundStyle(DS.ColorToken.textPrimary)

            Text("Default time for all-day reminders.")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.ColorToken.textSecondary)

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
            viewModel.setDefaultAllDayTimeMinutes(minutes)
        }
    }

    // MARK: - Scheduled

    private var scheduledSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Scheduled")
                .font(DS.Typography.sectionTitle)
                .foregroundStyle(DS.ColorToken.textPrimary)

            let reminders = viewModel.scheduledNext7Days(tasks: tasks)
            if reminders.isEmpty {
                Text(emptyScheduledText)
                    .font(DS.Typography.body)
                    .foregroundStyle(DS.ColorToken.textSecondary)
                    .padding(.top, 4)
            } else {
                ForEach(reminders) { r in
                    ScheduledReminderRow(reminder: r)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if let task = tasks.first(where: { String(describing: $0.persistentModelID) == r.taskId }) {
                                viewModel.openTask(taskId: task.persistentModelID, day: r.dayKey)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                if let task = tasks.first(where: { String(describing: $0.persistentModelID) == r.taskId }) {
                                    viewModel.disableReminder(for: task.persistentModelID)
                                }
                            } label: {
                                Label("Disable", systemImage: "bell.slash")
                            }
                        }
                }
            }
        }
    }

    private var emptyScheduledText: String {
        if viewModel.notificationsEnabled == false {
            return "Notifications are disabled in the app."
        }
        switch viewModel.systemStatus {
        case .denied:
            return "System permission denied. Enable notifications in Settings."
        case .notDetermined:
            return "Enable notifications to see scheduled reminders."
        case .authorized:
            return "No reminders scheduled for the next 7 days."
        }
    }
}
