//
//  BaseRecurringTasksView.swift
//  Task Planner
//
//  Created by Руслан Меланин on 09.03.2026.
//

import SwiftUI
import SwiftData

struct BaseRecurringTasksView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject var viewModel: BaseRecurringTasksViewModel

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

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    if sections.active.isEmpty && sections.past.isEmpty {
                        emptyState
                    } else {
                        if !sections.active.isEmpty {
                            sectionView(title: "Active", tasks: sections.active)
                        }

                        if !sections.past.isEmpty {
                            sectionView(title: "Past", tasks: sections.past)
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.md)
                .padding(.bottom, 28)
            }
        }
        .background(DS.ColorToken.appBackground.ignoresSafeArea())
        .onAppear {
            viewModel.loadPreferences()
        }
    }

    private func sectionView(title: String, tasks: [TaskEntity]) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack {
                Text(title)
                    .font(DS.Typography.sectionTitle)
                    .foregroundStyle(DS.ColorToken.textPrimary)

                Spacer()

                Text("\(tasks.count)")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(DS.ColorToken.purple)
            }

            VStack(spacing: 12) {
                ForEach(tasks) { task in
                    BaseRecurringTaskCardView(task: task)
                        .onTapGesture {
                            viewModel.open(task: task)
                        }
                }
            }
        }
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
