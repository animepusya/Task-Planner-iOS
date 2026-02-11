//
//  TaskEditorChipGroup.swift
//  Task Planner
//
//  Created by Руслан Меланин on 11.02.2026.
//

import SwiftUI

struct TaskEditorChipGroup: View {
    struct Chip: Identifiable {
        let id = UUID()
        let title: String
        let action: () -> Void
    }

    let title: String
    let chips: [Chip]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(DS.Typography.caption)
                .foregroundStyle(DS.ColorToken.textSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(chips) { chip in
                        Button(action: chip.action) {
                            Text(chip.title)
                                .font(DS.Typography.caption)
                                .foregroundStyle(DS.ColorToken.textPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(DS.ColorToken.lavender.opacity(0.45))
                                .cornerRadius(DS.Radius.pill)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.bottom, 2)
            }
        }
    }
}
