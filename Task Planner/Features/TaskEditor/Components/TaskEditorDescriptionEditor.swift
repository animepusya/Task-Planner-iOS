//
//  TaskEditorDescriptionEditor.swift
//  Task Planner
//
//  Created by Руслан Меланин on 11.02.2026.
//

import SwiftUI

struct TaskEditorDescriptionEditor: View {
    @Binding var notes: String
    @Binding var isExpanded: Bool

    @FocusState.Binding var focusedField: TaskEditorField?

    private var hasNotes: Bool {
        !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Description")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.ColorToken.textSecondary)

            VStack(spacing: 8) {
                if shouldShowEditor {
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: DS.Radius.sm)
                            .fill(Color.black.opacity(0.04))

                        TextEditor(text: $notes)
                            .font(DS.Typography.body)
                            .focused($focusedField, equals: .description)
                            .scrollContentBackground(.hidden)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 8)
                            .frame(minHeight: 104, maxHeight: 168)

                        if notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("Add a short description…")
                                .font(DS.Typography.body)
                                .foregroundStyle(DS.ColorToken.textSecondary.opacity(0.8))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 16)
                                .allowsHitTesting(false)
                        }
                    }
                    .transition(.identity)
                }

                if !hasNotes {
                    if isExpanded {
                        Button {
                            focusedField = nil
                            withAnimation(.none) { isExpanded = false }
                        } label: {
                            HStack {
                                Text("Hide description")
                                    .font(DS.Typography.caption)
                                    .foregroundStyle(DS.ColorToken.textSecondary)
                                    .fixedSize(horizontal: true, vertical: false)
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button {
                            withAnimation(.none) { isExpanded = true }
                            focusedField = .description
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(DS.ColorToken.purple)
                                Text("Add description")
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
        }
        .animation(nil, value: notes)
        .animation(nil, value: isExpanded)
        .onChange(of: notes) { _, newValue in
            if !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                isExpanded = true
            }
        }
    }

    private var shouldShowEditor: Bool {
        if hasNotes { return true }
        return isExpanded
    }
}
