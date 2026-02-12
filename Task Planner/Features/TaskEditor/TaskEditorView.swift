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
    @State private var showAlert = false

    private var availableCategoryTitles: [String] {
        let list = categories
            .filter { $0.id != CategorySystem.uncategorizedId }
            .map { $0.title }

        return list.isEmpty ? fallbackCategories : list
    }

    var body: some View {
        root
            .background(DS.ColorToken.appBackground.ignoresSafeArea())
            .alert(viewModel.alertTitle ?? "Error", isPresented: $showAlert) {
                Button("Close", role: .cancel) { dismiss() }
            } message: {
                Text(viewModel.alertMessage ?? "")
            }
            .onChange(of: viewModel.alertTitle) { _, newValue in
                showAlert = (newValue != nil)
            }
            .onAppear {
                viewModel.onAppear(availableCategories: availableCategoryTitles)
            }
            .onChange(of: categories) { _, _ in
                viewModel.ensureCategoryIsValid(available: availableCategoryTitles)
            }
            .onChange(of: viewModel.dayDate) { _, _ in viewModel.onStartDayChanged() }
            .onChange(of: viewModel.startTime) { _, _ in viewModel.onStartTimeChanged() }
            .onChange(of: viewModel.endDayDate) { _, _ in viewModel.onEndDayChanged(triggerFeedback: true) }
            .onChange(of: viewModel.endTime) { _, _ in viewModel.onEndTimeChanged() }
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
            onBack: { dismiss() },
            onSave: { save() },
            canSave: viewModel.canSave
        )
    }

    private var content: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                nameSection
                dateTimeSection
                TaskEditorColorSection(color: $viewModel.color)
                repeatSection
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.top, DS.Spacing.lg)
            .padding(.bottom, 28)
        }
    }

    private var nameSection: some View {
        TaskEditorNameSection(
            title: $viewModel.title,
            categoryTitle: $viewModel.categoryTitle,
            notes: $viewModel.notes,
            availableCategories: availableCategoryTitles,
            fixedCategoryChipWidth: 132
        )
    }

    private var dateTimeSection: some View {
        TaskEditorDateTimeSection(
            dayDate: $viewModel.dayDate,
            endDayDate: $viewModel.endDayDate,
            startTime: $viewModel.startTime,
            endTime: $viewModel.endTime,
            timeValidationMessage: viewModel.timeValidationMessage,
            onApplyDuration: { minutes in
                viewModel.applyDuration(minutes: minutes)
            }
        )
    }

    private var repeatSection: some View {
        TaskEditorRepeatSection(
            repeatRule: $viewModel.repeatRule,
            repeatIntervalDays: $viewModel.repeatIntervalDays,
            isInvalid: viewModel.isRepeatInvalid,
            validationMessage: viewModel.repeatValidationMessage
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
                // ✅ no alert, keep user on screen; UI already shows inline error
                return
            default:
                viewModel.alertTitle = "Can't save"
                viewModel.alertMessage = e.localizedDescription
                showAlert = true
            }
        } catch {
            viewModel.alertTitle = "Can't save"
            viewModel.alertMessage = error.localizedDescription
            showAlert = true
        }
    }
}
