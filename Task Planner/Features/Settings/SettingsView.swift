//
//  SettingsView.swift
//  Task Planner
//
//  Created by Руслан Меланин on 09.02.2026.
//

import Foundation
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: SettingsViewModel

    private let makeNotificationsView: () -> NotificationsView

    @State private var showNotifications = false
    @State private var showClearAllAlert = false

    init(
        viewModel: SettingsViewModel,
        makeNotificationsView: @escaping () -> NotificationsView
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.makeNotificationsView = makeNotificationsView
    }

    init(
        preferencesRepository: PreferencesRepository,
        taskRepository: TaskRepository,
        categoryRepository: CategoryRepository,
        calendarSync: CalendarSyncService,
        makeNotificationsView: @escaping () -> NotificationsView
    ) {
        _viewModel = StateObject(
            wrappedValue: SettingsViewModel(
                preferencesRepository: preferencesRepository,
                taskRepository: taskRepository,
                categoryRepository: categoryRepository,
                calendarSync: calendarSync
            )
        )
        self.makeNotificationsView = makeNotificationsView
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView(gradient: DS.GradientToken.splash)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: DS.Spacing.lg) {
                        SettingsScreenHeader {
                            dismiss()
                        }

                        VStack(spacing: DS.Spacing.lg) {
                            appSection
                            notificationsSection
                            calendarSection
                            categoriesSection
                            dataSection
                        }
                        .padding(.horizontal, DS.Spacing.md)
                        .padding(.bottom, DS.Spacing.xl)
                    }
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $showNotifications) {
                makeNotificationsView()
            }
            .alert("Clear all tasks?", isPresented: $showClearAllAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    viewModel.clearAllTasks()
                }
            } message: {
                Text("This action will permanently remove all tasks from the app.")
            }
        }
        .onAppear {
            viewModel.load()
        }
    }

    // MARK: - Sections

    private var appSection: some View {
        SettingsSection(title: "App") {
            SettingsCard {
                weekStartsOnRow

                SettingsRowDivider()

                SettingsRow(
                    title: "Theme",
                    subtitle: "Prepared for future appearance support",
                    systemImage: "circle.lefthalf.filled"
                ) {
                    Menu {
                        ForEach(SettingsViewModel.ThemeOption.allCases) { option in
                            Button {
                                viewModel.setTheme(option)
                            } label: {
                                if option == viewModel.selectedTheme {
                                    Label(option.title, systemImage: "checkmark")
                                } else {
                                    Text(option.title)
                                }
                            }
                        }
                    } label: {
                        rowValueLabel(viewModel.selectedTheme.title)
                    }
                }

                SettingsRowDivider()

                SettingsRow(
                    title: "Localization",
                    subtitle: "UI is ready. App localization can be connected later",
                    systemImage: "globe"
                ) {
                    Menu {
                        ForEach(SettingsViewModel.LocalizationOption.allCases) { option in
                            Button {
                                viewModel.setLocalization(option)
                            } label: {
                                if option == viewModel.selectedLocalization {
                                    Label(option.title, systemImage: "checkmark")
                                } else {
                                    Text(option.title)
                                }
                            }
                        }
                    } label: {
                        rowValueLabel(viewModel.selectedLocalization.title)
                    }
                }
            }
        }
    }

    private var weekStartsOnRow: some View {
        HStack(alignment: .center, spacing: DS.Spacing.sm) {
            Image(systemName: "calendar")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(DS.ColorToken.textSecondary)
                .frame(width: 22)

            Text("Week starts on")
                .font(DS.Typography.body)
                .foregroundStyle(DS.ColorToken.textPrimary)
                .lineLimit(1)

            Spacer(minLength: DS.Spacing.sm)

            weekStartPicker
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    private var weekStartPicker: some View {
        HStack(spacing: 4) {
            weekStartSegment(
                title: "Monday",
                isSelected: viewModel.weekStartsOnMonday,
                action: {
                    guard viewModel.weekStartsOnMonday == false else { return }
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                        viewModel.setWeekStartsOnMonday(true)
                    }
                }
            )

            weekStartSegment(
                title: "Sunday",
                isSelected: viewModel.weekStartsOnMonday == false,
                action: {
                    guard viewModel.weekStartsOnMonday else { return }
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                        viewModel.setWeekStartsOnMonday(false)
                    }
                }
            )
        }
        .padding(4)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.78))
                .overlay(
                    Capsule()
                        .stroke(Color.black.opacity(0.05), lineWidth: 1)
                )
        )
        .shadow(color: DS.Shadow.soft, radius: 10, x: 0, y: 6)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func weekStartSegment(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack {
                if isSelected {
                    Capsule()
                        .fill(DS.GradientToken.brand)
                }

                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(isSelected ? Color.white : DS.ColorToken.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, 12)
                    .frame(height: 32)
            }
        }
        .buttonStyle(.plain)
        .contentShape(Capsule())
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var notificationsSection: some View {
        SettingsSection(title: "Notifications") {
            SettingsCard {
                SettingsRow(
                    title: "Notifications",
                    subtitle: "Scheduled reminders, defaults and permission status",
                    systemImage: "bell.badge",
                    action: {
                        showNotifications = true
                    },
                    accessory: {
                        trailingChevron
                    }
                )
            }
        }
    }

    private var calendarSection: some View {
        SettingsSection(
            title: "Calendar",
            footer: footerTextForCalendar
        ) {
            SettingsCard {
                SettingsRow(
                    title: "Show tasks in Apple Calendar",
                    subtitle: "Exports to calendar “Task Planner”",
                    systemImage: "calendar.badge.plus",
                    accessory: {
                        Toggle(
                            "",
                            isOn: Binding(
                                get: { viewModel.showTasksInAppleCalendar },
                                set: { viewModel.setShowTasksInAppleCalendar($0) }
                            )
                        )
                        .labelsHidden()
                        .tint(DS.ColorToken.purple)
                    }
                )

                SettingsRowDivider()

                SettingsRow(
                    title: "Show Apple Calendar events in Planner",
                    subtitle: "Read-only overlay, not saved in SwiftData",
                    systemImage: "calendar.badge.clock",
                    accessory: {
                        Toggle(
                            "",
                            isOn: Binding(
                                get: { viewModel.showAppleCalendarEventsInPlanner },
                                set: { viewModel.setShowAppleCalendarEventsInPlanner($0) }
                            )
                        )
                        .labelsHidden()
                        .tint(DS.ColorToken.purple)
                    }
                )

                SettingsRowDivider()

                SettingsRow(
                    title: "Export now",
                    subtitle: "Force sync current tasks to Apple Calendar",
                    systemImage: "arrow.up.right.square",
                    action: {
                        viewModel.exportNow()
                    },
                    accessory: {
                        EmptyView()
                    }
                )

                SettingsRowDivider()

                SettingsRow(
                    title: "Remove exported events",
                    subtitle: "Delete all events created by Task Planner",
                    systemImage: "trash",
                    isDestructive: true,
                    action: {
                        viewModel.removeExportedEvents()
                    },
                    accessory: {
                        EmptyView()
                    }
                )
            }
        }
    }

    private var categoriesSection: some View {
        SettingsSection(title: "Categories") {
            SettingsCard {
                CategoryInputRow(
                    title: $viewModel.newCategoryTitle,
                    onAdd: { viewModel.addCategory() }
                )

                if !viewModel.categories.isEmpty {
                    SettingsRowDivider()
                }

                ForEach(Array(viewModel.categories.enumerated()), id: \.element.id) { index, category in
                    CategoryListRow(
                        title: category.title,
                        isDeletable: viewModel.isDeletable(category),
                        onDelete: { viewModel.deleteCategory(category) }
                    )

                    if index < viewModel.categories.count - 1 {
                        SettingsRowDivider()
                    }
                }
            }
        }
    }

    private var dataSection: some View {
        SettingsSection(
            title: "Data",
            footer: "Use with caution. This action cannot be undone."
        ) {
            SettingsCard {
                SettingsRow(
                    title: "Clear all tasks",
                    subtitle: "Remove all tasks and planner data from this device",
                    systemImage: "trash",
                    isDestructive: true,
                    action: {
                        showClearAllAlert = true
                    },
                    accessory: {
                        EmptyView()
                    }
                )
            }
        }
    }

    // MARK: - Helpers

    private var footerTextForCalendar: String? {
        if let error = viewModel.calendarErrorText, !error.isEmpty {
            return error
        }

        return viewModel.calendarStatusText.isEmpty ? nil : viewModel.calendarStatusText
    }

    private var trailingChevron: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(DS.ColorToken.textSecondary.opacity(0.9))
    }

    private func rowValueLabel(_ value: String) -> some View {
        HStack(spacing: 6) {
            Text(value)
                .font(DS.Typography.body)
                .foregroundStyle(DS.ColorToken.textSecondary)

            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(DS.ColorToken.textSecondary.opacity(0.85))
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(Color.black.opacity(0.03), in: Capsule())
    }
}
