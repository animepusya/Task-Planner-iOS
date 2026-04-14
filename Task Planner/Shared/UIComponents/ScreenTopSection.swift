//
//  ScreenTopSection.swift
//  Task Planner
//
//  Created by Руслан Меланин on 13.03.2026.
//

import SwiftUI

struct ScreenTopSectionStyle {
    let contentAlignment: VerticalAlignment
    let collapseDistance: CGFloat
    let horizontalPadding: CGFloat
    let expandedTopPadding: CGFloat
    let compactTopPadding: CGFloat
    let expandedBottomPadding: CGFloat
    let compactBottomPadding: CGFloat
    let expandedTitleSize: CGFloat
    let compactTitleSize: CGFloat
    let expandedTitleSubtitleSpacing: CGFloat
    let compactTitleSubtitleSpacing: CGFloat
    let expandedSubtitleHeight: CGFloat
    let compactSubtitleHeight: CGFloat

    func collapseProgress(for scrollOffset: CGFloat) -> CGFloat {
        guard collapseDistance > 0 else { return 0 }
        return max(0, min(1, scrollOffset / collapseDistance))
    }

    static let standard = ScreenTopSectionStyle(
        contentAlignment: .top,
        collapseDistance: 64,
        horizontalPadding: DS.Spacing.lg,
        expandedTopPadding: DS.Spacing.sm,
        compactTopPadding: 6,
        expandedBottomPadding: DS.Spacing.md,
        compactBottomPadding: 10,
        expandedTitleSize: 28,
        compactTitleSize: 24,
        expandedTitleSubtitleSpacing: 6,
        compactTitleSubtitleSpacing: 0,
        expandedSubtitleHeight: 20,
        compactSubtitleHeight: 0
    )

    static let planner = ScreenTopSectionStyle(
        contentAlignment: .top,
        collapseDistance: 68,
        horizontalPadding: DS.Spacing.lg,
        expandedTopPadding: DS.Spacing.sm,
        compactTopPadding: 7,
        expandedBottomPadding: DS.Spacing.md,
        compactBottomPadding: 11,
        expandedTitleSize: 28,
        compactTitleSize: 24.5,
        expandedTitleSubtitleSpacing: 6,
        compactTitleSubtitleSpacing: 0,
        expandedSubtitleHeight: 20,
        compactSubtitleHeight: 0
    )

    static let statistics = ScreenTopSectionStyle(
        contentAlignment: .center,
        collapseDistance: 52,
        horizontalPadding: DS.Spacing.lg,
        expandedTopPadding: DS.Spacing.sm,
        compactTopPadding: 4,
        expandedBottomPadding: DS.Spacing.md,
        compactBottomPadding: 8,
        expandedTitleSize: 28,
        compactTitleSize: 21.5,
        expandedTitleSubtitleSpacing: 0,
        compactTitleSubtitleSpacing: 0,
        expandedSubtitleHeight: 0,
        compactSubtitleHeight: 0
    )
}

struct ScreenTopSection<Trailing: View>: View {
    let title: String
    let subtitle: String?
    let collapseProgress: CGFloat
    let style: ScreenTopSectionStyle
    @ViewBuilder let trailing: () -> Trailing

    init(
        title: String,
        subtitle: String? = nil,
        collapseProgress: CGFloat = 0,
        style: ScreenTopSectionStyle = .standard,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.collapseProgress = collapseProgress
        self.style = style
        self.trailing = trailing
    }

    var body: some View {
        let progress = max(0, min(1, collapseProgress))
        let topPadding = interpolated(
            from: style.expandedTopPadding,
            to: style.compactTopPadding,
            progress: progress
        )
        let bottomPadding = interpolated(
            from: style.expandedBottomPadding,
            to: style.compactBottomPadding,
            progress: progress
        )
        let titleSize = interpolated(
            from: style.expandedTitleSize,
            to: style.compactTitleSize,
            progress: progress
        )
        let subtitleSpacing = interpolated(
            from: style.expandedTitleSubtitleSpacing,
            to: style.compactTitleSubtitleSpacing,
            progress: progress
        )
        let subtitleHeight = interpolated(
            from: style.expandedSubtitleHeight,
            to: style.compactSubtitleHeight,
            progress: progress
        )
        let subtitleOpacity = style.expandedSubtitleHeight == 0
            ? 0
            : max(0, 1 - (progress * 1.2))

        HStack(alignment: style.contentAlignment, spacing: DS.Spacing.md) {
            VStack(alignment: .leading, spacing: subtitle == nil ? 0 : subtitleSpacing) {
                Text(title)
                    .font(DS.Typography.screenTitle(size: titleSize))
                    .foregroundStyle(DS.ColorToken.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.92)

                if let subtitle {
                    Text(subtitle)
                        .font(DS.Typography.screenSubtitle())
                        .foregroundStyle(DS.ColorToken.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.88)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: subtitleHeight, alignment: .topLeading)
                        .clipped()
                        .opacity(subtitleOpacity)
                }
            }

            Spacer(minLength: 12)

            trailing()
                .fixedSize()
        }
        .padding(.horizontal, style.horizontalPadding)
        .padding(.top, topPadding)
        .padding(.bottom, bottomPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ScreenTopSectionBackground()
        }
    }

    private func interpolated(
        from start: CGFloat,
        to end: CGFloat,
        progress: CGFloat
    ) -> CGFloat {
        start + ((end - start) * progress)
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
