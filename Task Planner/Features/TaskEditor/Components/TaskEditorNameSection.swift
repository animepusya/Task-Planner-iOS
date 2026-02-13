//
//  TaskEditorNameSection.swift
//  Task Planner
//
//  Created by Руслан Меланин on 11.02.2026.
//

import SwiftUI

struct TaskEditorNameSection: View {
    @Binding var title: String
    @Binding var categoryTitle: String
    @Binding var notes: String

    let availableCategories: [String]
    let fixedCategoryChipWidth: CGFloat

    @FocusState.Binding var focusedField: TaskEditorField?

    @State private var isNotesExpanded = false
    
    private var hasNotes: Bool {
        !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {

            Text("Task Name")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.ColorToken.textSecondary)

            HStack(spacing: 10) {
                TextField("Enter task name", text: $title)
                    .font(DS.Typography.body)
                    .textInputAutocapitalization(.sentences)
                    .disableAutocorrection(false)
                    .focused($focusedField, equals: .title)

                categoryMenuChip
            }
            .padding(.vertical, 4)

            TaskEditorDescriptionEditor(
                notes: $notes,
                isExpanded: $isNotesExpanded,
                focusedField: $focusedField
            )
        }
        .dsCard()
        .onAppear {
            if hasNotes { isNotesExpanded = true }
        }
        .onChange(of: notes) { _, newValue in
            if !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                isNotesExpanded = true
            }
        }
    }

    private var categoryMenuChip: some View {
        Menu {
            ForEach(availableCategories, id: \.self) { c in
                Button {
                    withAnimation(.none) { categoryTitle = c }
                } label: {
                    if categoryTitle == c { Label(c, systemImage: "checkmark") }
                    else { Text(c) }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(categoryTitle)
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
        .animation(nil, value: categoryTitle)
    }
}
