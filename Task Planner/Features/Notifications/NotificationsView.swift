//
//  NotificationsView.swift
//  Task Planner
//
//  Created by Руслан Меланин on 03.03.2026.
//

import SwiftUI
import SwiftData

struct NotificationsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: NotificationsViewModel

    @Query(sort: [SortDescriptor(\TaskEntity.dayDate, order: .forward)])
    private var tasks: [TaskEntity]

    init(viewModel: NotificationsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    init(
        taskRepository: TaskRepository,
        preferencesRepository: PreferencesRepository,
        notificationService: NotificationService,
        notificationSync: NotificationSyncService,
        onOpenTaskEditor: @escaping (_ taskId: PersistentIdentifier?, _ day: Date) -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: NotificationsViewModel(
                taskRepository: taskRepository,
                preferencesRepository: preferencesRepository,
                notificationService: notificationService,
                notificationSync: notificationSync,
                onOpenTaskEditor: onOpenTaskEditor
            )
        )
    }

    var body: some View {
        DSAdaptiveLayoutScope { metrics in
            List {
                Section {
                    NotificationsSetupStrip(viewModel: viewModel)
                        .padding(.horizontal, metrics.screenPadding(DS.Spacing.lg))
                        .padding(.top, metrics.spacing(DS.Spacing.lg))
                        .padding(.bottom, metrics.spacing(DS.Spacing.sm))
                        .dsContentFrame(.modal)
                }
                .listRowInsets(.init())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                NotificationsScheduledSection(viewModel: viewModel, tasks: tasks)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(DS.ColorToken.appBackground.ignoresSafeArea())
            .navigationBarHidden(true)
            .safeAreaInset(edge: .top) {
                NotificationsTopBar(
                    title: String(localized: "Notifications"),
                    onBack: { dismiss() }
                )
                .padding(.top, metrics.spacing(6))
                .background(DS.ColorToken.appBackground.opacity(0.92))
            }
            .onAppear { viewModel.onAppear() }
        }
    }
}
