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
                .dsSurface(Circle(), fill: DS.Surface.chrome)
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
    }
}
