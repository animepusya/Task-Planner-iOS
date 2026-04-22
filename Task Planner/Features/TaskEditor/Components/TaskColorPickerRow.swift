//
//  TaskColorPickerRow.swift
//  Task Planner
//
//  Created by Руслан Меланин on 11.02.2026.
//

import SwiftUI

struct TaskColorPickerRow: View {
    @Environment(\.dsAdaptiveMetrics) private var dsMetrics

    @Binding var selection: TaskColor

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: dsMetrics.spacing(12)) {
                ForEach(TaskColor.allCases, id: \.self) { color in
                    Button {
                        selection = color
                    } label: {
                        Circle()
                            .fill(color.uiColor)
                            .frame(
                                width: dsMetrics.controlSize(28),
                                height: dsMetrics.controlSize(28)
                            )
                            .overlay(
                                Circle()
                                    .strokeBorder(
                                        Color.white,
                                        lineWidth: selection == color ? dsMetrics.strokeWidth(3) : 0
                                    )
                            )
                            .overlay(
                                Circle()
                                    .strokeBorder(
                                        DS.ColorToken.textSecondary.opacity(0.25),
                                        lineWidth: dsMetrics.strokeWidth(1)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }

                Spacer(minLength: 0)
            }
            .padding(.bottom, dsMetrics.spacing(2))
        }
    }
}
