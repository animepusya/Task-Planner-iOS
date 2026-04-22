//
//  TaskEditorTopBar.swift
//  Task Planner
//
//  Created by Руслан Меланин on 11.02.2026.
//

import SwiftUI

struct TaskEditorTopBar: View {
    @Environment(\.dsAdaptiveMetrics) private var dsMetrics

    @ObservedObject var state: TaskEditorViewModel.ChromeState

    let onBack: () -> Void
    let onSaveNormal: () -> Void
    let onSaveOnlyThisDay: () -> Void
    let onSaveAllFuture: () -> Void

    var body: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(
                        dsMetrics.font(
                            16,
                            weight: .semibold,
                            category: .micro
                        )
                    )
                .foregroundStyle(DS.ColorToken.textPrimary)
                .frame(
                    width: dsMetrics.controlSize(40),
                    height: dsMetrics.controlSize(40)
                )
                .dsSurface(Circle(), fill: DS.Surface.card)
            }
            .buttonStyle(.plain)
            .disabled(state.isBusy)

            Spacer()

            Text(state.navigationTitle)
                .font(
                    dsMetrics.font(
                        16,
                        weight: .semibold,
                        category: .title
                    )
                )
                .foregroundStyle(DS.ColorToken.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.9)

            Spacer()

            saveControl
        }
    }

    private var saveControl: some View {
        Group {
            if state.showSaveScopeMenu {
                Menu {
                    Text("Save changes to")
                        .foregroundStyle(DS.ColorToken.textSecondary)
                        .disabled(true)

                    Button("Only this day") { onSaveOnlyThisDay() }
                    Button("All future days") { onSaveAllFuture() }
                } label: {
                    saveLabel
                }
                .disabled(!state.canSave)
                .opacity(state.canSave ? 1.0 : 0.45)
            } else {
                Button(action: onSaveNormal) {
                    saveLabel
                }
                .buttonStyle(.plain)
                .disabled(!state.canSave)
                .opacity(state.canSave ? 1.0 : 0.45)
            }
        }
    }

    private var saveLabel: some View {
        HStack(spacing: dsMetrics.spacing(8)) {
            if state.isBusy {
                ProgressView().scaleEffect(0.85).tint(.white)
            }
            Text("Save")
                .font(
                    dsMetrics.font(
                        14,
                        weight: .semibold,
                        category: .micro
                    )
                )
                .foregroundStyle(.white)
        }
        .padding(.horizontal, dsMetrics.spacing(18))
        .padding(.vertical, dsMetrics.spacing(10))
        .background(DS.GradientToken.brand)
        .cornerRadius(DS.Radius.pill)
    }
}
