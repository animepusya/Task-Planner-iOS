//
//  ScreenTopSection.swift
//  Task Planner
//
//  Created by Руслан Меланин on 13.03.2026.
//

import SwiftUI

struct ScreenTopSection<Trailing: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder let trailing: () -> Trailing

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: subtitle == nil ? .center : .top, spacing: DS.Spacing.md) {
            VStack(alignment: .leading, spacing: subtitle == nil ? 0 : 6) {
                Text(title)
                    .font(DS.Typography.title)
                    .foregroundStyle(DS.ColorToken.textPrimary)

                if let subtitle {
                    Text(subtitle)
                        .font(DS.Typography.subtitle)
                        .foregroundStyle(DS.ColorToken.textSecondary)
                }
            }

            Spacer(minLength: 12)

            trailing()
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.top, DS.Spacing.sm)
        .padding(.bottom, DS.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ScreenTopSectionBackground()
        }
    }
}

private struct ScreenTopSectionBackground: View {
    var body: some View {
        Rectangle()
            .fill(.thinMaterial)
            .overlay {
                LinearGradient(
                    stops: [
                        .init(color: DS.ColorToken.appBackground.opacity(0.42), location: 0.0),
                        .init(color: DS.ColorToken.appBackground.opacity(0.28), location: 0.40),
                        .init(color: DS.ColorToken.appBackground.opacity(0.18), location: 0.74),
                        .init(color: Color.clear, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .compositingGroup()
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.70), location: 0.0),
                        .init(color: .black.opacity(0.70), location: 0.28),
                        .init(color: .black.opacity(0.70), location: 0.58),
                        .init(color: .black.opacity(0.28), location: 0.84),
                        .init(color: .clear, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)
    }
}
