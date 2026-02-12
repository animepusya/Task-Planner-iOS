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

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Menu {
                ForEach(RepeatRule.allCases, id: \.self) { rule in
                    Button {
                        repeatRule = rule
                    } label: {
                        if repeatRule == rule { Label(rule.displayName, systemImage: "checkmark") }
                        else { Text(rule.displayName) }
                    }
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Repeat")
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.ColorToken.textSecondary)

                        Text(repeatRule.displayName)
                            .font(DS.Typography.body)
                            .foregroundStyle(DS.ColorToken.textPrimary)
                    }

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DS.ColorToken.textSecondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if repeatRule == .everyNDays {
                Divider().opacity(0.12)

                Stepper(value: $repeatIntervalDays, in: 1...365) {
                    Text("Every \(repeatIntervalDays) days")
                        .font(DS.Typography.body)
                        .foregroundStyle(DS.ColorToken.textPrimary)
                }
            }

            if let validationMessage, isInvalid {
                Text(validationMessage)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.red)
            }
        }
        .dsCard()
        .shadow(
            color: isInvalid ? Color.red.opacity(0.25) : .clear,
            radius: isInvalid ? 12 : 0,
            x: 0,
            y: 8
        )
    }
}
