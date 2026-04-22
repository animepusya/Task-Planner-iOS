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
                            isAdvancedRepeatLocked: subscriptionStore.isLocked(.advancedRepeats),
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
                    case .paywall(let entryPoint):
                        PaywallView(entryPoint: entryPoint)
                    }
                }
            }
        }
    }

    private func dismissKeyboard() {
        focusedField = nil
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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

    let isAdvancedRepeatLocked: Bool
    let onRequestRepeatUnlock: () -> Void
    let onOpenNotificationsCenter: () -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: dsMetrics.spacing(DS.Spacing.lg)) {
                if visibility.showsNameSection {
                    TaskEditorNameSection(
                        titleState: viewModel.titleSection,
                        descriptionState: viewModel.descriptionSection,
                        fixedCategoryChipWidth: fixedCategoryChipWidth,
                        focusedField: $focusedField,
                        showsTitleAndCategory: visibility.showsTitleAndCategory,
                        showsNotesEditor: visibility.showsNotesEditor
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
    case paywall(PaywallEntryPoint)
}
