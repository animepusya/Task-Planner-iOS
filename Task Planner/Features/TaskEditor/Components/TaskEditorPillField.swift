//
//  TaskEditorPillField.swift
//  Task Planner
//
//  Created by Руслан Меланин on 11.02.2026.
//

import SwiftUI

struct TaskEditorPillField<Trailing: View>: View {
    @Environment(\.dsAdaptiveMetrics) private var dsMetrics

    let title: String?
    let icon: String
    let trailingMinWidth: CGFloat
    let trailingMaxWidth: CGFloat?
    let trailingAlignment: Alignment
    let expandsTrailing: Bool
    let showsIcon: Bool
    let reservesTitleSpace: Bool
    let pillOverlayFill: Color?

    @ViewBuilder var trailing: () -> Trailing

    init(
        title: String?,
        icon: String,
        trailingMinWidth: CGFloat = 0,
        trailingMaxWidth: CGFloat? = nil,
        trailingAlignment: Alignment = .trailing,
        expandsTrailing: Bool = false,
        showsIcon: Bool = true,
        reservesTitleSpace: Bool = true,
        pillOverlayFill: Color? = nil,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.title = title
        self.icon = icon
        self.trailingMinWidth = trailingMinWidth
        self.trailingMaxWidth = trailingMaxWidth
        self.trailingAlignment = trailingAlignment
        self.expandsTrailing = expandsTrailing
        self.showsIcon = showsIcon
        self.reservesTitleSpace = reservesTitleSpace
        self.pillOverlayFill = pillOverlayFill
        self.trailing = trailing
    }

    var body: some View {
        VStack(alignment: .leading, spacing: dsMetrics.spacing(6)) {
            if let title {
                Text(title)
                    .font(
                        dsMetrics.font(
                            12,
                            weight: .medium,
                            category: .caption
                        )
                    )
                    .foregroundStyle(DS.ColorToken.textSecondary)
            } else if reservesTitleSpace {
                Color.clear
                    .frame(height: dsMetrics.spacing(14))
            }

            HStack(spacing: dsMetrics.spacing(8)) {
                if showsIcon {
                    Image(systemName: icon)
                        .font(
                            dsMetrics.font(
                                13,
                                weight: .semibold,
                                category: .micro
                            )
                        )
                        .foregroundStyle(DS.ColorToken.textSecondary)
                        .frame(width: dsMetrics.controlSize(18), alignment: .center)
                }

                trailing()
                    .frame(
                        minWidth: trailingMinWidth,
                        maxWidth: expandsTrailing ? .infinity : trailingMaxWidth,
                        alignment: trailingAlignment
                    )
                    .layoutPriority(expandsTrailing ? 1 : 0)
                    .clipped()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(dsMetrics.spacing(10))
            .background(DS.ColorToken.controlFill)
            .cornerRadius(dsMetrics.cornerRadius(DS.Radius.sm))
            .overlay {
                if let pillOverlayFill {
                    RoundedRectangle(
                        cornerRadius: dsMetrics.cornerRadius(DS.Radius.sm),
                        style: .continuous
                    )
                        .fill(pillOverlayFill)
                        .allowsHitTesting(false)
                }
            }
        }
    }
}
