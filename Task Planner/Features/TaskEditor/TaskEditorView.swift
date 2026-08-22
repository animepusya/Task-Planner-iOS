//
//  TaskEditorView.swift
//  Task Planner
//
//  Created by Руслан Меланин on 09.02.2026.
//

import SwiftData
import SwiftUI

struct TaskEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var subscriptionStore: SubscriptionStore

    @State private var viewModel: TaskEditorViewModel
    @StateObject private var chrome: TaskEditorViewModel.ChromeState
    @StateObject private var visibility: TaskEditorViewModel.VisibilityState
    @StateObject private var alertState: TaskEditorViewModel.AlertState
    @State private var navigationPath: [TaskEditorRoute] = []
    @State private var pendingLockedSource: TaskCreationSourceCandidate?
    @State private var showsLockedSourceOptions = false

    let onOpenNotificationsCenter: () -> Void

    @Query(sort: \CategoryEntity.title, order: .forward)
    private var categories: [CategoryEntity]

    @Query
    private var preferences: [AppPreferencesEntity]

    @FocusState private var focusedField: TaskEditorField?

    init(
        viewModel: TaskEditorViewModel,
        onOpenNotificationsCenter: @escaping () -> Void
    ) {
        _viewModel = State(initialValue: viewModel)
        _chrome = StateObject(wrappedValue: viewModel.chrome)
        _visibility = StateObject(wrappedValue: viewModel.visibility)
        _alertState = StateObject(wrappedValue: viewModel.alertState)
        self.onOpenNotificationsCenter = onOpenNotificationsCenter
    }

    init(
        taskRepository: TaskRepository,
        preferencesRepository: PreferencesRepository,
        notificationService: NotificationService,
        seriesService: TaskSeriesService,
        taskId: PersistentIdentifier?,
        preselectedDay: Date,
        editMode: TaskEditorMode,
        onOpenNotificationsCenter: @escaping () -> Void
    ) {
        let wrappedViewModel = TaskEditorViewModel(
            taskRepository: taskRepository,
            preferencesRepository: preferencesRepository,
            notificationService: notificationService,
            seriesService: seriesService,
            taskId: taskId,
            preselectedDay: preselectedDay,
            editMode: editMode
        )

        _viewModel = State(initialValue: wrappedViewModel)
        _chrome = StateObject(wrappedValue: wrappedViewModel.chrome)
        _visibility = StateObject(wrappedValue: wrappedViewModel.visibility)
        _alertState = StateObject(wrappedValue: wrappedViewModel.alertState)
        self.onOpenNotificationsCenter = onOpenNotificationsCenter
    }

    private var availableCategoryTitles: [String] {
        CategorySystem.selectableTitles(from: categories)
    }

    private var appNotificationsEnabled: Bool {
        preferences.first?.notificationsEnabled ?? true
    }

    var body: some View {
        DSAdaptiveLayoutScope { metrics in
            NavigationStack(path: $navigationPath) {
                GeometryReader { proxy in
                    let layout = TaskEditorLayoutMetrics(
                        width: proxy.size.width,
                        adaptiveMetrics: metrics
                    )

                    VStack(spacing: 0) {
                        TaskEditorTopBar(
                            state: chrome,
                            onBack: {
                                dismissKeyboard()
                                dismiss()
                            },
                            onSaveNormal: {
                                dismissKeyboard()
                                saveNormal()
                            },
                            onSaveOnlyThisDay: {
                                dismissKeyboard()
                                saveScoped(.onlyThisDay)
                            },
                            onSaveAllFuture: {
                                dismissKeyboard()
                                saveScoped(.allFutureDays)
                            }
                        )
                        .frame(width: layout.contentWidth)
                        .padding(.horizontal, layout.horizontalPadding)
                        .padding(.vertical, metrics.spacing(10))

                        TaskEditorContentView(
                            layout: layout,
                            visibility: visibility.content,
                            viewModel: viewModel,
                            fixedCategoryChipWidth: metrics.isLargePad ? 220 : 132,
                            focusedField: $focusedField,
                            canChooseCreationSource: viewModel.isEditing == false,
                            isAdvancedRepeatLocked: subscriptionStore.isLocked(.advancedRepeats),
                            onLoadCreationSources: viewModel.loadCreationSourcesIfNeeded,
                            onRequestCreationSources: openCreationSourcePicker,
                            onRequestStatisticsLinkSources: openStatisticsLinkPicker,
                            onSelectCreationSource: handleCreationSourceSelection,
                            onSelectDuplicateTitleStatisticsSource: viewModel.selectStatisticsLinkSource,
                            onDismissDuplicateTitleSuggestion: viewModel.dismissDuplicateTitleSuggestion,
                            onSetStatisticsLinkEnabled: viewModel.setCreationSourceStatisticsLinkEnabled,
                            onRequestRepeatUnlock: {
                                navigationPath.append(.paywall(.advancedRepeats))
                            },
                            onOpenNotificationsCenter: {
                                dismissKeyboard()
                                onOpenNotificationsCenter()
                            }
                        )
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .background(DS.ColorToken.appBackground.ignoresSafeArea())
                    .taskEditorDismissKeyboardOnTap {
                        focusedField = nil
                    }
                    .toolbar(.hidden, for: .navigationBar)
                    .toolbar {
                        if focusedField == .description {
                            ToolbarItemGroup(placement: .keyboard) {
                                Spacer()
                                Button("Done") {
                                    dismissKeyboard()
                                }
                            }
                        }
                    }
                    .alert(item: $alertState.alert) { alert in
                        Alert(
                            title: Text(alert.title),
                            message: Text(alert.message),
                            dismissButton: .cancel(Text("Close")) { dismiss() }
                        )
                    }
                    .task {
                        viewModel.onAppear(availableCategories: availableCategoryTitles)
                        viewModel.onAppNotificationsEnabledChanged(appNotificationsEnabled)
                    }
                    .onChange(of: availableCategoryTitles) { _, newValue in
                        viewModel.ensureCategoryIsValid(available: newValue)
                    }
                    .onChange(of: appNotificationsEnabled) { _, newValue in
                        viewModel.onAppNotificationsEnabledChanged(newValue)
                    }
                }
                .navigationDestination(for: TaskEditorRoute.self) { route in
                    switch route {
                    case .creationSourcePicker:
                        TaskCreationSourcePicker(
                            state: viewModel.creationSourceState,
                            isAdvancedRepeatLocked: subscriptionStore.isLocked(.advancedRepeats),
                            onSelect: handleCreationSourceSelection
                        )
                    case .statisticsLinkPicker(let query):
                        TaskCreationSourcePicker(
                            state: viewModel.creationSourceState,
                            initialQuery: query,
                            navigationTitle: String(localized: "Count together"),
                            isAdvancedRepeatLocked: false,
                            trailingSystemName: "link",
                            onSelect: applyStatisticsLinkSource
                        )
                    case .paywall(let entryPoint):
                        PaywallView(entryPoint: entryPoint)
                    }
                }
            }
        }
        .confirmationDialog(
            "This task uses a Pro repeat",
            isPresented: $showsLockedSourceOptions,
            presenting: pendingLockedSource
        ) { candidate in
            Button("Upgrade to Pro") {
                pendingLockedSource = nil
                navigationPath.append(.paywall(.advancedRepeats))
            }

            Button("Copy without repeat") {
                pendingLockedSource = nil
                applyCreationSource(candidate, includeRepeatRule: false)
            }

            Button("Cancel", role: .cancel) {
                pendingLockedSource = nil
            }
        } message: { _ in
            Text("Copy all settings by opening Pro, or copy without the repeat rule.")
        }
        .onChange(of: subscriptionStore.isRefreshing) { _, isRefreshing in
            guard isRefreshing == false, let candidate = pendingLockedSource else { return }

            if subscriptionStore.isPro {
                pendingLockedSource = nil
                applyCreationSource(candidate, includeRepeatRule: true)
            } else {
                showsLockedSourceOptions = true
            }
        }
    }

    private func dismissKeyboard() {
        focusedField = nil
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func openCreationSourcePicker() {
        dismissKeyboard()
        viewModel.loadCreationSourcesIfNeeded()

        guard navigationPath.last != .creationSourcePicker else { return }
        navigationPath.append(.creationSourcePicker)
    }

    private func openStatisticsLinkPicker() {
        dismissKeyboard()
        viewModel.loadStatisticsLinkSourcesIfNeeded()

        let route = TaskEditorRoute.statisticsLinkPicker(
            query: viewModel.creationSourceState.currentTitleQuery
        )
        guard navigationPath.last != route else { return }
        navigationPath.append(route)
    }

    private func applyStatisticsLinkSource(_ candidate: TaskCreationSourceCandidate) {
        viewModel.selectStatisticsLinkSource(candidate)
        dismissKeyboard()

        if let lastRoute = navigationPath.last,
           case .statisticsLinkPicker = lastRoute {
            navigationPath.removeLast()
        }
    }

    private func handleCreationSourceSelection(_ candidate: TaskCreationSourceCandidate) {
        if candidate.repeatRule.requiresProAccess,
           subscriptionStore.isLocked(.advancedRepeats) {
            pendingLockedSource = candidate

            if subscriptionStore.isRefreshing == false {
                showsLockedSourceOptions = true
            }
            return
        }

        applyCreationSource(candidate, includeRepeatRule: true)
    }

    private func applyCreationSource(
        _ candidate: TaskCreationSourceCandidate,
        includeRepeatRule: Bool
    ) {
        guard viewModel.applyCreationSource(
            candidate,
            includeRepeatRule: includeRepeatRule
        ) else {
            return
        }

        dismissKeyboard()
        if navigationPath.last == .creationSourcePicker {
            navigationPath.removeLast()
        }
    }

    private func saveNormal() {
        viewModel.isBusy = true
        defer { viewModel.isBusy = false }

        do {
            try viewModel.saveNormal()
            dismiss()
        } catch let error as TaskEditorViewModel.EditorError {
            switch error {
            case .repeatConflict:
                return
            default:
                viewModel.alert = .init(title: String(localized: "Couldn't save"), message: error.localizedDescription)
            }
        } catch {
            viewModel.alert = .init(title: String(localized: "Couldn't save"), message: error.localizedDescription)
        }
    }

    private func saveScoped(_ scope: TaskSeriesService.Scope) {
        viewModel.isBusy = true
        defer { viewModel.isBusy = false }

        do {
            try viewModel.saveWithScope(scope)
            dismiss()
        } catch let error as TaskEditorViewModel.EditorError {
            switch error {
            case .repeatConflict:
                return
            default:
                viewModel.alert = .init(title: String(localized: "Couldn't save"), message: error.localizedDescription)
            }
        } catch {
            viewModel.alert = .init(title: String(localized: "Couldn't save"), message: error.localizedDescription)
        }
    }
}

private struct TaskEditorContentView: View {
    @Environment(\.dsAdaptiveMetrics) private var dsMetrics

    let layout: TaskEditorLayoutMetrics
    let visibility: TaskEditorViewModel.VisibilityState.Content
    let viewModel: TaskEditorViewModel
    let fixedCategoryChipWidth: CGFloat

    @FocusState.Binding var focusedField: TaskEditorField?

    let canChooseCreationSource: Bool
    let isAdvancedRepeatLocked: Bool
    let onLoadCreationSources: () -> Void
    let onRequestCreationSources: () -> Void
    let onRequestStatisticsLinkSources: () -> Void
    let onSelectCreationSource: (TaskCreationSourceCandidate) -> Void
    let onSelectDuplicateTitleStatisticsSource: (TaskCreationSourceCandidate) -> Void
    let onDismissDuplicateTitleSuggestion: () -> Void
    let onSetStatisticsLinkEnabled: (Bool) -> Void
    let onRequestRepeatUnlock: () -> Void
    let onOpenNotificationsCenter: () -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: dsMetrics.spacing(DS.Spacing.lg)) {
                if visibility.showsNameSection {
                    TaskEditorNameSection(
                        titleState: viewModel.titleSection,
                        descriptionState: viewModel.descriptionSection,
                        creationSourceState: viewModel.creationSourceState,
                        fixedCategoryChipWidth: fixedCategoryChipWidth,
                        focusedField: $focusedField,
                        showsTitleAndCategory: visibility.showsTitleAndCategory,
                        showsNotesEditor: visibility.showsNotesEditor,
                        canChooseCreationSource: canChooseCreationSource,
                        isAdvancedRepeatLocked: isAdvancedRepeatLocked,
                        onLoadCreationSources: onLoadCreationSources,
                        onRequestCreationSources: onRequestCreationSources,
                        onRequestStatisticsLinkSources: onRequestStatisticsLinkSources,
                        onSelectCreationSource: onSelectCreationSource,
                        onSelectDuplicateTitleStatisticsSource: onSelectDuplicateTitleStatisticsSource,
                        onDismissDuplicateTitleSuggestion: onDismissDuplicateTitleSuggestion,
                        onSetStatisticsLinkEnabled: onSetStatisticsLinkEnabled
                    )
                }

                if visibility.showsDateTimeSection {
                    TaskEditorDateTimeSection(
                        state: viewModel.dateTimeSection,
                        availableWidth: layout.contentWidth,
                        onApplyDuration: viewModel.applyDuration(minutes:)
                    )
                }

                if visibility.showsReminderSection {
                    TaskEditorReminderSection(
                        state: viewModel.reminderSection,
                        dateTimeState: viewModel.dateTimeSection,
                        onOpenNotificationsCenter: onOpenNotificationsCenter,
                        onOpenSystemSettings: viewModel.openSystemSettings
                    )
                }

                if visibility.showsColorSection {
                    TaskEditorColorSection(state: viewModel.colorSection)
                }

                if visibility.showsRepeatSection {
                    TaskEditorRepeatSection(
                        state: viewModel.repeatSection,
                        isAdvancedRepeatLocked: isAdvancedRepeatLocked,
                        onRequestUnlock: onRequestRepeatUnlock
                    )
                }

                if visibility.showsPhotoSection {
                    TaskEditorPhotoSection(state: viewModel.photoSection)
                }
            }
            .frame(width: layout.contentWidth, alignment: .leading)
            .padding(.horizontal, layout.horizontalPadding)
            .padding(.top, dsMetrics.spacing(DS.Spacing.lg))
            .padding(.bottom, dsMetrics.spacing(28))
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

private struct TaskEditorLayoutMetrics {
    let horizontalPadding: CGFloat
    let contentWidth: CGFloat

    init(width: CGFloat, adaptiveMetrics: DSAdaptiveMetrics) {
        let metrics = Self.resolveLayout(width: width, adaptiveMetrics: adaptiveMetrics)
        horizontalPadding = metrics.horizontalPadding
        contentWidth = metrics.contentWidth
    }

    private static func resolveLayout(
        width: CGFloat,
        adaptiveMetrics: DSAdaptiveMetrics
    ) -> (horizontalPadding: CGFloat, contentWidth: CGFloat) {
        let basePadding: CGFloat
        if width < 375 {
            basePadding = adaptiveMetrics.screenPadding(DS.Spacing.md)
        } else if width < 430 {
            basePadding = adaptiveMetrics.screenPadding(DS.Spacing.lg)
        } else {
            basePadding = adaptiveMetrics.screenPadding(DS.Spacing.xl)
        }

        let availableWidth = max(0, width - basePadding * 2)
        let contentWidth = min(
            availableWidth,
            adaptiveMetrics.maxWidth(for: .modal) ?? availableWidth
        )
        let horizontalPadding = max(basePadding, (width - contentWidth) / 2)
        return (horizontalPadding, contentWidth)
    }
}

private enum TaskEditorRoute: Hashable {
    case creationSourcePicker
    case statisticsLinkPicker(query: String)
    case paywall(PaywallEntryPoint)
}
