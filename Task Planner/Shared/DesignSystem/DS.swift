//
//  DS.swift
//  Task Planner
//
//  Created by Руслан Меланин on 09.02.2026.
//

import SwiftUI
import UIKit

enum DS {
    fileprivate enum AssetName {
        static let brandPurple = "DSBrandPurple"
        static let brandPurpleDark = "DSBrandPurpleDark"
        static let brandLavender = "DSBrandLavender"
        static let brandLightPink = "DSBrandLightPink"
        static let brandPink = "DSBrandPink"

        static let appBackground = "DSAppBackground"
        static let cardBackground = "DSCardBackground"
        static let textPrimary = "DSTextPrimary"
        static let textSecondary = "DSTextSecondary"

        static let borderSubtle = "DSBorderSubtle"
        static let borderMuted = "DSBorderMuted"
        static let borderInverted = "DSBorderInverted"

        static let surfaceCard = "DSSurfaceCard"
        static let surfaceChrome = "DSSurfaceChrome"
        static let surfaceFrosted = "DSSurfaceFrosted"

        static let controlFill = "DSControlFill"
        static let controlFillStrong = "DSControlFillStrong"
        static let disabledOverlay = "DSDisabledOverlay"
        static let topScrim = "DSBackgroundTopScrim"
        static let brandCardOverlay = "DSBrandCardOverlay"
        static let surfaceHighlightStrong = "DSSurfaceHighlightStrong"
        static let surfaceHighlightSoft = "DSSurfaceHighlightSoft"
    }

    fileprivate static func assetColor(_ name: String, fallback: Color) -> Color {
        guard let uiColor = UIColor(named: name) else {
            return fallback
        }

        return Color(uiColor)
    }

    enum CardStyle {
        case solid
        case outlined
    }

    enum Spacing {
        static let xs: CGFloat = 6
        static let sm: CGFloat = 10
        static let md: CGFloat = 16
        static let lg: CGFloat = 22
        static let xl: CGFloat = 28
    }

    enum Layout {
        static let tabBarMinHeight: CGFloat = 42
        static let tabBarBottomSpacing: CGFloat = 6
        static let tabBarReservedScrollSpace: CGFloat = 72
    }

    enum Radius {
        static let sm: CGFloat = 12
        static let md: CGFloat = 18
        static let lg: CGFloat = 26
        static let pill: CGFloat = 999
    }

    enum Border {
        static let subtle = DS.assetColor(
            AssetName.borderSubtle,
            fallback: Color.black.opacity(0.045)
        )
        static let muted = DS.assetColor(
            AssetName.borderMuted,
            fallback: Color.black.opacity(0.025)
        )
        static let inverted = DS.assetColor(
            AssetName.borderInverted,
            fallback: Color.white.opacity(0.18)
        )
    }

    enum ColorToken {
        static let purple = DS.assetColor(
            AssetName.brandPurple,
            fallback: Color(red: 0.55, green: 0.39, blue: 0.98)
        )
        static let purpleDark = DS.assetColor(
            AssetName.brandPurpleDark,
            fallback: Color(red: 0.38, green: 0.23, blue: 0.82)
        )
        static let brandPink = DS.assetColor(
            AssetName.brandPink,
            fallback: Color(red: 0.98, green: 0.42, blue: 0.77)
        )

        static let appBackground = DS.assetColor(
            AssetName.appBackground,
            fallback: Color(red: 0.98, green: 0.98, blue: 1.00)
        )
        static let cardBackground = DS.assetColor(
            AssetName.cardBackground,
            fallback: Color.white
        )

        static let lavender = DS.assetColor(
            AssetName.brandLavender,
            fallback: Color(red: 0.85, green: 0.82, blue: 0.98)
        )
        static let lightPink = DS.assetColor(
            AssetName.brandLightPink,
            fallback: Color(red: 0.98, green: 0.83, blue: 0.92)
        )

