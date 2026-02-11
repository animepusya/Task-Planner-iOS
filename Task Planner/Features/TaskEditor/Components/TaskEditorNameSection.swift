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

    private var hasNotes: Bool {
        !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @State private var isNotesExpanded = false

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

                categoryMenuChip
            }
            .padding(.vertical, 4)

            // ✅ логика:
            // - если описание уже есть -> всегда показываем editor (и нет Hide)
            // - если пусто -> кнопка Add, можно открыть/закрыть
            if hasNotes {
                TaskEditorDescriptionEditor(notes: $notes, canHide: false, onHide: nil)
                    .transition(.opacity)
            } else {
                if isNotesExpanded {
                    TaskEditorDescriptionEditor(
                        notes: $notes,
                        canHide: true,
                        onHide: {
                            withAnimation(.snappy(duration: 0.20)) {
                                isNotesExpanded = false
                            }
                        }
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                } else {
                    Button {
                        withAnimation(.snappy(duration: 0.22)) {
                            isNotesExpanded = true
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(DS.ColorToken.purple)
                            Text(hasNotes ? "Show description" : "Add description")
                                .font(DS.Typography.caption)
                                .foregroundStyle(DS.ColorToken.purple)
                                .fixedSize(horizontal: true, vertical: false)
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .dsCard()
        .onAppear {
            // ✅ при редактировании: если notes уже есть, раскрываем без анимаций
            if hasNotes { isNotesExpanded = true }
        }
        .onChange(of: notes) { _, newValue in
            // ✅ если пользователь начал печатать — фиксируем “всегда открыто”
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
            .frame(width: fixedCategoryChipWidth) // ✅ фикс прыгания/обрезаний
            .background(DS.ColorToken.purple.opacity(0.10))
            .cornerRadius(DS.Radius.pill)
        }
        .buttonStyle(.plain)
        .animation(nil, value: categoryTitle)
    }
}
