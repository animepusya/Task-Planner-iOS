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

    var body: some View {
        Group {
            // Header
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
            .listRowInsets(.init())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            let reminders = viewModel.scheduledNext7Days(tasks: tasks)

            if reminders.isEmpty {
                Section {
                    Text(emptyText)
                        .font(DS.Typography.body)
                        .foregroundStyle(DS.ColorToken.textSecondary)
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.bottom, DS.Spacing.lg)
                }
                .listRowInsets(.init())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                Section {
                    ForEach(reminders) { r in
                        ScheduledReminderRow(reminder: r)
                            .padding(.horizontal, DS.Spacing.lg)
                            .padding(.vertical, DS.Spacing.xs)
                            .listRowInsets(.init())
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if
                                    let task = taskEntity(for: r)
                                {
                                    viewModel.openTask(taskId: task.persistentModelID, day: r.dayKey)
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if let task = taskEntity(for: r) {
                                    if r.isSuppressed {
                                        Button {
                                            lightHaptic()
                                            viewModel.enableReminderForThisDay(
                                                taskId: task.persistentModelID,
                                                occurrenceKey: r.occurrenceKey,
                                                occurrenceDay: r.dayKey
                                            )
                                        } label: {
                                            Label("Enable", systemImage: "arrow.uturn.backward.circle")
                                        }
                                        .tint(DS.ColorToken.lavender)
                                    } else {
                                        Button {
                                            lightHaptic()
                                            viewModel.disableReminderForThisDay(
                                                taskId: task.persistentModelID,
                                                occurrenceKey: r.occurrenceKey
                                            )
                                        } label: {
                                            Label("Disable", systemImage: "bell.slash")
                                        }
                                        .tint(DS.ColorToken.purple)
                                    }
                                } else {
                                    // No matching task — produce an empty view to satisfy ViewBuilder
                                    EmptyView()
                                }
                            }
                    }
                }
                .listRowInsets(.init())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
    }

    private func taskEntity(for reminder: ScheduledReminderItem) -> TaskEntity? {
        tasks.first(where: { String(describing: $0.persistentModelID) == reminder.taskId })
    }

    private func lightHaptic() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

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
