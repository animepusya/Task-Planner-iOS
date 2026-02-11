//
//  TaskEditorColorSection.swift
//  Task Planner
//
//  Created by Руслан Меланин on 11.02.2026.
//

import SwiftUI

struct TaskEditorColorSection: View {
    @Binding var color: TaskColor

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Color")
                .font(DS.Typography.sectionTitle)
                .foregroundStyle(DS.ColorToken.textPrimary)

            TaskColorPickerRow(selection: $color)
        }
        .dsCard()
    }
}
