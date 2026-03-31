//
//  StatisticsBreakdownSegmentedControl.swift
//  Task Planner
//
//  Created by Руслан Меланин on 15.03.2026.
//

import SwiftUI

struct StatisticsBreakdownSegmentedControl: View {
    @Binding var selection: StatisticsBreakdown

    @Namespace private var selectionNamespace

    var body: some View {
        HStack(spacing: 4) {
            segmentButton(
                title: StatisticsBreakdown.category.title,
                value: .category
            )

            segmentButton(
                title: StatisticsBreakdown.task.title,
                value: .task
            )
        }
        .padding(4)
        .dsSurface(Capsule(), fill: DS.Surface.frosted)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func segmentButton(
        title: String,
        value: StatisticsBreakdown
    ) -> some View {
        let isSelected = selection == value

        Button {
            guard selection != value else { return }

            withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                selection = value
            }
        } label: {
            ZStack {
                if isSelected {
                    Capsule()
                        .fill(DS.GradientToken.brand)
                        .matchedGeometryEffect(
                            id: "statistics_breakdown_selection",
                            in: selectionNamespace
                        )
                }

                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(isSelected ? Color.white : DS.ColorToken.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, 12)
                    .frame(height: 32)
            }
        }
        .buttonStyle(.plain)
        .contentShape(Capsule())
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
