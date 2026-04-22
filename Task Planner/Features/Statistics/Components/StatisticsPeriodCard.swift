//
//  StatisticsPeriodCard.swift
//  Task Planner
//
//  Created by Codex on 10.04.2026.
//

import SwiftUI

struct StatisticsPeriodCard: View {
    @ObservedObject var viewModel: StatisticsViewModel
    @Environment(\.dsAdaptiveMetrics) private var dsMetrics

    @EnvironmentObject private var subscriptionStore: SubscriptionStore

    @State private var isRangeSheetPresented = false

    var body: some View {
        HStack {
            navCircle("chevron.left", action: viewModel.goToPrevious)

            Spacer()

            Button {
                isRangeSheetPresented = true
            } label: {
                HStack(spacing: dsMetrics.spacing(10)) {
                    Image(systemName: "calendar")
                        .font(
                            dsMetrics.font(
                                14,
                                weight: .semibold,
                                category: .micro
                            )
                        )
                        .foregroundStyle(DS.ColorToken.purple)

                    Text(viewModel.snapshot.displayedTitle)
                        .font(
                            dsMetrics.font(
                                16,
                                weight: .semibold,
                                category: .title
                            )
                        )
                        .foregroundStyle(DS.ColorToken.textPrimary)
                }
                .padding(.vertical, dsMetrics.spacing(12))
                .padding(.horizontal, dsMetrics.spacing(12))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Select period")

            Spacer()

            navCircle("chevron.right", action: viewModel.goToNext)
        }
        .padding(.horizontal, dsMetrics.spacing(12))
        .padding(.vertical, dsMetrics.spacing(8))
        .dsPrimaryCard(padding: 0, cornerRadius: DS.Radius.md)
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
                .font(
                    dsMetrics.font(
                        14,
                        weight: .semibold,
                        category: .micro
                    )
                )
                .foregroundColor(DS.ColorToken.textSecondary)
                .frame(
                    width: dsMetrics.controlSize(36),
                    height: dsMetrics.controlSize(36)
                )
                .dsSurface(Circle(), fill: DS.Surface.chrome)
        }
        .buttonStyle(.plain)
    }
}
