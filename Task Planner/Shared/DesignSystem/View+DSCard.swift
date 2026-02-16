//
//  View+DSCard.swift
//  Task Planner
//
//  Created by Руслан Меланин on 16.02.2026.
//

import SwiftUI

extension View {

    func dsCard(padding: CGFloat = DS.Spacing.md) -> some View {
        dsCard(padding: padding) {
            DS.ColorToken.cardBackground
        }
    }

    func dsCard<Background: View>(
        padding: CGFloat = DS.Spacing.md,
        @ViewBuilder background: () -> Background
    ) -> some View {
        self
            .padding(padding)
            .background(background())
            .cornerRadius(DS.Radius.md)
            .shadow(color: DS.Shadow.soft, radius: 14, x: 0, y: 10)
    }
}