        static let textPrimary = DS.assetColor(
            AssetName.textPrimary,
            fallback: Color(red: 0.12, green: 0.12, blue: 0.16)
        )
        static let textSecondary = DS.assetColor(
            AssetName.textSecondary,
            fallback: Color(red: 0.45, green: 0.45, blue: 0.52)
        )
        static let controlFill = DS.assetColor(
            AssetName.controlFill,
            fallback: Color.black.opacity(0.04)
        )
        static let controlFillStrong = DS.assetColor(
            AssetName.controlFillStrong,
            fallback: Color.black.opacity(0.06)
        )
        static let disabledOverlay = DS.assetColor(
            AssetName.disabledOverlay,
            fallback: Color.white.opacity(0.35)
        )
        static let topScrim = DS.assetColor(
            AssetName.topScrim,
            fallback: Color.white.opacity(0.55)
        )
        static let brandCardOverlay = DS.assetColor(
            AssetName.brandCardOverlay,
            fallback: Color.white.opacity(0.62)
        )
        static let surfaceHighlightStrong = DS.assetColor(
            AssetName.surfaceHighlightStrong,
            fallback: Color.white.opacity(0.55)
        )
        static let surfaceHighlightSoft = DS.assetColor(
            AssetName.surfaceHighlightSoft,
            fallback: Color.white.opacity(0.18)
        )
    }

    enum Surface {
        static let card = DS.assetColor(
            AssetName.surfaceCard,
            fallback: Color.white.opacity(0.94)
        )
        static let chrome = DS.assetColor(
            AssetName.surfaceChrome,
            fallback: Color.white.opacity(0.90)
        )
        static let frosted = DS.assetColor(
            AssetName.surfaceFrosted,
            fallback: Color.white.opacity(0.78)
        )
    }

