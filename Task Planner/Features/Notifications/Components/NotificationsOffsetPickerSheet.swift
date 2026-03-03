//
//  NotificationsOffsetPickerSheet.swift
//  Task Planner
//
//  Created by Руслан Меланин on 03.03.2026.
//

import SwiftUI

struct NotificationsOffsetPickerSheet: View {
    let selectedMinutes: Int
    let onSelect: (Int) -> Void
    let onClose: () -> Void

    @State private var custom: String = ""

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            HStack {
                Text("Default reminder")
                    .font(DS.Typography.sectionTitle)
                    .foregroundStyle(DS.ColorToken.textPrimary)
                Spacer()
                Button("Close", action: onClose)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
            }
            .padding(.top, 6)

            VStack(spacing: 10) {
                ForEach(ReminderPreset.allCases) { preset in
                    Button {
                        switch preset {
                        case .customMinutes:
                            let v = Int(custom) ?? selectedMinutes
                            onSelect(max(0, v))
                        default:
                            let v = preset.resolvedOffsetMinutes(customValue: selectedMinutes)
                            onSelect(v)
                        }
                    } label: {
                        HStack {
                            Text(preset.title)
                                .font(DS.Typography.body)
                                .foregroundStyle(DS.ColorToken.textPrimary)

                            Spacer()

                            if isSelected(preset: preset) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(DS.ColorToken.purple)
                            } else {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(DS.ColorToken.textSecondary.opacity(0.6))
                            }
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 12)
                        .background(Color.black.opacity(0.04))
                        .cornerRadius(DS.Radius.sm)
                    }
                    .buttonStyle(.plain)

                    if preset == .customMinutes {
                        HStack(spacing: 10) {
                            Text("Minutes")
                                .font(DS.Typography.caption)
                                .foregroundStyle(DS.ColorToken.textSecondary)

                            Spacer()

                            TextField("\(selectedMinutes)", text: $custom)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .padding(.vertical, 10)
                                .padding(.horizontal, 12)
                                .background(Color.black.opacity(0.04))
                                .cornerRadius(DS.Radius.sm)
                                .frame(width: 120)
                        }
                        .padding(.top, 2)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.bottom, 18)
        .background(DS.ColorToken.appBackground.ignoresSafeArea())
        .onAppear {
            if ReminderPreset.fromOffsetMinutes(selectedMinutes) == .customMinutes {
                custom = "\(selectedMinutes)"
            } else {
                custom = ""
            }
        }
    }

    private func isSelected(preset: ReminderPreset) -> Bool {
        let current = ReminderPreset.fromOffsetMinutes(selectedMinutes)
        switch (preset, current) {
        case (.atTime, .atTime): return true
        case (.minutes(let a), .minutes(let b)): return a == b
        case (.customMinutes, .customMinutes): return true
        default: return false
        }
    }
}
