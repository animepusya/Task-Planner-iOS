//
//  AppBackgroundView.swift
//  Task Planner
//
//  Created by Руслан Меланин on 16.02.2026.
//

import SwiftUI

struct AppBackgroundView: View {
    var body: some View {
        ZStack {
            DS.ColorToken.appBackground

            DS.GradientToken.splash
                .opacity(0.28)
                .blur(radius: 18)
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.white.opacity(0.60),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
    }
}
