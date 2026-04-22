//
//  TaskEditorChipGroup.swift
//  Task Planner
//
//  Created by Руслан Меланин on 11.02.2026.
//

import SwiftUI

struct TaskEditorChipGroup: View {
    @Environment(\.dsAdaptiveMetrics) private var dsMetrics

    struct Chip: Identifiable {
        let id: String
        let title: String
        let action: () -> Void

        init(id: String? = nil, title: String, action: @escaping () -> Void) {
            self.id = id ?? title
            self.title = title
            self.action = action
        }
    }

    let title: String
    let chips: [Chip]

    var body: some View {
        VStack(alignment: .leading, spacing: dsMetrics.spacing(10)) {
            Text(title)
                .font(
                    dsMetrics.font(
                        12,
                        weight: .medium,
                        category: .caption
                    )
                )
                .foregroundStyle(DS.ColorToken.textSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: dsMetrics.spacing(10)) {
                    ForEach(chips) { chip in
                        Button(action: chip.action) {
                            Text(chip.title)
                                .font(
                                    dsMetrics.font(
                                        12,
                                        weight: .medium,
                                        category: .caption
                                    )
                                )
                                .foregroundStyle(DS.ColorToken.textPrimary)
                                .padding(.horizontal, dsMetrics.spacing(12))
                                .padding(.vertical, dsMetrics.spacing(8))
                                .background(DS.ColorToken.lavender.opacity(0.45))
                                .cornerRadius(DS.Radius.pill)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.bottom, dsMetrics.spacing(2))
            }
        }
    }
}
