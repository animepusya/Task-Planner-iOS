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
    let canSave: Bool
    let showSaveScopeMenu: Bool
    let onSaveNormal: () -> Void
    let onSaveOnlyThisDay: () -> Void
    let onSaveAllFuture: () -> Void

    var body: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DS.ColorToken.textPrimary)
                    .frame(width: 40, height: 40)
                    .dsSurface(Circle(), fill: DS.Surface.card)
            }
            .buttonStyle(.plain)
            .disabled(isBusy)

            Spacer()

            Text(title)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(DS.ColorToken.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.9)

            Spacer()

            saveControl
        }
    }

    private var saveControl: some View {
        Group {
            if showSaveScopeMenu {
                Menu {
                    Text("How to apply changes?")
                        .foregroundStyle(DS.ColorToken.textSecondary)
                        .disabled(true)

                    Button("Only this day") { onSaveOnlyThisDay() }
                    Button("All future days") { onSaveAllFuture() }
                } label: {
                    saveLabel
                }
                .disabled(!canSave)
                .opacity(canSave ? 1.0 : 0.45)
            } else {
                Button(action: onSaveNormal) {
                    saveLabel
                }
                .buttonStyle(.plain)
                .disabled(!canSave)
                .opacity(canSave ? 1.0 : 0.45)
            }
        }
    }

    private var saveLabel: some View {
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
}
