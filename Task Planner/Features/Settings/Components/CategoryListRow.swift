//
//  CategoryListRow.swift
//  Task Planner
//
//  Created by Руслан Меланин on 14.03.2026.
//

import SwiftUI

struct CategoryListRow: View {
    let title: String
    let isDeletable: Bool
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: isDeletable ? "folder" : "lock.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isDeletable ? DS.ColorToken.textSecondary : DS.ColorToken.textSecondary)

            Text(displayTitle)
                .font(DS.Typography.body)
                .foregroundStyle(DS.ColorToken.textPrimary)

            Spacer()

            if !isDeletable {
                Text("System")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.ColorToken.textSecondary)
            }
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if isDeletable {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    private var displayTitle: String {
        isDeletable ? title : CategorySystem.localizedDisplayTitle(for: title)
    }
}
