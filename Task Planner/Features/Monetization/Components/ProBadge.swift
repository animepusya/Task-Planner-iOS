//
//  ProBadge.swift
//  Task Planner
//
//  Created by Codex on 04.04.2026.
//

import SwiftUI

struct ProBadge: View {
    enum Size {
        case small
        case regular

        var primaryFont: CGFloat {
            switch self {
            case .small:
                return 10
            case .regular:
                return 12
            }
        }

        var secondaryFont: CGFloat {
            switch self {
            case .small:
                return 7
            case .regular:
                return 8
            }
        }

        var symbolOffset: CGSize {
            switch self {
            case .small:
                return CGSize(width: 6, height: -5)
            case .regular:
                return CGSize(width: 8, height: -6)
            }
        }

        var opticalCenterOffset: CGSize {
            switch self {
            case .small:
                return CGSize(width: -2, height: 1.5)
            case .regular:
                return CGSize(width: -2.5, height: 1.75)
            }
        }
    }

    let size: Size

    init(size: Size = .regular) {
        self.size = size
    }

    var body: some View {
        ZStack {
            Image(systemName: "sparkles")
                .font(.system(size: size.primaryFont, weight: .semibold))
                .foregroundStyle(DS.GradientToken.brandPink)

            Image(systemName: "sparkle")
                .font(.system(size: size.secondaryFont, weight: .semibold))
                .foregroundStyle(DS.ColorToken.purple.opacity(0.95))
                .offset(size.symbolOffset)
        }
        .offset(size.opticalCenterOffset)
        .accessibilityHidden(true)
    }
}

