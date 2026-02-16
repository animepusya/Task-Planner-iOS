//
//  SplashView.swift
//  Task Planner
//
//  Created by Руслан Меланин on 16.02.2026.
//

import SwiftUI

struct SplashView: View {
    let onFinished: () -> Void

    @State private var breathe = false
    @State private var didScheduleFinish = false

    var body: some View {
        ZStack {
            // Фон должен совпадать с launch screen по палитре
            DS.GradientToken.splash
                .ignoresSafeArea()

            // Очень лёгкая “вышка” сверху — делает дороже
            LinearGradient(
                colors: [
                    Color.white.opacity(0.45),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                logoMark
                titleBlock
            }
            .padding(.horizontal, DS.Spacing.xl)
        }
        .allowsHitTesting(false) // splash не должен мешать системным жестам
        .onAppear {
            withAnimation(.easeInOut(duration: 0.95).repeatForever(autoreverses: true)) {
                breathe = true
            }

            guard !didScheduleFinish else { return }
            didScheduleFinish = true

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.15) {
                onFinished()
            }
        }
    }

    // MARK: - Pieces

    private var logoMark: some View {
        ZStack {
            // “Стеклянный” бейдж вместо грубого круга
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.28))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.35), lineWidth: 1)
                )
                .frame(width: 124, height: 124)
                .shadow(color: Color.black.opacity(0.10), radius: 18, x: 0, y: 10)

            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 44, weight: .semibold, design: .rounded))
                .foregroundStyle(DS.ColorToken.purpleDark.opacity(0.92))
        }
        .scaleEffect(breathe ? 1.03 : 0.97)
        .opacity(breathe ? 1.0 : 0.86)
    }

    private var titleBlock: some View {
        VStack(spacing: 6) {
            Text("Task Planner")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(DS.ColorToken.textPrimary)

            Text("Organize your day with ease")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(DS.ColorToken.textSecondary)
        }
    }
}
