//
//  TaskEditorDescriptionEditor.swift
//  Task Planner
//
//  Created by Руслан Меланин on 11.02.2026.
//

import SwiftUI

struct TaskEditorDescriptionEditor: View {
    @Environment(\.dsAdaptiveMetrics) private var dsMetrics

    @ObservedObject var state: TaskEditorViewModel.DescriptionSectionState

    @FocusState.Binding var focusedField: TaskEditorField?
    let expandsByDefault: Bool

    @State private var isExpanded = false

    private let editorHeight: CGFloat = 132

    var body: some View {
        VStack(alignment: .leading, spacing: dsMetrics.spacing(6)) {
            Text("Description")
                .font(
                    dsMetrics.font(
                        12,
                        weight: .medium,
                        category: .caption
                    )
                )
                .foregroundStyle(DS.ColorToken.textSecondary)

            if state.hasNotes || isExpanded {
                textEditor
            }

            if !state.hasNotes {
                expansionControl
            }
        }
        .onAppear(perform: syncExpansionState)
        .onChange(of: state.hasNotes) { _, hasNotes in
            if hasNotes {
                isExpanded = true
            } else {
                syncExpansionState()
            }
        }
        .onChange(of: expandsByDefault) { _, _ in
            syncExpansionState()
        }
    }

    private var textEditor: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: dsMetrics.cornerRadius(DS.Radius.sm))
                .fill(DS.ColorToken.controlFill)

            TextEditor(text: state.notesBinding)
                .font(
                    dsMetrics.font(
                        15,
                        weight: .regular,
                        category: .body
                    )
                )
                .focused($focusedField, equals: .description)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, dsMetrics.spacing(8))
                .padding(.vertical, dsMetrics.spacing(8))
                .frame(height: dsMetrics.controlSize(editorHeight))

            if !state.hasNotes {
                Text("Add a short description…")
                    .font(
                        dsMetrics.font(
                            15,
                            weight: .regular,
                            category: .body
                        )
                    )
                    .foregroundStyle(DS.ColorToken.textSecondary.opacity(0.8))
                    .padding(.horizontal, dsMetrics.spacing(14))
                    .padding(.vertical, dsMetrics.spacing(16))
                    .allowsHitTesting(false)
            }
        }
    }

    @ViewBuilder
    private var expansionControl: some View {
        if isExpanded {
            Button {
                focusedField = nil
                isExpanded = false
            } label: {
                HStack {
                    Text("Hide description")
                        .font(
                            dsMetrics.font(
                                12,
                                weight: .medium,
                                category: .caption
                            )
                        )
                        .foregroundStyle(DS.ColorToken.textSecondary)
                        .fixedSize(horizontal: true, vertical: false)
                    Spacer()
                }
            }
            .buttonStyle(.plain)
        } else {
            Button {
                isExpanded = true
                focusedField = .description
            } label: {
                HStack(spacing: dsMetrics.spacing(8)) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(DS.ColorToken.purple)

                    Text("Add description")
                        .font(
                            dsMetrics.font(
                                12,
                                weight: .medium,
                                category: .caption
                            )
                        )
                        .foregroundStyle(DS.ColorToken.purple)
                        .fixedSize(horizontal: true, vertical: false)

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, dsMetrics.spacing(6))
            }
            .buttonStyle(.plain)
        }
    }

    private func syncExpansionState() {
        if state.hasNotes || expandsByDefault {
            isExpanded = true
        }
    }
}
