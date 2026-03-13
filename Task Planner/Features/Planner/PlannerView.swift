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

    @State private var didTriggerSwipe = false
    private let swipeThreshold: CGFloat = 72
    private let monthAnim: Animation = .easeInOut(duration: 0.2)

    private enum MonthNavDirection {
        case next
        case prev

        var insertionEdge: Edge { self == .next ? .trailing : .leading }
        var removalEdge: Edge { self == .next ? .leading : .trailing }
    }

    @State private var monthDirection: MonthNavDirection = .next

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    calendarCard
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.md)
            }
            .listRowInsets(.init())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

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

            let dayItems = viewModel.itemsForSelectedDay(from: tasks)

            if dayItems.isEmpty {
                Section {
                    EmptyTasksCardView(onTap: viewModel.openCreateTask)
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.bottom, DS.Spacing.lg)
                }
                .listRowInsets(.init())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                Section {
                    ForEach(dayItems) { item in
                        switch item {
                        case .task(let occ):
                            let modelCompleted = occ.task.isCompleted(on: viewModel.selectedDay)
                            let isVisuallyDone = viewModel.isVisuallyDone(
                                taskId: occ.task.persistentModelID,
                                modelCompleted: modelCompleted
                            )

                            TaskCardView(occurrence: occ, isVisuallyDone: isVisuallyDone)
                                .padding(.horizontal, DS.Spacing.lg)
                                .padding(.vertical, 6)
                                .listRowInsets(.init())
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .onTapGesture {
                                    viewModel.openEditTask(id: occ.task.persistentModelID)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button {
                                        viewModel.toggleDoneTwoPhase(
                                            taskId: occ.task.persistentModelID,
                                            on: viewModel.selectedDay
                                        )
                                    } label: {
                                        Label(
                                            modelCompleted ? "Undo" : "Done",
                                            systemImage: modelCompleted
                                            ? "arrow.uturn.backward.circle"
                                            : "checkmark.circle.fill"
                                        )
                                    }
                                    .tint(DS.ColorToken.purple)

                                    if occ.task.repeatRule != .none {
                                        Menu {
                                            Text("How to delete?")
                                                .foregroundStyle(DS.ColorToken.textSecondary)
                                                .disabled(true)

                                            Button(role: .destructive) {
                                                viewModel.deleteOccurrence(
                                                    taskId: occ.task.persistentModelID,
                                                    occurrenceStartDay: occ.occurrenceStartDay,
                                                    scope: .onlyThisDay
                                                )
                                            } label: {
                                                Text("Only this day")
                                            }

                                            Button(role: .destructive) {
                                                viewModel.deleteOccurrence(
                                                    taskId: occ.task.persistentModelID,
                                                    occurrenceStartDay: occ.occurrenceStartDay,
                                                    scope: .allFutureDays
                                                )
                                            } label: {
                                                Text("All future days")
                                            }
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                        .tint(.red)
                                    } else {
                                        Button(role: .destructive) {
                                            viewModel.delete(taskId: occ.task.persistentModelID)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }

                        case .imported(let ev):
                            ImportedEventCardView(event: ev)
                                .padding(.horizontal, DS.Spacing.lg)
                                .padding(.vertical, 6)
                                .listRowInsets(.init())
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
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
        .contentMargins(.bottom, DS.Layout.tabBarReservedScrollSpace, for: .scrollContent)
        .navigationBarHidden(true)
        .safeAreaInset(edge: .top, spacing: 0) {
            header
        }
        .onAppear {
            viewModel.loadPreferences()
            viewModel.refreshExternalEvents()
        }
        .onReceive(NotificationCenter.default.publisher(for: .widgetPlannerDayRequested)) { note in
            guard let day = note.object as? Date else { return }
            viewModel.applyExternalSelectedDay(day)
        }
    }

    private var header: some View {
        ScreenTopSection(
            title: "Task Planner",
            subtitle: "Organize your day with ease"
        ) {
            HStack(spacing: 10) {
                IconCircleButton(systemName: "square.stack.3d.up") {
                    viewModel.openRecurringBaseTasks()
                }
                .accessibilityLabel("Recurring Tasks")

                IconCircleButton(systemName: "bell") {
                    viewModel.openNotifications()
                }
                .accessibilityLabel("Notifications")
            }
        }
    }

    private var calendarCard: some View {
        ZStack {
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

    private func handlePrevMonth() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        monthDirection = .prev
        withAnimation(monthAnim) { viewModel.goToPreviousMonth() }
    }

    private func handleNextMonth() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        monthDirection = .next
        withAnimation(monthAnim) { viewModel.goToNextMonth() }
    }

    private func handleSelectMonthAnchor(_ date: Date) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        monthDirection = .next
        withAnimation(monthAnim) { viewModel.setMonthAnchor(date) }
    }

    private func handleToday() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        monthDirection = .next
        withAnimation(monthAnim) { viewModel.goToToday() }
    }

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

    private var tasksForSelectedDay: [DayOccurrence] {
        viewModel.tasksForDay(viewModel.selectedDay, from: tasks)
    }
}
