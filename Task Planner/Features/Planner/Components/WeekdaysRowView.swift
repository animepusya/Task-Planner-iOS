//
//  WeekdaysRowView.swift
//  Task Planner
//
//  Created by Руслан Меланин on 09.02.2026.
//

import SwiftUI

struct WeekdaysRowView: View {
    @Environment(\.dsAdaptiveMetrics) private var dsMetrics

    let symbols: [String]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(symbols, id: \.self) { sym in
                Text(sym)
                    .font(
                        dsMetrics.font(
                            12,
                            weight: .medium,
                            category: .caption
                        )
                    )
                    .foregroundColor(DS.ColorToken.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}
