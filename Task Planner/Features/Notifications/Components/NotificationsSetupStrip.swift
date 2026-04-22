//
//  NotificationsSetupStrip.swift
//  Task Planner
//
//  Created by Руслан Меланин on 04.03.2026.
//

import SwiftUI
import UIKit

struct NotificationsSetupStrip: View {
    @Environment(\.dsAdaptiveMetrics) private var dsMetrics

    @ObservedObject var viewModel: NotificationsViewModel

    var body: some View {
        WidthReader { width in
            content(for: width)
                .dsCard(padding: DS.Spacing.sm)
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func content(for width: CGFloat) -> some View {
        // На iPhone 13 mini в портрете часто < 360 по внутренней ширине списка.
        if width >= 360 {
            HStack(alignment: .top, spacing: dsMetrics.spacing(DS.Spacing.sm)) {
                NotificationsStatusMini(viewModel: viewModel)
                    .frame(maxWidth: .infinity, alignment: .leading)

                divider

                NotificationsDefaultsMini(viewModel: viewModel)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, dsMetrics.spacing(6))
            .padding(.vertical, dsMetrics.spacing(4))
        } else {
            VStack(alignment: .leading, spacing: dsMetrics.spacing(DS.Spacing.xs)) {
                NotificationsStatusMini(viewModel: viewModel)
                divider
                NotificationsDefaultsMini(viewModel: viewModel)
            }
            .padding(.horizontal, dsMetrics.spacing(6))
            .padding(.vertical, dsMetrics.spacing(4))
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(DS.Border.subtle)
            .frame(height: dsMetrics.strokeWidth(1))
            .padding(.vertical, dsMetrics.spacing(2))
            .accessibilityHidden(true)
    }
}
