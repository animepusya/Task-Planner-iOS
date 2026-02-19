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
            Text("Repeat")
                .font(DS.Typography.sectionTitle)
                .foregroundStyle(DS.ColorToken.textPrimary)

            repeatPill

            if showsInterval {
                intervalRow
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
    }

    // MARK: - Interval row

    private var intervalRow: some View {
        HStack(alignment: .center, spacing: DS.Spacing.sm) {
            Text("Every \(repeatIntervalDays) days")
                .font(DS.Typography.body)                // больше не caption
                .foregroundStyle(DS.ColorToken.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .layoutPriority(1)

            Spacer(minLength: DS.Spacing.sm)

            RepeatIntervalControl(value: $repeatIntervalDays, range: 1...365)
        }
        .padding(.top, 4)
    }

    // MARK: - Repeat pill (Menu)

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
                    .frame(width: 18, alignment: .center)

                Text(repeatRule.displayName)
                    .font(DS.Typography.body)
                    .foregroundStyle(DS.ColorToken.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .layoutPriority(1)

                Spacer(minLength: 8)

                Image(systemName: "chevron.down")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DS.ColorToken.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(minHeight: 44) // комфортный tap target + меньше “прыжков”
            .background(Color.black.opacity(0.04))
            .cornerRadius(DS.Radius.pill)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Premium +/- control (compact)

private struct RepeatIntervalControl: View {
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        HStack(spacing: 8) {
            stepButton(systemName: "minus") {
                value = max(range.lowerBound, value - 1)
            }
            .disabled(value <= range.lowerBound)

            Text("\(value)")
                .font(DS.Typography.body)
                .foregroundStyle(DS.ColorToken.textPrimary)
                .monospacedDigit()
                .frame(minWidth: 30, alignment: .center)

            stepButton(systemName: "plus") {
                value = min(range.upperBound, value + 1)
            }
            .disabled(value >= range.upperBound)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(minHeight: 40)
        .background(Color.black.opacity(0.04))
        .cornerRadius(DS.Radius.pill)
    }

    private func stepButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DS.ColorToken.textSecondary)
                .frame(width: 30, height: 30)
                .background(DS.ColorToken.cardBackground)
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(Color.black.opacity(0.06), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }
}
