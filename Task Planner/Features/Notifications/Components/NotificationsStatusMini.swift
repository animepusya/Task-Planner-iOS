//
//  NotificationsStatusMini.swift
//  Task Planner
//
//  Created by Руслан Меланин on 04.03.2026.
//

import SwiftUI
import UIKit

struct NotificationsStatusMini: View {
    @ObservedObject var viewModel: NotificationsViewModel

    @State private var showInfoPopover = false

    private var pillTitle: String {
        viewModel.notificationsEnabled ? "Enabled" : "Disabled"
    }

    private var systemStatusTitle: String? {
        switch viewModel.systemStatus {
        case .notDetermined: return "Permission not requested"
        case .denied: return "Permission denied"
        case .authorized: return nil
        }
    }

    private var primaryActionTitle: String? {
        switch viewModel.systemStatus {
        case .notDetermined: return "Enable"
        case .denied: return "Settings"
        case .authorized: return nil
        }
    }

    private var infoText: String {
        switch viewModel.systemStatus {
        case .notDetermined:
            return "System permission is not requested yet. Tap “Enable” to show the system prompt."
        case .denied:
            return "System permission is denied. Tap “Settings” to enable notifications in iOS Settings."
        case .authorized:
            return "System permission is granted."
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Status")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(DS.ColorToken.textSecondary)

                StatusPill(title: pillTitle, isOn: viewModel.notificationsEnabled)
                    .scaleEffect(0.92, anchor: .leading)

                if systemStatusTitle != nil {
                    Button {
                        showInfoPopover = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(DS.ColorToken.textSecondary.opacity(0.85))
                            .padding(4)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Permission info")
                    .popover(isPresented: $showInfoPopover) {
                        infoPopover
                            .presentationCompactAdaptation(.popover)
                    }
                }

                Spacer(minLength: 8)

                Toggle("", isOn: Binding(
                    get: { viewModel.notificationsEnabled },
                    set: { viewModel.setNotificationsEnabled($0) }
                ))
                .labelsHidden()
                .tint(DS.ColorToken.lavender)
                .accessibilityLabel("App notifications")
                .accessibilityValue(viewModel.notificationsEnabled ? "On" : "Off")
            }

            if let action = primaryActionTitle {
                HStack(spacing: 8) {
                    if let oneLine = systemStatusTitle {
                        Text(oneLine)
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.ColorToken.textSecondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    } else {
                        Spacer(minLength: 0)
                    }

                    Spacer(minLength: 8)

                    Button {
                        lightHaptic()
                        viewModel.primaryActionTapped()
                    } label: {
                        Text(action)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(DS.ColorToken.textPrimary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: DS.Radius.pill)
                                    .fill(Color.black.opacity(0.06))
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isLoading)
                    .opacity(viewModel.isLoading ? 0.6 : 1.0)
                    .accessibilityLabel(action)
                }
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .contain)
    }

    private var infoPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Notifications")
                .font(DS.Typography.sectionTitle)
                .foregroundStyle(DS.ColorToken.textPrimary)

            Text(infoText)
                .font(DS.Typography.body)
                .foregroundStyle(DS.ColorToken.textSecondary)

            Text("This is a one-time setup. Scheduled reminders will appear below.")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.ColorToken.textSecondary)
        }
        .padding(DS.Spacing.lg)
        .background(DS.ColorToken.appBackground)
    }

    private func lightHaptic() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
