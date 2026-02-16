//
//  SplashView.swift
//  Task Planner
//
//  Created by Руслан Меланин on 16.02.2026.
//

import SwiftUI

import SwiftUI

struct SplashView: View {
    let onFinished: () -> Void

    // timing
    private let totalDuration: TimeInterval = 1.15
    private let mainAnim: TimeInterval = 0.85
    private let fadeOut: TimeInterval = 0.22

    @State private var appear = false
    @State private var glow = false
    @State private var fade = false

    var body: some View {
        ZStack {
            // Full splash gradient (match LaunchScreen target)
            DS.GradientToken.splash
                .ignoresSafeArea()

            // subtle top "premium" veil
            LinearGradient(
                colors: [
                    Color.white.opacity(0.30),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()

            VStack(spacing: 14) {
                iconMark

                VStack(spacing: 6) {
                    Text("Task Planner")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.96))

                    Text("Plan your day beautifully")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.78))
                }
            }
            .scaleEffect(appear ? 1.0 : 0.92)
            .opacity(fade ? 0.0 : (appear ? 1.0 : 0.0))
        }
        .onAppear {
            runAnimation()
        }
    }

    private var iconMark: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.20))
                .overlay(
                    Circle()
                        .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
                )
                .shadow(color: Color.white.opacity(glow ? 0.18 : 0.06), radius: glow ? 20 : 10, x: 0, y: 10)
                .shadow(color: Color.black.opacity(0.10), radius: 22, x: 0, y: 16)

            Image(systemName: "calendar")
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.96))
        }
        .frame(width: 96, height: 96)
        .overlay(
            Circle()
                .stroke(Color.white.opacity(glow ? 0.22 : 0.0), lineWidth: glow ? 6 : 0)
                .blur(radius: 10)
        )
        .scaleEffect(appear ? 1.0 : 0.84)
    }

    private func runAnimation() {
        // Main entrance
        withAnimation(.easeOut(duration: mainAnim)) {
            appear = true
        }

        // Subtle breathing glow
        withAnimation(.easeInOut(duration: 0.95).repeatForever(autoreverses: true)) {
            glow = true
        }

        // Fade out at the end
        DispatchQueue.main.asyncAfter(deadline: .now() + (totalDuration - fadeOut)) {
            withAnimation(.easeIn(duration: fadeOut)) {
                fade = true
            }
        }

        // Finish -> AppRootView
        DispatchQueue.main.asyncAfter(deadline: .now() + totalDuration) {
            onFinished()
        }
    }
}

#Preview {
    SplashView(onFinished: {})
}
