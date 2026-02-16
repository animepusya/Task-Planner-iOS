//
//  AppBackgroundView.swift
//  Task Planner
//
//  Created by Руслан Меланин on 16.02.2026.
//

import SwiftUI

struct AppBackgroundView: View {
    let gradient: LinearGradient
    let gradientOpacity: Double
    let blurRadius: CGFloat

    init(
        gradient: LinearGradient = DS.GradientToken.splash,
        gradientOpacity: Double = 0.28,
        blurRadius: CGFloat = 18
    ) {
        self.gradient = gradient
        self.gradientOpacity = gradientOpacity
        self.blurRadius = blurRadius
    }

    var body: some View {
        ZStack {
            DS.ColorToken.appBackground

            gradient
                .opacity(gradientOpacity)
                .blur(radius: blurRadius)
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.white.opacity(0.55),
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
