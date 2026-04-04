//
//  CategoryInputRow.swift
//  Task Planner
//
//  Created by Руслан Меланин on 14.03.2026.
//

import SwiftUI

struct CategoryInputRow: View {
    @Binding var title: String
    let showsProBadge: Bool
    let onAdd: () -> Void

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(DS.GradientToken.brand)

            TextField("Add category", text: $title)
                .textInputAutocapitalization(.words)
                .disableAutocorrection(true)
                .font(DS.Typography.body)
                .submitLabel(.done)
                .onSubmit {
                    guard !trimmedTitle.isEmpty else { return }
                    onAdd()
                }

            if showsProBadge {
                ProBadge(size: .small)
            }

            Button("Add") {
                onAdd()
            }
            .buttonStyle(.plain)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(trimmedTitle.isEmpty ? DS.ColorToken.textSecondary : DS.ColorToken.purple)
            .disabled(trimmedTitle.isEmpty)
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, 14)
    }
}
