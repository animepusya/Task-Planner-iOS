//
//  TaskEditorTopBar.swift
//  Task Planner
//
//  Created by Руслан Меланин on 11.02.2026.
//

import SwiftUI

struct TaskEditorTopBar: View {
    let title: String
    let isBusy: Bool
    let onBack: () -> Void
    let onSave: () -> Void

    var body: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DS.ColorToken.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(.white)
                    .clipShape(Circle())
                    .shadow(color: DS.Shadow.soft, radius: 10, x: 0, y: 6)
            }
            .buttonStyle(.plain)
            .disabled(isBusy)

            Spacer()

            Text(title)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(DS.ColorToken.textPrimary)

            Spacer()

            Button(action: onSave) {
                HStack(spacing: 8) {
                    if isBusy {
                        ProgressView().scaleEffect(0.85).tint(.white)
                    }
                    Text("Save")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(DS.GradientToken.brand)
                .cornerRadius(DS.Radius.pill)
            }
            .buttonStyle(.plain)
            .disabled(isBusy)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, 10)
    }
}
