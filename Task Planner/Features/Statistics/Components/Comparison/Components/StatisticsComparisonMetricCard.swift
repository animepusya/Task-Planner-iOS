//
//  StatisticsComparisonMetricCard.swift
//  Task Planner
//
//  Created by Codex on 08.04.2026.
//

import SwiftUI

struct StatisticsComparisonMetricCard: View {
    let metric: StatisticsComparisonMetricSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                if metric.showsTrendIndicator {
                    Image(systemName: metric.direction.symbolName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(metric.direction.tintColor)
                        .frame(width: 22, height: 22)
                        .background(metric.direction.backgroundColor, in: Circle())
                }

                Text(metric.title)
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.ColorToken.textSecondary)
                    .lineLimit(1)
            }

            Text(metric.valueText)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(DS.ColorToken.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.85)

            if let subtitle = metric.subtitle {
                Text(subtitle)
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.ColorToken.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsCard(padding: DS.Spacing.md, cornerRadius: DS.Radius.md) {
            DS.Surface.chrome
        }
    }
}
