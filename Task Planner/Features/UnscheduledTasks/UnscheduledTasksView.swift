//
//  UnscheduledTasksView.swift
//  Task Planner
//

import SwiftData
import SwiftUI

struct UnscheduledTasksView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dsAdaptiveMetrics) private var dsMetrics

    @StateObject private var viewModel: UnscheduledTasksViewModel

    init(viewModel: UnscheduledTasksViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    init(
        taskRepository: TaskRepository,
        onOpenTaskEditor: @escaping (_ taskId: PersistentIdentifier) -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: UnscheduledTasksViewModel(
                taskRepository: taskRepository,
                onOpenTaskEditor: onOpenTaskEditor
            )
        )
    }

    var body: some View {
        DSAdaptiveLayoutScope { metrics in
            VStack(spacing: 0) {
                NotificationsTopBar(
                    title: String(localized: "Unscheduled Tasks"),
                    onBack: { dismiss() }
                )

                List {
                    if viewModel.tasks.isEmpty {
                        emptyState
                            .dsContentFrame(.modal)
                            .listRowInsets(.init(
                                top: metrics.spacing(DS.Spacing.md),
                                leading: metrics.screenPadding(DS.Spacing.lg),
                                bottom: metrics.spacing(28),
                                trailing: metrics.screenPadding(DS.Spacing.lg)
                            ))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    } else {
                        ForEach(viewModel.tasks) { task in
                            unscheduledTaskRow(task, metrics: metrics)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .background(DS.ColorToken.appBackground.ignoresSafeArea())
            .onAppear {
                viewModel.onViewAppear()
            }
            .onDisappear {
                viewModel.onViewDisappear()
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: dsMetrics.spacing(DS.Spacing.sm)) {
            Text("No unscheduled tasks yet")
                .font(
                    dsMetrics.font(
                        18,
                        weight: .semibold,
                        category: .title
                    )
                )
                .foregroundStyle(DS.ColorToken.textPrimary)

            Text("Tasks without a date will appear here.")
                .font(
                    dsMetrics.font(
                        15,
                        weight: .regular,
                        category: .body
                    )
                )
                .foregroundStyle(DS.ColorToken.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsCard()
    }

    private func unscheduledTaskRow(
        _ task: UnscheduledTaskRowModel,
        metrics: DSAdaptiveMetrics
    ) -> some View {
        UnscheduledTaskRowView(task: task)
            .contentShape(Rectangle())
            .onTapGesture {
                viewModel.open(task: task)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    viewModel.delete(task: task)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            .padding(.vertical, metrics.spacing(6))
            .dsContentFrame(.modal)
            .listRowInsets(.init(
                top: 0,
                leading: metrics.screenPadding(DS.Spacing.lg),
                bottom: 0,
                trailing: metrics.screenPadding(DS.Spacing.lg)
            ))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}
