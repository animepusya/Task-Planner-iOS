//
//  NotificationsScheduledSection.swift
//  Task Planner
//
//  Created by Руслан Меланин on 04.03.2026.
//

import SwiftUI
import SwiftData
import UIKit

struct NotificationsScheduledSection: View {
    @ObservedObject var viewModel: NotificationsViewModel
    let tasks: [TaskEntity]

    private var reminders: [ScheduledReminderItem] {
        viewModel.scheduledNext7Days(tasks: tasks)
    }

    private var taskIdMap: [String: PersistentIdentifier] {
        var dict: [String: PersistentIdentifier] = [:]
        dict.reserveCapacity(tasks.count)
        for t in tasks {
            dict[String(describing: t.persistentModelID)] = t.persistentModelID
        }
        return dict
    }

    var body: some View {
        Group {
            headerSection

            if reminders.isEmpty {
                emptySection
            } else {
                rowsSection
            }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text("Scheduled")
                    .font(DS.Typography.sectionTitle)
                    .foregroundStyle(DS.ColorToken.textPrimary)
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.top, DS.Spacing.sm)
                    .padding(.bottom, DS.Spacing.xs)
            }
        }
        .applyScheduledListChrome()
    }

    private var emptySection: some View {
        Section {
            Text(emptyText)
                .font(DS.Typography.body)
                .foregroundStyle(DS.ColorToken.textSecondary)
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.lg)
        }
        .applyScheduledListChrome()
    }

    private var rowsSection: some View {
        Section {
            ForEach(reminders, id: \.id) { r in
                let taskId = taskIdMap[r.taskId]

                ScheduledReminderRow(reminder: r)
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.xs)
                    .applyScheduledRowChrome()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard let taskId else { return }
                        viewModel.openTask(taskId: taskId, day: r.dayKey)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        ScheduledSwipeActions(
                            reminder: r,
                            taskId: taskId,
                            onDisable: { id in
                                lightHaptic()
                                viewModel.disableReminderForThisDay(taskId: id, occurrenceKey: r.occurrenceKey)
                            },
                            onEnable: { id in
                                lightHaptic()
                                viewModel.enableReminderForThisDay(
                                    taskId: id,
                                    occurrenceKey: r.occurrenceKey,
                                    occurrenceDay: r.dayKey
                                )
                            }
                        )
                    }
            }
        }
        .applyScheduledListChrome()
    }

    // MARK: - Actions

    private func lightHaptic() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func disableReminderForThisDay(_ taskId: PersistentIdentifier, _ r: ScheduledReminderItem) {
        viewModel.disableReminderForThisDay(taskId: taskId, occurrenceKey: r.occurrenceKey)
    }

    private func enableReminderForThisDay(_ taskId: PersistentIdentifier, _ r: ScheduledReminderItem) {
        viewModel.enableReminderForThisDay(taskId: taskId, occurrenceKey: r.occurrenceKey, occurrenceDay: r.dayKey)
    }

    // MARK: - Empty text

    private var emptyText: String {
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

// MARK: - Small modifiers

private extension View {
    func applyScheduledListChrome() -> some View {
        self
            .listRowInsets(.init())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }

    func applyScheduledRowChrome() -> some View {
        self
            .listRowInsets(.init())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}
