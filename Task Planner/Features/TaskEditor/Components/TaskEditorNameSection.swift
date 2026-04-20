//
//  TaskEditorNameSection.swift
//  Task Planner
//
//  Created by Руслан Меланин on 11.02.2026.
//

import SwiftUI

struct TaskEditorNameSection: View {
    let titleState: TaskEditorViewModel.TitleSectionState
    let descriptionState: TaskEditorViewModel.DescriptionSectionState
    let fixedCategoryChipWidth: CGFloat

    @FocusState.Binding var focusedField: TaskEditorField?
    let showsTitleAndCategory: Bool
    let showsNotesEditor: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            if showsTitleAndCategory {
                TaskEditorTitleRow(
                    state: titleState,
                    fixedCategoryChipWidth: fixedCategoryChipWidth,
                    focusedField: $focusedField
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
    @ObservedObject var state: TaskEditorViewModel.TitleSectionState

    let fixedCategoryChipWidth: CGFloat
    @FocusState.Binding var focusedField: TaskEditorField?

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Task Name")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.ColorToken.textSecondary)

            HStack(spacing: 10) {
                TextField("Enter title", text: state.titleBinding)
                    .font(DS.Typography.body)
                    .textInputAutocapitalization(.sentences)
                    .disableAutocorrection(false)
                    .submitLabel(.done)
                    .focused($focusedField, equals: .title)
                    .onSubmit {
                        focusedField = nil
                    }

                categoryMenuChip
            }
            .padding(.vertical, 4)
        }
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
            HStack(spacing: 6) {
                Text(displayCategoryTitle(state.categoryTitle))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(DS.ColorToken.purple)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
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
