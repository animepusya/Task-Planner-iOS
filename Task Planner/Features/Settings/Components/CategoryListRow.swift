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
        SettingsRow(
            title: displayTitle,
            systemImage: "tag",
            accessory: {
                Group {
                    if isDeletable {
                        deleteButton
                    } else {
                        EmptyView()
                    }
                }
            }
        )
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if isDeletable {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    private var deleteButton: some View {
        Button(action: onDelete) {
            Image(systemName: "trash")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.red)
                .frame(width: 28, height: 28)
                .background(Color.red.opacity(0.12), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            Text(
                String.localizedStringWithFormat(
                    String(localized: "Delete %@"),
                    displayTitle
                )
            )
        )
    }

    private var displayTitle: String {
        CategorySystem.localizedDisplayTitle(for: title)
    }
}