    enum GradientToken {
        static let splash = LinearGradient(
            colors: [ColorToken.lavender, ColorToken.lightPink],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let brand = LinearGradient(
            colors: [ColorToken.purple, ColorToken.purpleDark],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let brandPink = LinearGradient(
            colors: [
                ColorToken.brandPink,
                ColorToken.purple
            ],
            startPoint: .leading,
            endPoint: .trailing
        )

        static let pinkPurpleSoft = LinearGradient(
            colors: [
                ColorToken.lightPink,
                ColorToken.lavender
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let cardTopHighlight = LinearGradient(
            colors: [
                ColorToken.surfaceHighlightStrong,
                ColorToken.surfaceHighlightSoft,
                Color.clear
            ],
            startPoint: .top,
            endPoint: .bottom
        )

        @ViewBuilder
        static var pinkPurpleCardBackground: some View {
            ZStack {
                pinkPurpleSoft
                    .opacity(0.90)

                ColorToken.brandCardOverlay
            }
        }
    }

    enum Typography {
        static let title = Font.system(size: 28, weight: .bold, design: .rounded)
        static let subtitle = Font.system(size: 15, weight: .medium, design: .rounded)
        static let sectionTitle = Font.system(size: 18, weight: .semibold, design: .rounded)
        static let body = Font.system(size: 15, weight: .regular, design: .rounded)
        static let caption = Font.system(size: 12, weight: .medium, design: .rounded)

        static func screenTitle(size: CGFloat) -> Font {
            .system(size: size, weight: .bold, design: .rounded)
        }

        static func screenSubtitle(size: CGFloat = 15) -> Font {
            .system(size: size, weight: .medium, design: .rounded)
        }
    }
}

enum DSContentWidthRole {
    case screen
    case wide
    case modal
}

struct DSAdaptiveMetrics: Equatable {
    enum FontCategory {
        case display
        case title
        case body
        case caption
        case micro
    }

    let containerSize: CGSize
    let safeAreaInsets: EdgeInsets
    let horizontalSizeClass: UserInterfaceSizeClass?
    let verticalSizeClass: UserInterfaceSizeClass?
    let idiom: UIUserInterfaceIdiom

    static let fallback = DSAdaptiveMetrics(
        containerSize: .zero,
        safeAreaInsets: EdgeInsets(),
        horizontalSizeClass: nil,
        verticalSizeClass: nil,
        idiom: UIDevice.current.userInterfaceIdiom
    )

    var isLargePad: Bool {
        idiom == .pad
        && horizontalSizeClass == .regular
        && containerSize.width >= 900
        && max(containerSize.width, containerSize.height) >= 1024
    }

    var tabBarMinHeight: CGFloat {
        isLargePad ? 60 : DS.Layout.tabBarMinHeight
    }

    var tabBarBottomSpacing: CGFloat {
        isLargePad ? 12 : DS.Layout.tabBarBottomSpacing
    }

    var tabBarReservedScrollSpace: CGFloat {
        isLargePad ? 104 : DS.Layout.tabBarReservedScrollSpace
    }

    var sheetCornerRadius: CGFloat {
        isLargePad ? 44 : 32
    }

    func spacing(_ value: CGFloat) -> CGFloat {
        scale(value, by: 1.35)
    }

    func screenPadding(_ value: CGFloat) -> CGFloat {
        scale(value, by: 1.5)
    }

    func controlSize(_ value: CGFloat) -> CGFloat {
        scale(value, by: 1.55)
    }

    func detailSize(_ value: CGFloat) -> CGFloat {
        guard isLargePad, value > 0 else { return value }
        return rounded(max(value * 3.0, value + 6))
    }

    func cornerRadius(_ value: CGFloat) -> CGFloat {
        scale(value, by: 1.35)
    }

    func strokeWidth(_ value: CGFloat) -> CGFloat {
        guard isLargePad else { return value }
        return value * 1.2
    }

    func fontSize(_ value: CGFloat, category: FontCategory = .body) -> CGFloat {
        guard isLargePad, value > 0 else { return value }

        let multiplier: CGFloat
        switch category {
        case .display:
            multiplier = 1.45
        case .title:
            multiplier = 1.34
        case .body:
            multiplier = 1.2
        case .caption:
            multiplier = 1.28
        case .micro:
            multiplier = 1.42
        }

        return rounded(value * multiplier)
    }

    func font(
        _ size: CGFloat,
        weight: Font.Weight,
        design: Font.Design = .rounded,
        category: FontCategory = .body
    ) -> Font {
        .system(
            size: fontSize(size, category: category),
            weight: weight,
            design: design
        )
    }

    func maxWidth(for role: DSContentWidthRole) -> CGFloat? {
        guard isLargePad else { return nil }

        switch role {
        case .screen:
            return 920
        case .wide:
            return 980
        case .modal:
            return 860
        }
    }

    func topSectionLeadingPadding(base: CGFloat) -> CGFloat {
        let basePadding = screenPadding(base)
        guard isLargePad else { return basePadding }
        return max(basePadding, safeAreaInsets.leading + 24)
    }

    func topSectionTrailingPadding(base: CGFloat) -> CGFloat {
        let basePadding = screenPadding(base)
        guard isLargePad else { return basePadding }
        return max(basePadding, 32)
    }

    private func scale(_ value: CGFloat, by multiplier: CGFloat) -> CGFloat {
        guard isLargePad, value != 0 else { return value }
        return rounded(value * multiplier)
    }

    private func rounded(_ value: CGFloat) -> CGFloat {
        (value * 2).rounded() / 2
    }
}

private struct DSAdaptiveMetricsKey: EnvironmentKey {
    static let defaultValue: DSAdaptiveMetrics = .fallback
}

extension EnvironmentValues {
    var dsAdaptiveMetrics: DSAdaptiveMetrics {
        get { self[DSAdaptiveMetricsKey.self] }
        set { self[DSAdaptiveMetricsKey.self] = newValue }
    }
}

struct DSAdaptiveLayoutScope<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private let content: (DSAdaptiveMetrics) -> Content

    init(@ViewBuilder content: @escaping (DSAdaptiveMetrics) -> Content) {
        self.content = content
    }

    var body: some View {
        GeometryReader { proxy in
            let metrics = DSAdaptiveMetrics(
                containerSize: proxy.size,
                safeAreaInsets: proxy.safeAreaInsets,
                horizontalSizeClass: horizontalSizeClass,
                verticalSizeClass: verticalSizeClass,
                idiom: UIDevice.current.userInterfaceIdiom
            )

            content(metrics)
                .environment(\.dsAdaptiveMetrics, metrics)
                .frame(
                    width: proxy.size.width,
                    height: proxy.size.height,
                    alignment: .topLeading
                )
        }
    }
}
