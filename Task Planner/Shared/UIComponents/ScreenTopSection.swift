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
    let leadingTrailingSpacing: CGFloat
    let expandedTopPadding: CGFloat
    let compactTopPadding: CGFloat
    let expandedBottomPadding: CGFloat
    let compactBottomPadding: CGFloat
    let expandedTitleSize: CGFloat
    let compactTitleSize: CGFloat
    let expandedTitleSubtitleSpacing: CGFloat
    let compactTitleSubtitleSpacing: CGFloat
    let subtitleLineLimit: Int
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
        leadingTrailingSpacing: 12,
        expandedTopPadding: DS.Spacing.sm,
        compactTopPadding: 6,
        expandedBottomPadding: DS.Spacing.md,
        compactBottomPadding: 10,
        expandedTitleSize: 28,
        compactTitleSize: 24,
        expandedTitleSubtitleSpacing: 6,
        compactTitleSubtitleSpacing: 0,
        subtitleLineLimit: 1,
        expandedSubtitleHeight: 20,
        compactSubtitleHeight: 0
    )

    static let planner = ScreenTopSectionStyle(
        contentAlignment: .top,
        collapseDistance: 68,
        horizontalPadding: DS.Spacing.lg,
        leadingTrailingSpacing: 8,
        expandedTopPadding: DS.Spacing.sm,
        compactTopPadding: 7,
        expandedBottomPadding: DS.Spacing.sm,
        compactBottomPadding: 7,
        expandedTitleSize: 28,
        compactTitleSize: 24.5,
        expandedTitleSubtitleSpacing: 6,
        compactTitleSubtitleSpacing: 0,
        subtitleLineLimit: 2,
        expandedSubtitleHeight: 40,
        compactSubtitleHeight: 0
    )

    static let statistics = ScreenTopSectionStyle(
        contentAlignment: .center,
        collapseDistance: 52,
        horizontalPadding: DS.Spacing.lg,
        leadingTrailingSpacing: 12,
        expandedTopPadding: DS.Spacing.sm,
        compactTopPadding: 4,
        expandedBottomPadding: DS.Spacing.sm,
        compactBottomPadding: 6,
        expandedTitleSize: 28,
        compactTitleSize: 21.5,
        expandedTitleSubtitleSpacing: 0,
        compactTitleSubtitleSpacing: 0,
        subtitleLineLimit: 1,
        expandedSubtitleHeight: 0,
        compactSubtitleHeight: 0
    )
}

struct ScreenTopSection<Trailing: View>: View {
    @Environment(\.dsAdaptiveMetrics) private var dsMetrics

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
        let leadingPadding = dsMetrics.topSectionLeadingPadding(base: style.horizontalPadding)
        let trailingPadding = dsMetrics.topSectionTrailingPadding(base: style.horizontalPadding)
        let topPadding = interpolated(
            from: dsMetrics.spacing(style.expandedTopPadding),
            to: dsMetrics.spacing(style.compactTopPadding),
            progress: progress
        )
        let bottomPadding = interpolated(
            from: dsMetrics.spacing(style.expandedBottomPadding),
            to: dsMetrics.spacing(style.compactBottomPadding),
            progress: progress
        )
        let titleSize = interpolated(
            from: dsMetrics.fontSize(style.expandedTitleSize, category: .display),
            to: dsMetrics.fontSize(style.compactTitleSize, category: .title),
            progress: progress
        )
        let subtitleSpacing = interpolated(
            from: dsMetrics.spacing(style.expandedTitleSubtitleSpacing),
            to: dsMetrics.spacing(style.compactTitleSubtitleSpacing),
            progress: progress
        )
        let subtitleProgress = remappedProgress(
            progress,
            start: 0.04,
            end: 0.58
        )
        let subtitleHeight = interpolated(
            from: dsMetrics.spacing(style.expandedSubtitleHeight),
            to: dsMetrics.spacing(style.compactSubtitleHeight),
            progress: subtitleProgress
        )
        let subtitleVerticalOffset = -5 * subtitleProgress
        let subtitleFadeStart = interpolated(
            from: 0.98,
            to: 0.42,
            progress: subtitleProgress
        )
        let subtitleOpacity = style.expandedSubtitleHeight == 0
            ? 0
            : pow(max(0, 1 - subtitleProgress), 1.15)

        HStack(
            alignment: style.contentAlignment,
            spacing: dsMetrics.spacing(style.leadingTrailingSpacing)
        ) {
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(DS.Typography.screenTitle(size: titleSize))
                    .foregroundStyle(DS.ColorToken.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.92)
                    .allowsTightening(true)

                if let subtitle {
                    ScreenTopSectionSubtitleSlot(
                        subtitle: subtitle,
                        lineLimit: style.subtitleLineLimit,
                        fontSize: dsMetrics.fontSize(15, category: .body),
                        topSpacing: subtitleSpacing,
                        visibleHeight: subtitleHeight,
                        verticalOffset: subtitleVerticalOffset,
                        fadeStart: subtitleFadeStart,
                        opacity: subtitleOpacity
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            trailing()
                .fixedSize()
        }
        .padding(.leading, leadingPadding)
        .padding(.trailing, trailingPadding)
        .padding(.top, topPadding)
        .padding(.bottom, bottomPadding)
        .dsContentFrame(.wide)
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

    private func remappedProgress(
        _ progress: CGFloat,
        start: CGFloat,
        end: CGFloat
    ) -> CGFloat {
        guard end > start else { return progress >= end ? 1 : 0 }
        return max(0, min(1, (progress - start) / (end - start)))
    }
}

private struct ScreenTopSectionSubtitleSlot: View {
    let subtitle: String
    let lineLimit: Int
    let fontSize: CGFloat
    let topSpacing: CGFloat
    let visibleHeight: CGFloat
    let verticalOffset: CGFloat
    let fadeStart: CGFloat
    let opacity: CGFloat

    var body: some View {
        let slotHeight = max(0, topSpacing + visibleHeight)

        Color.clear
            .frame(height: slotHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .topLeading) {
                Text(subtitle)
                    .font(DS.Typography.screenSubtitle(size: fontSize))
                    .foregroundStyle(DS.ColorToken.textSecondary)
                    .lineLimit(lineLimit)
                    .multilineTextAlignment(.leading)
                    .minimumScaleFactor(0.92)
                    .allowsTightening(true)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, topSpacing)
                    .offset(y: verticalOffset)
                    .mask {
                        LinearGradient(
                            stops: [
                                .init(color: .black, location: 0),
                                .init(color: .black, location: fadeStart),
                                .init(color: .clear, location: 1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                    .opacity(opacity)
            }
            .clipped()
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
