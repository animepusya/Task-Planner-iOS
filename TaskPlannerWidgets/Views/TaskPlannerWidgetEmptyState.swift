//
//  TaskPlannerWidgetEmptyState.swift
//  TaskPlannerWidgetsExtension
//
//  Created by Руслан Меланин on 13.03.2026.
//

import SwiftUI
import WidgetKit

struct TaskPlannerWidgetEmptyState: View {
    let text: String
    let isAccented: Bool

    var body: some View {
        VStack {
            Spacer(minLength: 0)

            HStack {
                Spacer()
                
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isAccented ? .primary : DS.ColorToken.purple)
                    .widgetAccentable(isAccented)

                Text(text)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(
                        isAccented
                        ? AnyShapeStyle(.secondary)
                        : AnyShapeStyle(DS.ColorToken.textSecondary)
                    )
                    .multilineTextAlignment(.center)

                Spacer()
            }

            Spacer(minLength: 0)
        }
    }
}

