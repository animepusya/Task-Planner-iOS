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

    @Query(sort: \CategoryEntity.title, order: .forward)
    private var categories: [CategoryEntity]

    private let fallbackCategories = ["Work", "Study", "Hobby"]
    @FocusState private var focusedField: TaskEditorField?

    private var availableCategoryTitles: [String] {
        let list = categories
            .filter { $0.id != CategorySystem.uncategorizedId }
            .map { $0.title }

        return list.isEmpty ? fallbackCategories : list
    }

    var body: some View {
        root
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
            }
            .onChange(of: categories.count) { _, _ in
                viewModel.ensureCategoryIsValid(available: availableCategoryTitles)
            }
    }

    // MARK: - Subviews

    private var root: some View {
        VStack(spacing: 0) {
            topBar
            content
        }
    }

    private var topBar: some View {
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
    }

    private var content: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                nameSection
                dateTimeSection
                TaskEditorColorSection(color: viewModel.binding(\.color))
                repeatSection
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.top, DS.Spacing.lg)
            .padding(.bottom, 28)
        }
        .scrollDismissesKeyboard(.interactively)
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

    private var dateTimeSection: some View {
        TaskEditorDateTimeSection(
            dayDate: viewModel.dayDateBinding,
            endDayDate: viewModel.endDayDateBinding,
            startTime: viewModel.startTimeBinding,
            endTime: viewModel.endTimeBinding,
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

    // MARK: - Actions

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
