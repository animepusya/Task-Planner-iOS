//
//  SettingsCard.swift
//  Task Planner
//
//  Created by Руслан Меланин on 14.03.2026.
//

import SwiftUI

struct SettingsCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        VStack(spacing: 0) {
            content()
        }
        .dsCard(padding: 0) {
            DS.Surface.card
        }
    }
}
