//
//  SettingsView.swift
//  Task Planner
//
//  Created by Руслан Меланин on 09.02.2026.
//

import Foundation
import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dsAdaptiveMetrics) private var dsMetrics
    @EnvironmentObject private var subscriptionStore: SubscriptionStore

    @StateObject private var viewModel: SettingsViewModel

    private let makeNotificationsView: () -> NotificationsView
    private let onOpenPaywall: (PaywallEntryPoint) -> Void

    @State private var showNotifications = false
    @State private var showClearAllAlert = false
    @State private var showAddCategoryPrompt = false
    @State private var monetizationNotice: MonetizationNotice?

    init(
        viewModel: SettingsViewModel,
        onOpenPaywall: @escaping (PaywallEntryPoint) -> Void,
        makeNotificationsView: @escaping () -> NotificationsView
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onOpenPaywall = onOpenPaywall
        self.makeNotificationsView = makeNotificationsView
    }

    init(
        preferencesRepository: PreferencesRepository,
        taskRepository: TaskRepository,
        categoryRepository: CategoryRepository,
        calendarSync: CalendarSyncService,
        onOpenPaywall: @escaping (PaywallEntryPoint) -> Void,
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
        self.onOpenPaywall = onOpenPaywall
        self.makeNotificationsView = makeNotificationsView
    }

    var body: some View {
        ZStack {
            AppBackgroundView(gradient: DS.GradientToken.splash)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: dsMetrics.spacing(DS.Spacing.lg)) {
                    preferencesSection
                    generalSection
                    calendarSection
                    categoriesSection
                    proSection
                    legalSection
                    dataSection
                }
                .padding(.horizontal, dsMetrics.screenPadding(DS.Spacing.md))
                .padding(.top, dsMetrics.spacing(DS.Spacing.lg))
                .padding(.bottom, dsMetrics.spacing(DS.Spacing.xl))
                .dsContentFrame(.screen)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
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
        .alert("New Category", isPresented: $showAddCategoryPrompt) {
            TextField("Category name", text: $viewModel.newCategoryTitle)
                .textInputAutocapitalization(.words)
                .disableAutocorrection(true)

            Button("Cancel", role: .cancel) {
                viewModel.prepareForNewCategory()
            }

            Button("Add") {
                confirmAddCategory()
            }
        } message: {
            Text("Choose a name.")
        }
        .alert(item: $monetizationNotice) { notice in
            Alert(
                title: Text(notice.title),
                message: Text(notice.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .onAppear {
            viewModel.load()
        }
        .onChange(of: scenePhase) { _, newValue in
            guard newValue == .active else { return }
            viewModel.refreshAppLanguageDisplayName()
        }
    }

    // MARK: - Sections

    private var preferencesSection: some View {
        SettingsSection(title: String(localized: "Preferences")) {
            SettingsCard {
                weekStartsOnRow

                SettingsRowDivider()

                SettingsRow(
                    title: String(localized: "Theme"),
                    subtitle: String(localized: "Follow system appearance or always use Light or Dark"),
                    systemImage: "circle.lefthalf.filled"
                ) {
                    Menu {
                        ForEach(AppTheme.allCases) { option in
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
            }
        }
    }

    private var generalSection: some View {
        SettingsSection(title: String(localized: "General")) {
            SettingsCard {
                SettingsRow(
                    title: String(localized: "App Language"),
                    subtitle: String(localized: "Change in iPhone Settings"),
                    systemImage: "globe",
                    action: openAppSettings,
                    accessory: {
                        trailingValueChevron(viewModel.appLanguageDisplayName)
                    }
                )

                SettingsRowDivider()

                SettingsRow(
                    title: String(localized: "Notifications"),
                    subtitle: String(localized: "Scheduled reminders, defaults and permission status"),
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

    private var weekStartsOnRow: some View {
        HStack(alignment: .center, spacing: dsMetrics.spacing(DS.Spacing.sm)) {
            Image(systemName: "calendar")
                .font(
                    dsMetrics.font(
                        16,
                        weight: .semibold,
                        category: .micro
                    )
                )
                .foregroundStyle(DS.ColorToken.textSecondary)
                .frame(width: dsMetrics.controlSize(22))

            Text("Week starts on")
                .font(
                    dsMetrics.font(
                        15,
                        weight: .regular,
                        category: .body
                    )
                )
                .foregroundStyle(DS.ColorToken.textPrimary)
                .lineLimit(1)

            Spacer(minLength: dsMetrics.spacing(DS.Spacing.sm))

            weekStartPicker
        }
        .padding(.horizontal, dsMetrics.spacing(DS.Spacing.md))
        .padding(.vertical, dsMetrics.spacing(14))
        .contentShape(Rectangle())
    }

    private var weekStartPicker: some View {
        HStack(spacing: dsMetrics.spacing(4)) {
            weekStartSegment(
                title: String(localized: "Monday"),
                isSelected: viewModel.weekStartsOnMonday,
                action: {
                    guard viewModel.weekStartsOnMonday == false else { return }
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                        viewModel.setWeekStartsOnMonday(true)
                    }
                }
            )

            weekStartSegment(
                title: String(localized: "Sunday"),
                isSelected: viewModel.weekStartsOnMonday == false,
                action: {
                    guard viewModel.weekStartsOnMonday else { return }
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                        viewModel.setWeekStartsOnMonday(false)
                    }
                }
            )
        }
        .padding(dsMetrics.spacing(4))
        .dsSurface(Capsule(), fill: DS.Surface.frosted)
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
                    .font(
                        dsMetrics.font(
                            13,
                            weight: .semibold,
                            category: .micro
                        )
                    )
                    .foregroundStyle(isSelected ? Color.white : DS.ColorToken.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, dsMetrics.spacing(12))
                    .frame(height: dsMetrics.controlSize(32))
            }
        }
        .buttonStyle(.plain)
        .contentShape(Capsule())
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var calendarSection: some View {
        SettingsSection(
            title: String(localized: "Calendar"),
            footer: footerTextForCalendar
        ) {
            SettingsCard {
                SettingsRow(
                    title: String(localized: "Show tasks in Apple Calendar"),
                    subtitle: String(localized: "Keeps tasks synced in the “Task Planner” calendar"),
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
                    title: String(localized: "Show Apple Calendar events in Planner"),
                    subtitle: String(localized: "Shown in Planner only. Not saved in the app."),
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
                    title: String(localized: "Resync now"),
                    subtitle: String(localized: "Force sync current tasks to Apple Calendar"),
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
                    title: String(localized: "Remove exported events"),
                    subtitle: String(localized: "Turns off sync and deletes Task Planner events from Apple Calendar"),
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
        SettingsSection(title: String(localized: "Categories")) {
            SettingsCard {
                CategoryInputRow(
                    title: String(localized: "Add Category"),
                    showsProBadge: true,
                    action: handleAddCategoryEntryTap
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

    private var proSection: some View {
        SettingsSection(title: String(localized: "Task Planner Pro")) {
            SettingsCard {
                monetizationSummaryRow

                SettingsRowDivider()

                SettingsRow(
                    title: String(localized: "Restore Purchases"),
                    subtitle: String(localized: "Use this if you've already bought Pro."),
                    systemImage: "arrow.clockwise.circle",
                    action: {
                        Task {
                            monetizationNotice = await subscriptionStore.restorePurchases()
                        }
                    },
                    accessory: {
                        EmptyView()
                    }
                )

                SettingsRowDivider()

                SettingsRow(
                    title: String(localized: "Manage Subscription"),
                    subtitle: String(localized: "Open Apple's subscription settings."),
                    systemImage: "slider.horizontal.3",
                    action: {
                        Task {
                            monetizationNotice = await subscriptionStore.manageSubscription()
                        }
                    },
                    accessory: {
                        trailingChevron
                    }
                )
            }
        }
    }

    private var legalSection: some View {
        SettingsSection(title: String(localized: "Legal")) {
            SettingsCard {
                SettingsRow(
                    title: String(localized: "Privacy Policy"),
                    subtitle: String(localized: "How Task Planner handles your data."),
                    systemImage: "hand.raised",
                    action: {
                        openLegal(.privacyPolicy)
                    },
                    accessory: {
                        trailingChevron
                    }
                )

                SettingsRowDivider()

                SettingsRow(
                    title: String(localized: "Terms of Use"),
                    subtitle: String(localized: "Review the terms that apply to the app."),
                    systemImage: "doc.text",
                    action: {
                        openLegal(.termsOfUse)
                    },
                    accessory: {
                        trailingChevron
                    }
                )
            }
        }
    }

    private var monetizationSummaryRow: some View {
        Button {
            onOpenPaywall(.settings)
        } label: {
            HStack(alignment: .center, spacing: dsMetrics.spacing(DS.Spacing.sm)) {
                ProBadge(size: .regular)
                    .frame(
                        width: dsMetrics.controlSize(22),
                        height: dsMetrics.controlSize(22)
                    )

                VStack(alignment: .leading, spacing: dsMetrics.spacing(2)) {
                    Text(subscriptionStore.isPro ? String(localized: "Current plan") : String(localized: "Upgrade to Pro"))
                        .font(
                            dsMetrics.font(
                                15,
                                weight: .regular,
                                category: .body
                            )
                        )
                        .foregroundStyle(DS.ColorToken.textPrimary)
                        .multilineTextAlignment(.leading)

                    Text(subscriptionStore.planSummaryText)
                        .font(
                            dsMetrics.font(
                                12,
                                weight: .medium,
                                category: .caption
                            )
                        )
                        .foregroundStyle(DS.ColorToken.textSecondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: dsMetrics.spacing(DS.Spacing.sm))

                if subscriptionStore.isPro {
                    Text(subscriptionStore.currentPlanTitle)
                        .font(
                            dsMetrics.font(
                                12,
                                weight: .medium,
                                category: .caption
                            )
                        )
                        .foregroundStyle(DS.ColorToken.purple)
                        .padding(.horizontal, dsMetrics.spacing(10))
                        .padding(.vertical, dsMetrics.spacing(6))
                        .background(DS.ColorToken.purple.opacity(0.10), in: Capsule())
                } else {
                    trailingChevron
                }
            }
            .padding(.horizontal, dsMetrics.spacing(DS.Spacing.md))
            .padding(.vertical, dsMetrics.spacing(14))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var dataSection: some View {
        SettingsSection(
            title: String(localized: "Data"),
            footer: String(localized: "Use with caution. This action can't be undone.")
        ) {
            SettingsCard {
                SettingsRow(
                    title: String(localized: "Clear all tasks"),
                    subtitle: String(localized: "Remove all tasks and planner data from this device"),
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
            .font(
                dsMetrics.font(
                    13,
                    weight: .semibold,
                    category: .micro
                )
            )
            .foregroundStyle(DS.ColorToken.textSecondary.opacity(0.9))
    }

    @ViewBuilder
    private func trailingValueChevron(_ value: String) -> some View {
        HStack(spacing: 6) {
            if !value.isEmpty {
                Text(value)
                    .font(
                        dsMetrics.font(
                            15,
                            weight: .regular,
                            category: .body
                        )
                    )
                    .foregroundStyle(DS.ColorToken.textSecondary)
                    .lineLimit(1)
            }

            trailingChevron
        }
    }

    private func rowValueLabel(_ value: String) -> some View {
        HStack(spacing: dsMetrics.spacing(6)) {
            Text(value)
                .font(
                    dsMetrics.font(
                        15,
                        weight: .regular,
                        category: .body
                    )
                )
                .foregroundStyle(DS.ColorToken.textSecondary)

            Image(systemName: "chevron.up.chevron.down")
                .font(
                    dsMetrics.font(
                        10,
                        weight: .semibold,
                        category: .micro
                    )
                )
                .foregroundStyle(DS.ColorToken.textSecondary.opacity(0.85))
        }
        .padding(.vertical, dsMetrics.spacing(6))
        .padding(.horizontal, dsMetrics.spacing(10))
        .background(DS.ColorToken.controlFill, in: Capsule())
    }

    private func handleAddCategoryEntryTap() {
        guard subscriptionStore.hasAccess(to: .customCategories) else {
            onOpenPaywall(.customCategories)
            return
        }

        viewModel.prepareForNewCategory()
        showAddCategoryPrompt = true
    }

    private func confirmAddCategory() {
        let trimmed = viewModel.newCategoryTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            viewModel.prepareForNewCategory()
            return
        }

        viewModel.addCategory()
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }

    private func openLegal(_ link: SubscriptionLegalLink) {
        guard let url = link.url(from: subscriptionStore.catalog) else {
            monetizationNotice = MonetizationNotice(
                title: link.title,
                message: link.unavailableMessage
            )
            return
        }

        openURL(url)
    }
}
