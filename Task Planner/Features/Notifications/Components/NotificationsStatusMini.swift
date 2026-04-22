//
//  NotificationsStatusMini.swift
//  Task Planner
//
//  Created by Руслан Меланин on 04.03.2026.
//

import SwiftUI
import UIKit

struct NotificationsStatusMini: View {
    @Environment(\.dsAdaptiveMetrics) private var dsMetrics

    @ObservedObject var viewModel: NotificationsViewModel

    private var pillTitle: String {
        viewModel.notificationsEnabled ? String(localized: "Enabled") : String(localized: "Disabled")
    }

    private var systemStatusTitle: String? {
        switch viewModel.systemStatus {
        case .notDetermined: return String(localized: "Permission not requested")
        case .denied: return String(localized: "Permission denied")
        case .authorized: return nil
        }
    }

    private var primaryActionTitle: String? {
        switch viewModel.systemStatus {
        case .notDetermined: return String(localized: "Enable")
        case .denied: return String(localized: "Settings")
        case .authorized: return nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: dsMetrics.spacing(8)) {
            HStack(spacing: dsMetrics.spacing(8)) {
                Text("Status")
                    .font(
                        dsMetrics.font(
                            13,
                            weight: .semibold,
                            category: .micro
                        )
                    )
                    .foregroundStyle(DS.ColorToken.textSecondary)

                StatusPill(title: pillTitle, isOn: viewModel.notificationsEnabled)
                    .scaleEffect(0.92, anchor: .leading)

                Spacer(minLength: dsMetrics.spacing(8))

                Toggle("", isOn: Binding(
                    get: { viewModel.notificationsEnabled },
                    set: { viewModel.setNotificationsEnabled($0) }
                ))
                .labelsHidden()
                .tint(DS.ColorToken.lavender)
                .accessibilityLabel("App notifications")
                .accessibilityValue(viewModel.notificationsEnabled ? "On" : "Off")
            }

            if let action = primaryActionTitle, let systemStatusTitle {
                HStack(spacing: dsMetrics.spacing(8)) {
                    Text(systemStatusTitle)
                        .font(
                            dsMetrics.font(
                                12,
                                weight: .medium,
                                category: .caption
                            )
                        )
                        .foregroundStyle(DS.ColorToken.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Spacer(minLength: dsMetrics.spacing(8))

                    Button {
                        lightHaptic()
                        viewModel.primaryActionTapped()
                    } label: {
                        Text(action)
                            .font(
                                dsMetrics.font(
                                    13,
                                    weight: .semibold,
                                    category: .micro
                                )
                            )
                            .foregroundStyle(DS.ColorToken.textPrimary)
                            .padding(.horizontal, dsMetrics.spacing(10))
                            .padding(.vertical, dsMetrics.spacing(7))
                            .background(
                                RoundedRectangle(cornerRadius: DS.Radius.pill)
                                    .fill(DS.ColorToken.controlFillStrong)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isLoading)
                    .opacity(viewModel.isLoading ? 0.6 : 1.0)
                    .accessibilityLabel(action)
                }
            }
        }
        .padding(.vertical, dsMetrics.spacing(2))
        .accessibilityElement(children: .contain)
    }

    private func lightHaptic() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
