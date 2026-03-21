//
//  SplashView.swift
//  Task Planner
//
//  Created by Руслан Меланин on 16.02.2026.
//

import SwiftUI

struct SplashView: View {
    let onFinished: () -> Void

    private let totalDuration: TimeInterval = 1.8
    private let mainAnim: TimeInterval = 1.1
    private let fadeOut: TimeInterval = 0.28

    @State private var appear = false
    @State private var glow = false
    @State private var fade = false
    @State private var didStart = false

    var body: some View {
        ZStack {
            DS.GradientToken.splash
                .ignoresSafeArea()

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
            guard !didStart else { return }
            didStart = true
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
        withAnimation(.easeOut(duration: mainAnim)) {
            appear = true
        }

        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            glow = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + (totalDuration - fadeOut)) {
            withAnimation(.easeIn(duration: fadeOut)) {
                fade = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + totalDuration) {
            onFinished()
        }
    }
}

#Preview {
    SplashView(onFinished: {})
}
