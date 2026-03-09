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
    @StateObject var viewModel: RecurringTasksViewModel

    @Query(sort: [SortDescriptor(\TaskEntity.title, order: .forward),
                  SortDescriptor(\TaskEntity.dayDate, order: .forward)])
    private var tasks: [TaskEntity]

    var body: some View {
        let sections = viewModel.sections(from: tasks)

        VStack(spacing: 0) {
            NotificationsTopBar(
                title: "Recurring Tasks",
                onBack: { dismiss() }
            )

            if sections.active.isEmpty && sections.past.isEmpty {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                        emptyState
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.top, DS.Spacing.md)
                    .padding(.bottom, 28)
                }
            } else {
                List {
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
                                            Text("Deletes the whole recurring series.")
                                                .foregroundStyle(DS.ColorToken.textSecondary)
                                                .disabled(true)

                                            Button(role: .destructive) {
                                                viewModel.deleteSeries(taskId: task.persistentModelID)
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
                            sectionHeader(title: "Active", count: sections.active.count)
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
                                            Text("Deletes the whole recurring series.")
                                                .foregroundStyle(DS.ColorToken.textSecondary)
                                                .disabled(true)

                                            Button(role: .destructive) {
                                                viewModel.deleteSeries(taskId: task.persistentModelID)
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
                            sectionHeader(title: "Past", count: sections.past.count)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(DS.ColorToken.appBackground.ignoresSafeArea())
        .onAppear {
            viewModel.loadPreferences()
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
        .dsCard()
    }
}
