//
//  StatisticsPeriodCard.swift
//  Task Planner
//
//  Created by Codex on 10.04.2026.
//

import SwiftUI

struct StatisticsPeriodCard: View {
    @ObservedObject var viewModel: StatisticsViewModel

    @EnvironmentObject private var subscriptionStore: SubscriptionStore

    @State private var isRangeSheetPresented = false

    var body: some View {
        HStack {
            navCircle("chevron.left", action: viewModel.goToPrevious)

            Spacer()

            Button {
                isRangeSheetPresented = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "calendar")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DS.ColorToken.purple)

                    Text(viewModel.snapshot.displayedTitle)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(DS.ColorToken.textPrimary)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 12)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Select period")

            Spacer()

            navCircle("chevron.right", action: viewModel.goToNext)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .dsSurface(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous),
            fill: DS.Surface.chrome
        )
        .sheet(isPresented: $isRangeSheetPresented) {
            StatisticsRangeSheet(
                range: $viewModel.range,
                anchorDate: $viewModel.anchorDate,
                weekStartsOnMonday: viewModel.weekStartsOnMonday
            )
            .environmentObject(subscriptionStore)
        }
    }

    private func navCircle(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(DS.ColorToken.textSecondary)
                .frame(width: 36, height: 36)
                .dsSurface(Circle(), fill: DS.Surface.chrome)
        }
        .buttonStyle(.plain)
    }
}
