//
//  PlannerView.swift
//  Task Planner
//
//  Created by Руслан Меланин on 09.02.2026.
//

import SwiftUI
import SwiftData
import UIKit

struct PlannerView: View {
    @StateObject var viewModel: PlannerViewModel

    @Query(sort: [SortDescriptor(\TaskEntity.dayDate, order: .forward),
                  SortDescriptor(\TaskEntity.startTime, order: .forward)])
    private var tasks: [TaskEntity]

    // MARK: - Swipe month switch
    @State private var didTriggerSwipe = false
    private let swipeThreshold: CGFloat = 72
    private let monthAnim: Animation = .easeInOut(duration: 0.2)

    // MARK: - Month slide animation direction
    private enum MonthNavDirection {
        case next
        case prev

        var insertionEdge: Edge { self == .next ? .trailing : .leading }
        var removalEdge: Edge { self == .next ? .leading : .trailing }
    }

    @State private var monthDirection: MonthNavDirection = .next

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
        .contentMargins(.bottom, DS.Layout.tabBarHeight + DS.Layout.tabBarBottomPadding, for: .scrollContent)
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
        ZStack {
            // Важно: меняем identity по monthAnchor, чтобы работал transition
            calendarContent
                .id(viewModel.monthAnchor)
                .transition(monthSlideTransition)
        }
        .dsCard {
            DS.GradientToken.pinkPurpleCardBackground
        }
        .contentShape(Rectangle())
        .simultaneousGesture(monthSwipeGesture)
        .animation(monthAnim, value: viewModel.monthAnchor)
    }

    private var calendarContent: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            MonthSwitcherView(
                title: viewModel.monthAnchor.monthTitle(),
                monthAnchor: viewModel.monthAnchor,
                onPrev: handlePrevMonth,
                onNext: handleNextMonth,
                onSelectMonthAnchor: handleSelectMonthAnchor(_:),
                onToday: handleToday,
                todayTitle: "Today"
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
    }

    private var monthSlideTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: monthDirection.insertionEdge).combined(with: .opacity),
            removal: .move(edge: monthDirection.removalEdge).combined(with: .opacity)
        )
    }

    private var monthSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 18, coordinateSpace: .local)
            .onChanged { value in
                guard !didTriggerSwipe else { return }

                let dx = value.translation.width
                let dy = value.translation.height

                // чтобы вертикальный скролл List не воспринимался как свайп месяца
                guard abs(dx) > abs(dy) else { return }

                if dx <= -swipeThreshold {
                    triggerMonthChange(next: true)
                } else if dx >= swipeThreshold {
                    triggerMonthChange(next: false)
                }
            }
            .onEnded { _ in
                didTriggerSwipe = false
            }
    }

    private func triggerMonthChange(next: Bool) {
        didTriggerSwipe = true

        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        monthDirection = next ? .next : .prev
        withAnimation(monthAnim) {
            if next {
                viewModel.goToNextMonth()
            } else {
                viewModel.goToPreviousMonth()
            }
        }
    }

    // MARK: - Month actions (buttons / picker / today)

    private func handlePrevMonth() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        monthDirection = .prev
        withAnimation(monthAnim) {
            viewModel.goToPreviousMonth()
        }
    }

    private func handleNextMonth() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        monthDirection = .next
        withAnimation(monthAnim) {
            viewModel.goToNextMonth()
        }
    }

    private func handleSelectMonthAnchor(_ date: Date) {
        // для выбора из пикера — мягкое появление без явного направления
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        monthDirection = .next
        withAnimation(monthAnim) {
            viewModel.setMonthAnchor(date)
        }
    }

    private func handleToday() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        monthDirection = .next
        withAnimation(monthAnim) {
            viewModel.goToToday()
        }
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
