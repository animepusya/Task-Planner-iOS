//
//  NotificationsSetupStrip.swift
//  Task Planner
//
//  Created by Руслан Меланин on 04.03.2026.
//

import SwiftUI
import UIKit

struct NotificationsSetupStrip: View {
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
            HStack(alignment: .top, spacing: DS.Spacing.sm) {
                NotificationsStatusMini(viewModel: viewModel)
                    .frame(maxWidth: .infinity, alignment: .leading)

                divider

                NotificationsDefaultsMini(viewModel: viewModel)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
        } else {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                NotificationsStatusMini(viewModel: viewModel)
                divider
                NotificationsDefaultsMini(viewModel: viewModel)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.black.opacity(0.06))
            .frame(height: 1)
            .padding(.vertical, 2)
            .accessibilityHidden(true)
    }
}
