//
//  RecurringTasksView.swift
//  Task Planner
//
//  Created by Руслан Меланин on 09.03.2026.
//

import SwiftUI
import SwiftData

struct RecurringTasksView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: RecurringTasksViewModel

    init(viewModel: RecurringTasksViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    init(
        taskRepository: TaskRepository,
        preferencesRepository: PreferencesRepository,
        onOpenBaseRecurringEditor: @escaping (_ taskId: PersistentIdentifier, _ day: Date) -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: RecurringTasksViewModel(
                taskRepository: taskRepository,
                preferencesRepository: preferencesRepository,
                onOpenBaseRecurringEditor: onOpenBaseRecurringEditor
            )
        )
    }

    var body: some View {
        let sections = viewModel.sections

        VStack(spacing: 0) {
            NotificationsTopBar(
                title: String(localized: "Recurring Tasks"),
                onBack: { dismiss() }
            )

            List {
                if viewModel.isLoading && sections.active.isEmpty && sections.past.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, DS.Spacing.xl)
                        .listRowInsets(.init(top: DS.Spacing.md, leading: DS.Spacing.lg, bottom: 28, trailing: DS.Spacing.lg))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                } else if sections.active.isEmpty && sections.past.isEmpty {
                    emptyState
                        .listRowInsets(.init(top: DS.Spacing.md, leading: DS.Spacing.lg, bottom: 28, trailing: DS.Spacing.lg))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                } else {
                    if !sections.active.isEmpty {
                        Section {
                            ForEach(sections.active) { task in
                                RecurringTaskCardView(task: task)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        viewModel.open(task: task)
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Menu {
                                            Text("Deletes the entire series.")
                                                .foregroundStyle(DS.ColorToken.textSecondary)
                                                .disabled(true)

                                            Button(role: .destructive) {
                                                viewModel.deleteSeries(taskId: task.id)
                                            } label: {
                                                Text("Delete series")
                                            }
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                        .tint(.red)
                                    }
                                    .padding(.vertical, 6)
                                    .listRowInsets(.init(top: 0, leading: DS.Spacing.lg, bottom: 0, trailing: DS.Spacing.lg))
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                            }
                        } header: {
                            sectionHeader(title: String(localized: "Active"), count: sections.active.count)
                        }
                    }

                    if !sections.past.isEmpty {
                        Section {
                            ForEach(sections.past) { task in
                                RecurringTaskCardView(task: task)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        viewModel.open(task: task)
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Menu {
                                            Text("Deletes the entire series.")
                                                .foregroundStyle(DS.ColorToken.textSecondary)
                                                .disabled(true)

                                            Button(role: .destructive) {
                                                viewModel.deleteSeries(taskId: task.id)
                                            } label: {
                                                Text("Delete series")
                                            }
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                        .tint(.red)
                                    }
                                    .padding(.vertical, 6)
                                    .listRowInsets(.init(top: 0, leading: DS.Spacing.lg, bottom: 0, trailing: DS.Spacing.lg))
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                            }
                        } header: {
                            sectionHeader(title: String(localized: "Past"), count: sections.past.count)
                        }
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

    private func sectionHeader(title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(DS.Typography.sectionTitle)
                .foregroundStyle(DS.ColorToken.textPrimary)

            Spacer()

            Text("\(count)")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(DS.ColorToken.purple)
        }
        .textCase(nil)
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.top, DS.Spacing.sm)
        .padding(.bottom, DS.Spacing.xs)
        .listRowInsets(.init())
        .listRowBackground(Color.clear)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("No recurring tasks yet")
                .font(DS.Typography.sectionTitle)
                .foregroundStyle(DS.ColorToken.textPrimary)

            Text("Create a repeating task in Planner and it will appear here.")
                .font(DS.Typography.body)
                .foregroundStyle(DS.ColorToken.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsCard()
    }
}
