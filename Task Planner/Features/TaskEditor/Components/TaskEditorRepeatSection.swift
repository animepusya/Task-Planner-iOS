//
//  TaskEditorRepeatSection.swift
//  Task Planner
//
//  Created by Руслан Меланин on 11.02.2026.
//

import SwiftUI

struct TaskEditorRepeatSection: View {
    @Binding var repeatRule: RepeatRule
    @Binding var repeatIntervalDays: Int

    let isInvalid: Bool
    let validationMessage: String?

    private var showsInterval: Bool { repeatRule == .everyNDays }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                header
                
                Spacer()

                if showsInterval {
                    Text("Every \(repeatIntervalDays) days")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.ColorToken.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                        .padding(.top, 2)
                }
            }

            HStack(alignment: .center, spacing: DS.Spacing.sm) {
                repeatPill
                    .frame(maxWidth: .infinity, alignment: .leading)

                if showsInterval {
                    RepeatIntervalControl(
                        value: $repeatIntervalDays,
                        range: 1...365
                    )
                }
            }

            if isInvalid, let validationMessage {
                Text(validationMessage)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
        }
        .dsCard()
        .shadow(
            color: isInvalid ? Color.red.opacity(0.22) : .clear,
            radius: isInvalid ? 12 : 0,
            x: 0,
            y: 8
        )
        .transaction { $0.animation = nil }
        .animation(nil, value: repeatRule)
        .animation(nil, value: isInvalid)
        .animation(nil, value: validationMessage)
    }

    // MARK: - UI

    private var header: some View {
        Text("Repeat")
            .font(DS.Typography.sectionTitle)
            .foregroundStyle(DS.ColorToken.textPrimary)
    }

    private var repeatPill: some View {
        Menu {
            ForEach(RepeatRule.allCases, id: \.self) { rule in
                Button {
                    repeatRule = rule
                } label: {
                    if repeatRule == rule {
                        Label(rule.displayName, systemImage: "checkmark")
                    } else {
                        Text(rule.displayName)
                    }
                }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "repeat")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DS.ColorToken.textSecondary)

                Text(repeatRule.displayName)
                    .font(DS.Typography.body)
                    .foregroundStyle(DS.ColorToken.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)

                Spacer(minLength: 0)

                Image(systemName: "chevron.down")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DS.ColorToken.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.04))
            .cornerRadius(DS.Radius.pill)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Compact +/- control

private struct RepeatIntervalControl: View {
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        HStack(spacing: 8) {
            circleButton(systemName: "minus") {
                value = max(range.lowerBound, value - 1)
            }
            .disabled(value <= range.lowerBound)

            Text("\(value)")
                .font(DS.Typography.body)
                .foregroundStyle(DS.ColorToken.textPrimary)
                .monospacedDigit()
                .frame(minWidth: 28, alignment: .center)

            circleButton(systemName: "plus") {
                value = min(range.upperBound, value + 1)
            }
            .disabled(value >= range.upperBound)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.04))
        .cornerRadius(DS.Radius.pill)
    }

    private func circleButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DS.ColorToken.textSecondary)
                .frame(width: 28, height: 28)
                .background(DS.ColorToken.cardBackground)
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }
}
