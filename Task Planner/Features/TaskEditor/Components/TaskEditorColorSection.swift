//
//  TaskEditorColorSection.swift
//  Task Planner
//
//  Created by Руслан Меланин on 11.02.2026.
//

import SwiftUI

struct TaskEditorColorSection: View {
    @ObservedObject var state: TaskEditorViewModel.ColorSectionState

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Color")
                .font(DS.Typography.sectionTitle)
                .foregroundStyle(DS.ColorToken.textPrimary)

            TaskColorPickerRow(selection: state.colorBinding)
        }
        .dsCard(style: .outlined)
    }
}
