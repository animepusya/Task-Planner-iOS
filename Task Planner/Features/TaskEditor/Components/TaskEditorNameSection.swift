//
//  TaskEditorNameSection.swift
//  Task Planner
//
//  Created by Руслан Меланин on 11.02.2026.
//

import SwiftUI

struct TaskEditorNameSection: View {
    @Environment(\.dsAdaptiveMetrics) private var dsMetrics

    let titleState: TaskEditorViewModel.TitleSectionState
    let descriptionState: TaskEditorViewModel.DescriptionSectionState
    @ObservedObject var creationSourceState: TaskEditorViewModel.CreationSourceState
    let fixedCategoryChipWidth: CGFloat

    @FocusState.Binding var focusedField: TaskEditorField?
    let showsTitleAndCategory: Bool
    let showsNotesEditor: Bool
    let canChooseCreationSource: Bool
    let isAdvancedRepeatLocked: Bool
    let onLoadCreationSources: () -> Void
    let onRequestCreationSources: () -> Void
    let onRequestStatisticsLinkSources: () -> Void
    let onSelectCreationSource: (TaskCreationSourceCandidate) -> Void
    let onSelectDuplicateTitleStatisticsSource: (TaskCreationSourceCandidate) -> Void
    let onDismissDuplicateTitleSuggestion: () -> Void
    let onSetStatisticsLinkEnabled: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: dsMetrics.spacing(DS.Spacing.sm)) {
            if showsTitleAndCategory {
                TaskEditorTitleRow(
                    state: titleState,
                    creationSourceState: creationSourceState,
                    fixedCategoryChipWidth: fixedCategoryChipWidth,
                    focusedField: $focusedField,
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

            if showsNotesEditor {
                TaskEditorDescriptionEditor(
                    state: descriptionState,
                    focusedField: $focusedField,
                    expandsByDefault: !showsTitleAndCategory
                )
            }
        }
        .dsCard(style: .outlined)
    }
}

private struct TaskEditorTitleRow: View {
    @Environment(\.dsAdaptiveMetrics) private var dsMetrics

    @ObservedObject var state: TaskEditorViewModel.TitleSectionState
    @ObservedObject var creationSourceState: TaskEditorViewModel.CreationSourceState

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

