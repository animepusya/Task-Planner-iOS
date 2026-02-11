//
//  TaskEditorDescriptionEditor.swift
//  Task Planner
//
//  Created by Руслан Меланин on 11.02.2026.
//

import SwiftUI

struct TaskEditorDescriptionEditor: View {
    @Binding var notes: String
    let canHide: Bool
    let onHide: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Description")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.ColorToken.textSecondary)

            ZStack(alignment: .topLeading) {
                if notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Add a short description…")
                        .font(DS.Typography.body)
                        .foregroundStyle(DS.ColorToken.textSecondary.opacity(0.8))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 14)
                }

                TextEditor(text: $notes)
                    .font(DS.Typography.body)
                    .frame(minHeight: 110)
                    .padding(8)
                    .background(Color.black.opacity(0.04))
                    .cornerRadius(DS.Radius.sm)
            }

            if canHide, let onHide {
                Button(action: onHide) {
                    HStack {
                        Text("Hide description")
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.ColorToken.textSecondary)
                            .fixedSize(horizontal: true, vertical: false)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .animation(nil, value: notes) // ✅ убираем “дерготню” во время набора
    }
}
