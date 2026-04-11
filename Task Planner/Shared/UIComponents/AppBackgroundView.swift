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
    let showsTopScrim: Bool

    init(
        gradient: LinearGradient = DS.GradientToken.splash,
        gradientOpacity: Double = 0.28,
        blurRadius: CGFloat = 18,
        showsTopScrim: Bool = true
    ) {
        self.gradient = gradient
        self.gradientOpacity = gradientOpacity
        self.blurRadius = blurRadius
        self.showsTopScrim = showsTopScrim
    }

    var body: some View {
        ZStack {
            DS.ColorToken.appBackground

            gradient
                .opacity(gradientOpacity)
                .blur(radius: blurRadius)

            if showsTopScrim {
                LinearGradient(
                    colors: [
                        DS.ColorToken.topScrim,
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .center
                )
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
