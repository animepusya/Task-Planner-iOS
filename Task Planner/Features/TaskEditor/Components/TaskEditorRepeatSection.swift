//
//  TaskEditorRepeatSection.swift
//  Task Planner
//
//  Created by Руслан Меланин on 11.02.2026.
//

import SwiftUI

struct TaskEditorRepeatSection: View {
    @Environment(\.dsAdaptiveMetrics) private var dsMetrics

    @ObservedObject var state: TaskEditorViewModel.RepeatSectionState
    let isAdvancedRepeatLocked: Bool
    let onRequestUnlock: () -> Void

    private var showsInterval: Bool {
        state.repeatRule == .everyNDays
    }

    private var currentRuleRequiresPro: Bool {
        state.repeatRule.requiresProAccess
    }

    var body: some View {
        VStack(alignment: .leading, spacing: dsMetrics.spacing(DS.Spacing.sm)) {
            HStack(spacing: dsMetrics.spacing(8)) {
                Text("Repeat")
                    .font(
                        dsMetrics.font(
                            18,
                            weight: .semibold,
                            category: .title
                        )
                    )
                    .foregroundStyle(DS.ColorToken.textPrimary)

                if isAdvancedRepeatLocked && currentRuleRequiresPro {
                    ProBadge(size: .small)
                }
            }

            repeatPill

            if showsInterval {
                intervalRow
            }

            if state.isInvalid, let validationMessage = state.validationMessage {
                Text(validationMessage)
                    .font(
                        dsMetrics.font(
                            12,
                            weight: .medium,
                            category: .caption
                        )
                    )
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, dsMetrics.spacing(2))
            }
        }
        .dsCard(style: .outlined)
        .overlay {
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .stroke(state.isInvalid ? Color.red.opacity(0.28) : .clear, lineWidth: 1.25)
        }
    }

    private var intervalRow: some View {
        HStack(alignment: .center, spacing: dsMetrics.spacing(DS.Spacing.sm)) {
            Text(
                String.localizedStringWithFormat(
                    String(localized: "Every %lld days"),
                    Int64(state.repeatIntervalDays)
                )
            )
                .font(
                    dsMetrics.font(
                        15,
                        weight: .regular,
                        category: .body
                    )
                )
                .foregroundStyle(DS.ColorToken.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .layoutPriority(1)

            Spacer(minLength: dsMetrics.spacing(DS.Spacing.sm))

            RepeatIntervalControl(
                value: state.repeatIntervalDaysBinding,
                range: 1...365,
                isLocked: isAdvancedRepeatLocked && currentRuleRequiresPro,
                onRequestUnlock: onRequestUnlock
            )
        }
        .padding(.top, 4)
    }

    private var repeatPill: some View {
        Menu {
            ForEach(RepeatRule.allCases, id: \.self) { rule in
                Button {
                    if rule.requiresProAccess && isAdvancedRepeatLocked {
                        onRequestUnlock()
                    } else {
                        state.repeatRuleBinding.wrappedValue = rule
                    }
                } label: {
                    HStack(spacing: 8) {
                        if state.repeatRule == rule {
                            Label(rule.displayName, systemImage: "checkmark")
                        } else {
                            Text(rule.displayName)
                        }

                        if rule.requiresProAccess && isAdvancedRepeatLocked {
                            ProBadge(size: .small)
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: dsMetrics.spacing(10)) {
                Image(systemName: "repeat")
                    .font(
                        dsMetrics.font(
                            13,
                            weight: .semibold,
                            category: .micro
                        )
                    )
                    .foregroundStyle(DS.ColorToken.textSecondary)
                    .frame(width: dsMetrics.controlSize(18), alignment: .center)

                Text(state.repeatRule.displayName)
                    .font(
                        dsMetrics.font(
                            15,
                            weight: .regular,
                            category: .body
                        )
                    )
                    .foregroundStyle(DS.ColorToken.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .layoutPriority(1)

                if isAdvancedRepeatLocked && currentRuleRequiresPro {
                    ProBadge(size: .small)
                }

                Spacer(minLength: dsMetrics.spacing(8))

                Image(systemName: "chevron.down")
                    .font(
                        dsMetrics.font(
                            13,
                            weight: .semibold,
                            category: .micro
                        )
                    )
                    .foregroundStyle(DS.ColorToken.textSecondary)
            }
            .padding(.horizontal, dsMetrics.spacing(12))
            .padding(.vertical, dsMetrics.spacing(10))
            .frame(minHeight: dsMetrics.controlSize(44))
            .background(DS.ColorToken.controlFill)
            .cornerRadius(DS.Radius.pill)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct RepeatIntervalControl: View {
    @Environment(\.dsAdaptiveMetrics) private var dsMetrics

    @Binding var value: Int
    let range: ClosedRange<Int>
    let isLocked: Bool
    let onRequestUnlock: () -> Void

    var body: some View {
        HStack(spacing: dsMetrics.spacing(8)) {
            stepButton(systemName: "minus") {
                if isLocked {
                    onRequestUnlock()
                } else {
                    value = max(range.lowerBound, value - 1)
                }
            }
            .disabled(!isLocked && value <= range.lowerBound)

            Text("\(value)")
                .font(
                    dsMetrics.font(
                        15,
                        weight: .regular,
                        category: .body
                    )
                )
                .foregroundStyle(DS.ColorToken.textPrimary)
                .monospacedDigit()
                .frame(minWidth: dsMetrics.controlSize(30), alignment: .center)

            stepButton(systemName: "plus") {
                if isLocked {
                    onRequestUnlock()
                } else {
                    value = min(range.upperBound, value + 1)
                }
            }
            .disabled(!isLocked && value >= range.upperBound)
        }
        .padding(.horizontal, dsMetrics.spacing(10))
        .padding(.vertical, dsMetrics.spacing(8))
        .frame(minHeight: dsMetrics.controlSize(40))
        .background(DS.ColorToken.controlFill)
        .cornerRadius(DS.Radius.pill)
    }

    private func stepButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(
                    dsMetrics.font(
                        12,
                        weight: .semibold,
                        category: .micro
                    )
                )
                .foregroundStyle(DS.ColorToken.textSecondary)
                .frame(
                    width: dsMetrics.controlSize(30),
                    height: dsMetrics.controlSize(30)
                )
                .dsSurface(Circle(), fill: DS.Surface.card)
        }
        .buttonStyle(.plain)
    }
}
