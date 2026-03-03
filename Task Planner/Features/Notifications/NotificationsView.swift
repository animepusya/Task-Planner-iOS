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

    @State private var showOffsetSheet = false
    @State private var showAllDayTimeSheet = false

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
        .sheet(isPresented: $showOffsetSheet) { offsetPickerSheet }
        .sheet(isPresented: $showAllDayTimeSheet) { allDayTimeSheet }
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

            // balance
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

            DSRowButton(
                title: "Default reminder",
                value: defaultOffsetTitle,
                onTap: { showOffsetSheet = true }
            )

            DSRowButton(
                title: "All-day time",
                value: TimeOfDayMinutes.format(viewModel.defaultAllDayTimeMinutes),
                onTap: { showAllDayTimeSheet = true }
            )

            Text("These defaults apply to new tasks. Each task can override.")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.ColorToken.textSecondary)
        }
        .dsCard()
    }

    private var defaultOffsetTitle: String {
        ReminderPreset.fromOffsetMinutes(viewModel.defaultReminderOffsetMinutes).title
            + (ReminderPreset.fromOffsetMinutes(viewModel.defaultReminderOffsetMinutes) == .customMinutes
               ? " (\(viewModel.defaultReminderOffsetMinutes)m)" : "")
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
                            // Open TaskEditor, preselect day of reminder
                            // Note: taskId string -> we need PersistentIdentifier; we can resolve via tasks list.
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

    // MARK: - Sheets

    private var offsetPickerSheet: some View {
        NotificationsOffsetPickerSheet(
            selectedMinutes: viewModel.defaultReminderOffsetMinutes,
            onSelect: { minutes in
                viewModel.setDefaultOffsetMinutes(minutes)
                showOffsetSheet = false
            },
            onClose: { showOffsetSheet = false }
        )
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private var allDayTimeSheet: some View {
        NotificationsAllDayTimeSheet(
            selectedMinutes: viewModel.defaultAllDayTimeMinutes,
            onSelect: { minutes in
                viewModel.setDefaultAllDayTimeMinutes(minutes)
                showAllDayTimeSheet = false
            },
            onClose: { showAllDayTimeSheet = false }
        )
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
