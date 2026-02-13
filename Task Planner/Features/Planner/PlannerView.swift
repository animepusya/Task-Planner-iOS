//
//  PlannerView.swift
//  Task Planner
//
//  Created by Руслан Меланин on 09.02.2026.
//

import SwiftUI
import SwiftData

struct PlannerView: View {
    @StateObject var viewModel: PlannerViewModel

    @Query(sort: [SortDescriptor(\TaskEntity.dayDate, order: .forward),
                  SortDescriptor(\TaskEntity.startTime, order: .forward)])
    private var tasks: [TaskEntity]

    var body: some View {
        List {
            // MARK: - Header + Calendar (как "статичный верх")
            Section {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    header
                    calendarCard
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.md)
            }
            .listRowInsets(.init())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            // MARK: - Tasks
            Section {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    tasksHeader
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.sm)
                .padding(.bottom, DS.Spacing.xs)
            }
            .listRowInsets(.init())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            if tasksForSelectedDay.isEmpty {
                Section {
                    EmptyTasksCardView()
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.bottom, DS.Spacing.lg)
                }
                .listRowInsets(.init())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                Section {
                    ForEach(tasksForSelectedDay) { task in
                        let isCompleted = task.isCompleted(on: viewModel.selectedDay)

                        TaskCardView(task: task, isCompleted: isCompleted)
                            .padding(.horizontal, DS.Spacing.lg)
                            .padding(.vertical, 6)
                            .listRowInsets(.init())
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .onTapGesture {
                                viewModel.openEditTask(id: task.persistentModelID)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {

                                Button {
                                    viewModel.toggleDone(taskId: task.persistentModelID, on: viewModel.selectedDay)
                                } label: {
                                    Label(
                                        isCompleted ? "Undo" : "Done",
                                        systemImage: isCompleted
                                        ? "arrow.uturn.backward.circle"
                                        : "checkmark.circle.fill"
                                    )
                                }
                                .tint(DS.ColorToken.purple)

                                Button(role: .destructive) {
                                    viewModel.delete(taskId: task.persistentModelID)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
                .listRowInsets(.init())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(DS.ColorToken.appBackground.ignoresSafeArea())
        .navigationBarHidden(true)
        .onAppear { viewModel.loadPreferences() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Task Planner")
                    .font(DS.Typography.title)
                    .foregroundColor(DS.ColorToken.textPrimary)

                Text("Organize your day with ease")
                    .font(DS.Typography.subtitle)
                    .foregroundColor(DS.ColorToken.textSecondary)
            }

            Spacer(minLength: 12)
        }
    }

    // MARK: - Calendar

    private var calendarCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            MonthSwitcherView(
                title: viewModel.monthAnchor.monthTitle(),
                monthAnchor: viewModel.monthAnchor,
                onPrev: viewModel.goToPreviousMonth,
                onNext: viewModel.goToNextMonth,
                onSelectMonthAnchor: viewModel.setMonthAnchor(_:),
                onToday: viewModel.goToToday // ✅
            )

            WeekdaysRowView(
                symbols: CalendarGridBuilder.weekdaySymbols(
                    weekStartsOnMonday: viewModel.weekStartsOnMonday
                )
            )

            CalendarGridView(
                monthAnchor: viewModel.monthAnchor,
                weekStartsOnMonday: viewModel.weekStartsOnMonday,
                selectedDay: viewModel.selectedDay,
                tasks: tasks,
                indicatorColors: { date in
                    viewModel.indicatorColors(for: date, tasks: tasks)
                },
                onSelectDay: { day in
                    viewModel.selectedDay = Calendar.current.startOfDay(for: day)
                }
            )
        }
        .dsCard()
    }

    // MARK: - Tasks Header

    private var tasksHeader: some View {
        HStack {
            Text("Tasks for \(viewModel.selectedDay.dayTitle())")
                .font(DS.Typography.sectionTitle)
                .foregroundColor(DS.ColorToken.textPrimary)

            Spacer()

            HStack(spacing: 10) {
                Text("\(tasksForSelectedDay.count) tasks")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(DS.ColorToken.purple)

                Button(action: viewModel.openCreateTask) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 34, height: 34)
                        .background(DS.GradientToken.brand)
                        .clipShape(Circle())
                        .shadow(color: DS.Shadow.soft, radius: 10, x: 0, y: 6)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Create Task")
            }
        }
    }

    private var tasksForSelectedDay: [TaskEntity] {
        viewModel.tasksForDay(viewModel.selectedDay, from: tasks)
    }
}
