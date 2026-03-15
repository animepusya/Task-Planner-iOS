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
                title: "By Category",
                value: .category
            )

            segmentButton(
                title: "By Task",
                value: .task
            )
        }
        .padding(4)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.78))
                .overlay(
                    Capsule()
                        .stroke(Color.black.opacity(0.05), lineWidth: 1)
                )
        )
        .shadow(color: DS.Shadow.soft, radius: 10, x: 0, y: 6)
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
