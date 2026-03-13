//
//  IconCircleButton.swift
//  Task Planner
//
//  Created by Руслан Меланин on 09.02.2026.
//

import Foundation
import SwiftUI

struct IconCircleButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(DS.ColorToken.textPrimary)
                .frame(width: 42, height: 42)
                .background(
                    Circle().fill(Color.white.opacity(0.86))
                )
                .overlay(
                    Circle()
                        .stroke(Color.black.opacity(0.05), lineWidth: 1)
                )
                .shadow(color: DS.Shadow.soft, radius: 10, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
    }
}
