//
//  ScheduledSwipeActions.swift
//  Task Planner
//
//  Created by Руслан Меланин on 05.03.2026.
//

import SwiftUI
import SwiftData

struct ScheduledSwipeActions: View {
    let reminder: ScheduledReminderItem
    let taskId: PersistentIdentifier?

    let onDisable: (PersistentIdentifier) -> Void
    let onEnable: (PersistentIdentifier) -> Void

    var body: some View {
        if let taskId {
            if reminder.isSuppressed {
                Button { onEnable(taskId) } label: {
                    Image(systemName: "arrow.uturn.backward.circle")
                }
                .accessibilityLabel("Enable")
                .tint(DS.ColorToken.lavender)
            } else {
                Button { onDisable(taskId) } label: {
                    Image(systemName: "bell.slash")
                }
                .accessibilityLabel("Disable")
                .tint(DS.ColorToken.purple)
            }
        } else {
            EmptyView()
        }
    }
}
