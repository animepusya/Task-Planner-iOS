//
//  WidthReader.swift
//  Task Planner
//
//  Created by Руслан Меланин on 04.03.2026.
//

import SwiftUI

/// Положил в Shared/UIComponents, потому что:
/// 1) измерение ширины — общий UI-хелпер (может пригодиться в Settings/Statistics/Planner);
/// 2) не завязан на Notifications, без бизнес-логики;
/// 3) снижает риск дублирования подобных PreferenceKey в других фичах.
struct WidthReader<Content: View>: View {
    let content: (CGFloat) -> Content
    @State private var width: CGFloat = 0

    init(@ViewBuilder content: @escaping (CGFloat) -> Content) {
        self.content = content
    }

    var body: some View {
        content(width)
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .preference(key: WidthPreferenceKey.self, value: proxy.size.width)
                }
            )
            .onPreferenceChange(WidthPreferenceKey.self) { newValue in
                width = newValue
            }
    }
}

private struct WidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