    var body: some View {
        VStack(alignment: .leading, spacing: dsMetrics.spacing(DS.Spacing.sm)) {
            HStack(spacing: dsMetrics.spacing(8)) {
                Text("Task Name")
                    .font(
                        dsMetrics.font(
                            12,
                            weight: .medium,
                            category: .caption
                        )
                    )
                    .foregroundStyle(DS.ColorToken.textSecondary)

                Spacer()

                if canChooseCreationSource {
                    creationSourceActions
                }
            }

            HStack(spacing: dsMetrics.spacing(10)) {
                TextField("Enter title", text: state.titleBinding)
                    .font(
                        dsMetrics.font(
                            15,
                            weight: .regular,
                            category: .body
                        )
                    )
                    .textInputAutocapitalization(.sentences)
                    .disableAutocorrection(false)
                    .submitLabel(.done)
                    .focused($focusedField, equals: .title)
                    .onSubmit {
                        focusedField = nil
                    }

                categoryMenuChip
            }
            .padding(.vertical, dsMetrics.spacing(4))

            if shouldShowSuggestions {
                suggestions
            }

            if creationSourceState.shouldShowStatisticsLinkStatus {
                statisticsLinkStatus
            }

            if let errorMessage = creationSourceState.loadErrorMessage {
                Text(errorMessage)
                    .font(dsMetrics.font(12, weight: .medium, category: .caption))
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onChange(of: focusedField) { _, newValue in
            if newValue == .title, canChooseCreationSource {
                onLoadCreationSources()
            }
        }
    }

    private var statisticsLinkStatus: some View {
        VStack(alignment: .leading, spacing: dsMetrics.spacing(8)) {
            Divider()

            HStack(alignment: .top, spacing: dsMetrics.spacing(10)) {
                Image(systemName: "link")
                    .foregroundStyle(
                        creationSourceState.isStatisticsLinkEnabled
                            ? DS.ColorToken.purple
                            : DS.ColorToken.textSecondary
                    )
                    .frame(width: dsMetrics.controlSize(18))
                    .scaleEffect(creationSourceState.isStatisticsLinkEnabled ? 1.0 : 0.94)
                    .animation(
                        .easeInOut(duration: 0.18),
                        value: creationSourceState.isStatisticsLinkEnabled
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: dsMetrics.spacing(4)) {
                    Text(statisticsLinkTitle)
                        .font(dsMetrics.font(12, weight: .semibold, category: .caption))
                        .foregroundStyle(DS.ColorToken.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: dsMetrics.spacing(14)) {
                        if creationSourceState.isStatisticsLinkEnabled {
                            Button("Keep separate") {
                                onSetStatisticsLinkEnabled(false)
                            }

                            Button("Change") {
                                focusedField = nil
                                onRequestStatisticsLinkSources()
                            }
                        } else if creationSourceState.canEnableStatisticsLink {
                            Button("Count together") {
                                onSetStatisticsLinkEnabled(true)
                            }

                            Button("Change") {
                                focusedField = nil
                                onRequestStatisticsLinkSources()
                            }
                        } else {
                            Button("Choose a task") {
                                focusedField = nil
                                onRequestStatisticsLinkSources()
                            }
                        }
                    }
                    .font(dsMetrics.font(12, weight: .semibold, category: .caption))
                    .foregroundStyle(DS.ColorToken.purple)
                    .buttonStyle(.plain)
                }

                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var statisticsLinkTitle: String {
        guard creationSourceState.isStatisticsLinkEnabled,
              let displayTitle = creationSourceState.statisticsLinkDisplayTitle else {
            return String(localized: "Separate in statistics")
        }

        return String.localizedStringWithFormat(
            String(localized: "Together with “%@” in statistics"),
            displayTitle
        )
    }

    @ViewBuilder
    private var creationSourceActions: some View {
        Group {
            if creationSourceState.selectedSource == nil {
                Button {
                    focusedField = nil
                    onRequestCreationSources()
                } label: {
                    Label("Fill task", systemImage: "doc.on.doc")
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            } else {
                Button {
                    focusedField = nil
                    onRequestCreationSources()
                } label: {
                    Label("Change", systemImage: "doc.on.doc")
                }
            }
        }
        .font(dsMetrics.font(12, weight: .semibold, category: .caption))
        .foregroundStyle(DS.ColorToken.purple)
        .buttonStyle(.plain)
    }

    private var shouldShowSuggestions: Bool {
        canChooseCreationSource
            && focusedField == .title
            && creationSourceState.selectedSource == nil
            && creationSourceState.statisticsLinkSource == nil
            && creationSourceState.hasMeaningfulQuery
    }

    @ViewBuilder
    private var suggestions: some View {
        Divider()

        if creationSourceState.duplicateTitleCandidates.isEmpty == false {
            duplicateTitleSuggestion
        } else if creationSourceState.suggestions.isEmpty {
            Text("No matching tasks")
                .font(dsMetrics.font(12, weight: .regular, category: .caption))
                .foregroundStyle(DS.ColorToken.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, dsMetrics.spacing(4))
        } else {
            VStack(spacing: dsMetrics.spacing(DS.Spacing.xs)) {
                ForEach(creationSourceState.suggestions) { candidate in
                    Button {
                        focusedField = nil
                        onSelectCreationSource(candidate)
                    } label: {
                        TaskCreationSourceRow(
                            candidate: candidate,
                            showsProBadge: isAdvancedRepeatLocked && candidate.repeatRule.requiresProAccess,
                            trailingSystemName: "doc.on.doc"
                        )
                    }
                    .buttonStyle(.plain)
                }

                if creationSourceState.hasMoreSuggestions {
                    Button {
                        focusedField = nil
                        onRequestCreationSources()
                    } label: {
                        Text("Show all")
                            .font(dsMetrics.font(13, weight: .semibold, category: .body))
                            .foregroundStyle(DS.ColorToken.purple)
                            .frame(maxWidth: .infinity, minHeight: dsMetrics.controlSize(40))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var duplicateTitleSuggestion: some View {
        VStack(alignment: .leading, spacing: dsMetrics.spacing(DS.Spacing.sm)) {
            Label("A task with this name already exists.", systemImage: "link")
                .font(dsMetrics.font(13, weight: .semibold, category: .body))
                .foregroundStyle(DS.ColorToken.textPrimary)

            Text(duplicateTitlePrompt)
                .font(dsMetrics.font(12, weight: .regular, category: .caption))
                .foregroundStyle(DS.ColorToken.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Tasks and schedules stay separate.")
                .font(dsMetrics.font(11, weight: .regular, category: .micro))
                .foregroundStyle(DS.ColorToken.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(creationSourceState.duplicateTitleCandidates) { candidate in
                Button {
                    focusedField = nil
                    onSelectDuplicateTitleStatisticsSource(candidate)
                } label: {
                    TaskCreationSourceRow(
                        candidate: candidate,
                        showsProBadge: false,
                        trailingSystemName: "link"
                    )
                }
                .buttonStyle(.plain)
                .accessibilityHint("Count together")
            }

            HStack(spacing: dsMetrics.spacing(16)) {
                Button("Keep separate") {
                    focusedField = nil
                    onDismissDuplicateTitleSuggestion()
                }

                if creationSourceState.hasMoreDuplicateTitleCandidates {
                    Button("Show all") {
                        focusedField = nil
                        onRequestStatisticsLinkSources()
                    }
                }
            }
            .font(dsMetrics.font(12, weight: .semibold, category: .caption))
            .foregroundStyle(DS.ColorToken.purple)
            .buttonStyle(.plain)
        }
    }

    private var duplicateTitlePrompt: String {
        creationSourceState.duplicateTitleCandidates.count == 1
            ? String(localized: "Count together in statistics?")
            : String(localized: "Choose which task to count together with.")
    }

    private var categoryMenuChip: some View {
        Menu {
            ForEach(state.availableCategories, id: \.self) { category in
                Button {
                    state.categoryTitleBinding.wrappedValue = category
                } label: {
                    if state.categoryTitle == category {
                        Label(displayCategoryTitle(category), systemImage: "checkmark")
                    } else {
                        Text(displayCategoryTitle(category))
                    }
                }
            }
        } label: {
            HStack(spacing: dsMetrics.spacing(6)) {
                Text(displayCategoryTitle(state.categoryTitle))
                    .font(
                        dsMetrics.font(
                            12,
                            weight: .semibold,
                            category: .micro
                        )
                    )
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.down")
                    .font(
                        dsMetrics.font(
                            11,
                            weight: .semibold,
                            category: .micro
                        )
                    )
            }
            .foregroundStyle(DS.ColorToken.purple)
            .padding(.horizontal, dsMetrics.spacing(12))
            .padding(.vertical, dsMetrics.spacing(8))
            .frame(width: fixedCategoryChipWidth)
            .background(DS.ColorToken.purple.opacity(0.10))
            .cornerRadius(DS.Radius.pill)
        }
        .buttonStyle(.plain)
    }

    private func displayCategoryTitle(_ rawTitle: String) -> String {
        CategorySystem.localizedDisplayTitle(for: rawTitle)
    }
}
