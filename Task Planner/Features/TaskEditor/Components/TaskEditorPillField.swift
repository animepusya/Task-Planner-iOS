//
//  TaskEditorPillField.swift
//  Task Planner
//
//  Created by Руслан Меланин on 11.02.2026.
//

import SwiftUI

struct TaskEditorPillField<Trailing: View>: View {
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
        VStack(alignment: .leading, spacing: 6) {
            if let title {
                Text(title)
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.ColorToken.textSecondary)
            } else if reservesTitleSpace {
                Color.clear
                    .frame(height: 14)
            }

            HStack(spacing: 8) {
                if showsIcon {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DS.ColorToken.textSecondary)
                        .frame(width: 18, alignment: .center)
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
            .padding(10)
            .background(DS.ColorToken.controlFill)
            .cornerRadius(DS.Radius.sm)
            .overlay {
                if let pillOverlayFill {
                    RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                        .fill(pillOverlayFill)
                        .allowsHitTesting(false)
                }
            }
        }
    }
}
