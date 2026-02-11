//
//  TaskColorPickerRow.swift
//  Task Planner
//
//  Created by Руслан Меланин on 11.02.2026.
//

import SwiftUI

struct TaskColorPickerRow: View {
    @Binding var selection: TaskColor

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(TaskColor.allCases, id: \.self) { color in
                    Button {
                        selection = color
                    } label: {
                        Circle()
                            .fill(color.uiColor)
                            .frame(width: 28, height: 28)
                            .overlay(
                                Circle()
                                    .strokeBorder(Color.white, lineWidth: selection == color ? 3 : 0)
                            )
                            .overlay(
                                Circle()
                                    .strokeBorder(DS.ColorToken.textSecondary.opacity(0.25), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }

                Spacer(minLength: 0)
            }
            .padding(.bottom, 2)
        }
    }
}
