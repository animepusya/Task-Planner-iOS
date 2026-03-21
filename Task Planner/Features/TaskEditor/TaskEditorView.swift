//
//  TaskEditorView.swift
//  Task Planner
//
//  Created by Руслан Меланин on 09.02.2026.
//

import SwiftUI
import SwiftData

struct TaskEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: TaskEditorViewModel

    let onOpenNotificationsCenter: () -> Void

    @Query(sort: \CategoryEntity.title, order: .forward)
    private var categories: [CategoryEntity]

    @Query
    private var preferences: [AppPreferencesEntity]

    private let fallbackCategories = ["Work", "Study", "Hobby"]
    @FocusState private var focusedField: TaskEditorField?

    init(
        viewModel: TaskEditorViewModel,
        onOpenNotificationsCenter: @escaping () -> Void
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
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
        _viewModel = StateObject(
            wrappedValue: TaskEditorViewModel(
                taskRepository: taskRepository,
                preferencesRepository: preferencesRepository,
                notificationService: notificationService,
                seriesService: seriesService,
                taskId: taskId,
                preselectedDay: preselectedDay,
                editMode: editMode
            )
        )
        self.onOpenNotificationsCenter = onOpenNotificationsCenter
    }

    private var availableCategoryTitles: [String] {
        let list = categories
            .filter { $0.id != CategorySystem.uncategorizedId }
            .map { $0.title }

        return list.isEmpty ? fallbackCategories : list
    }

    private var appNotificationsEnabled: Bool {
        preferences.first?.notificationsEnabled ?? true
    }

    var body: some View {
        GeometryReader { proxy in
            let pad = adaptiveHorizontalPadding(for: proxy.size.width)
            let contentWidth = max(0, proxy.size.width - pad * 2)
            let isCompact = proxy.size.width < 375

            VStack(spacing: 0) {
                TaskEditorTopBar(
                    title: viewModel.navigationTitle,
                    isBusy: viewModel.isBusy,
                    onBack: {
                        dismissKeyboard()
                        dismiss()
                    },
                    canSave: viewModel.canSave,
                    showSaveScopeMenu: viewModel.requiresScopeMenuOnSave,
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
                .frame(width: contentWidth)
                .padding(.horizontal, pad)
                .padding(.vertical, 10)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                        if viewModel.showsNameSection {
                            nameSection
                        }

                        if viewModel.showsDateTimeSection {
                            dateTimeSection(isCompact: isCompact)
                        }

                        if viewModel.showsReminderSection {
                            TaskEditorReminderSection(
                                reminderEnabled: viewModel.reminderEnabledBinding,
                                reminderOffsetMinutes: viewModel.binding(\.reminderOffsetMinutes),
                                reminderAllDayTimeMinutes: viewModel.binding(\.reminderAllDayTimeMinutes),
                                isAllDay: viewModel.form.isAllDay,
                                defaultAllDayTimeMinutes: viewModel.defaultAllDayTimeMinutes,
                                gate: viewModel.reminderGate,
                                onOpenNotificationsCenter: {
                                    dismissKeyboard()
                                    onOpenNotificationsCenter()
                                },
                                onOpenSystemSettings: {
                                    viewModel.openSystemSettings()
                                }
                            )
                        }

                        if viewModel.showsColorSection {
                            TaskEditorColorSection(color: viewModel.binding(\.color))
                        }

                        if viewModel.showsRepeatSection {
                            repeatSection
                        }

                        if viewModel.showsPhotoSection {
                            TaskEditorPhotoSection(thumbData: viewModel.binding(\.photoThumbData))
                        }
                    }
                    .frame(width: contentWidth, alignment: .leading)
                    .padding(.horizontal, pad)
                    .padding(.top, DS.Spacing.lg)
                    .padding(.bottom, 28)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .background(DS.ColorToken.appBackground.ignoresSafeArea())
            .taskEditorDismissKeyboardOnTap {
                focusedField = nil
            }
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
            .alert(item: $viewModel.alert) { alert in
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
            .onChange(of: categories.count) { _, _ in
                viewModel.ensureCategoryIsValid(available: availableCategoryTitles)
            }
            .onChange(of: appNotificationsEnabled) { _, newValue in
                viewModel.onAppNotificationsEnabledChanged(newValue)
            }
        }
    }

    private func adaptiveHorizontalPadding(for width: CGFloat) -> CGFloat {
        if width < 375 { return DS.Spacing.md }
        if width < 430 { return DS.Spacing.lg }
        return DS.Spacing.xl
    }

    private var nameSection: some View {
        TaskEditorNameSection(
            title: viewModel.binding(\.title),
            categoryTitle: viewModel.binding(\.categoryTitle),
            notes: viewModel.binding(\.notes),
            availableCategories: availableCategoryTitles,
            fixedCategoryChipWidth: 132,
            focusedField: $focusedField,
            showsTitleAndCategory: viewModel.showsTitleAndCategory,
            showsNotesEditor: viewModel.showsNotesEditor
        )
    }

    private func dateTimeSection(isCompact: Bool) -> some View {
        TaskEditorDateTimeSection(
            dayDate: viewModel.dayDateBinding,
            endDayDate: viewModel.endDayDateBinding,
            startTime: viewModel.startTimeBinding,
            endTime: viewModel.endTimeBinding,
            isAllDay: viewModel.isAllDayBinding,
            timeValidationMessage: viewModel.form.timeValidationMessage,
            onApplyDuration: { minutes in
                viewModel.applyDuration(minutes: minutes)
            }
        )
    }

    private var repeatSection: some View {
        TaskEditorRepeatSection(
            repeatRule: viewModel.repeatRuleBinding,
            repeatIntervalDays: viewModel.repeatIntervalDaysBinding,
            isInvalid: viewModel.form.isRepeatInvalid,
            validationMessage: viewModel.form.repeatValidationMessage
        )
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
        } catch let e as TaskEditorViewModel.EditorError {
            switch e {
            case .repeatConflict:
                return
            default:
                viewModel.alert = .init(title: "Can't save", message: e.localizedDescription)
            }
        } catch {
            viewModel.alert = .init(title: "Can't save", message: error.localizedDescription)
        }
    }

    private func saveScoped(_ scope: TaskSeriesService.Scope) {
        viewModel.isBusy = true
        defer { viewModel.isBusy = false }

        do {
            try viewModel.saveWithScope(scope)
            dismiss()
        } catch let e as TaskEditorViewModel.EditorError {
            switch e {
            case .repeatConflict:
                return
            default:
                viewModel.alert = .init(title: "Can't save", message: e.localizedDescription)
            }
        } catch {
            viewModel.alert = .init(title: "Can't save", message: error.localizedDescription)
        }
    }
}
