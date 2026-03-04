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
    @StateObject var viewModel: TaskEditorViewModel

    let onOpenNotificationsCenter: () -> Void

    @Query(sort: \CategoryEntity.title, order: .forward)
    private var categories: [CategoryEntity]

    @Query
    private var preferences: [AppPreferencesEntity]

    private let fallbackCategories = ["Work", "Study", "Hobby"]
    @FocusState private var focusedField: TaskEditorField?

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
                        focusedField = nil
                        dismiss()
                    },
                    onSave: {
                        focusedField = nil
                        save()
                    },
                    canSave: viewModel.canSave
                )
                .frame(width: contentWidth)
                .padding(.horizontal, pad)
                .padding(.vertical, 10)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                        nameSection
                        dateTimeSection(isCompact: isCompact)

                        TaskEditorReminderSection(
                            reminderEnabled: viewModel.reminderEnabledBinding,
                            reminderOffsetMinutes: viewModel.binding(\.reminderOffsetMinutes),
                            reminderAllDayTimeMinutes: viewModel.binding(\.reminderAllDayTimeMinutes),
                            isAllDay: viewModel.form.isAllDay,
                            defaultAllDayTimeMinutes: viewModel.defaultAllDayTimeMinutes,
                            gate: viewModel.reminderGate,
                            onOpenNotificationsCenter: {
                                focusedField = nil
                                onOpenNotificationsCenter()
                            },
                            onOpenSystemSettings: {
                                viewModel.openSystemSettings()
                            }
                        )

                        TaskEditorColorSection(color: viewModel.binding(\.color))
                        repeatSection
                        TaskEditorPhotoSection(thumbData: viewModel.binding(\.photoThumbData))
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
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
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
            focusedField: $focusedField
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

    private func save() {
        viewModel.isBusy = true
        defer { viewModel.isBusy = false }

        do {
            try viewModel.save()
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
