//
//  PlannerView.swift
//  Task Planner
//
//  Created by Руслан Меланин on 09.02.2026.
//

import SwiftUI
import SwiftData

struct PlannerView: View {
    @StateObject private var viewModel: PlannerViewModel
    @Environment(\.modelContext) private var modelContext

    @Query(
        sort: [
            SortDescriptor(\TaskEntity.dayDate, order: .forward),
            SortDescriptor(\TaskEntity.startTime, order: .forward)
        ]
    )
    private var tasks: [TaskEntity]

    @State private var didTriggerSwipe = false
    @State private var headerCollapseProgress: CGFloat = 0
    private let swipeThreshold: CGFloat = 72
    private let monthAnim = PlannerViewModel.monthTransitionAnimation

    private enum MonthNavDirection {
        case next
        case prev

        var insertionEdge: Edge { self == .next ? .trailing : .leading }
        var removalEdge: Edge { self == .next ? .leading : .trailing }
    }

    @State private var monthDirection: MonthNavDirection = .next

    init(viewModel: PlannerViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    init(
        taskRepository: TaskRepository,
        preferencesRepository: PreferencesRepository,
        calendarSync: CalendarSyncService,
        seriesService: TaskSeriesService,
        onOpenTaskEditor: @escaping (_ taskId: PersistentIdentifier?, _ day: Date) -> Void,
        onOpenNotifications: @escaping () -> Void,
        onOpenRecurringBaseTasks: @escaping () -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: PlannerViewModel(
                taskRepository: taskRepository,
                preferencesRepository: preferencesRepository,
                calendarSync: calendarSync,
                seriesService: seriesService,
                onOpenTaskEditor: onOpenTaskEditor,
                onOpenNotifications: onOpenNotifications,
                onOpenRecurringBaseTasks: onOpenRecurringBaseTasks
            )
        )
    }

    var body: some View {
        let snapshot = viewModel.snapshot
        let monthSnapshot = snapshot.month
        let selectedDaySnapshot = snapshot.selectedDay

        List {
            Section {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    calendarCard(snapshot: monthSnapshot)
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
                    tasksHeader(snapshot: selectedDaySnapshot)
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.sm)
                .padding(.bottom, DS.Spacing.xs)
            }
            .listRowInsets(.init())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            if selectedDaySnapshot.isEmpty {
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
                    ForEach(selectedDaySnapshot.items) { item in
                        switch item {
                        case .task(let row):
                            let occurrence = row.occurrence
                            let isVisuallyDone = viewModel.isVisuallyDone(
                                taskKey: occurrence.taskKey,
                                modelCompleted: row.modelCompleted
                            )

                            TaskCardView(
                                occurrence: occurrence,
                                isVisuallyDone: isVisuallyDone
                            )
                            .padding(.horizontal, DS.Spacing.lg)
                            .padding(.vertical, 6)
                            .listRowInsets(.init())
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .onTapGesture {
                                viewModel.openEditTask(taskKey: occurrence.taskKey)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button {
                                    viewModel.toggleDoneTwoPhase(
                                        taskKey: occurrence.taskKey,
                                        on: viewModel.selectedDay
                                    )
                                } label: {
                                    Label(
                                        row.modelCompleted ? "Undo" : "Done",
                                        systemImage: row.modelCompleted
                                        ? "arrow.uturn.backward.circle"
                                        : "checkmark.circle.fill"
                                    )
                                }
                                .tint(DS.ColorToken.purple)

                                if occurrence.isRepeatingTask {
                                    Menu {
                                        Text("Delete from")
                                            .foregroundStyle(DS.ColorToken.textSecondary)
                                            .disabled(true)

                                        Button(role: .destructive) {
                                            viewModel.deleteOccurrence(
                                                taskKey: occurrence.taskKey,
                                                occurrenceStartDay: occurrence.occurrenceStartDay,
                                                scope: .onlyThisDay
                                            )
                                        } label: {
                                            Text("Only this day")
                                        }

                                        Button(role: .destructive) {
                                            viewModel.deleteOccurrence(
                                                taskKey: occurrence.taskKey,
                                                occurrenceStartDay: occurrence.occurrenceStartDay,
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
                                        viewModel.delete(taskKey: occurrence.taskKey)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }

                        case .imported(let row):
                            ImportedEventCardView(row: row)
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
        .contentMargins(.bottom, DS.Layout.tabBarReservedScrollSpace, for: .scrollContent)
        .background(DS.ColorToken.appBackground.ignoresSafeArea())
        .onScrollViewOffsetChange { offset in
            updateHeaderCollapse(offset, style: .planner)
        }
        .navigationBarHidden(true)
        .safeAreaInset(edge: .top) {
            header
        }
        .onAppear {
            viewModel.onViewAppear(tasks: tasks)
        }
        .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { note in
            guard let context = note.object as? ModelContext, context == modelContext else { return }
            viewModel.handleModelContextDidSave(tasks: tasks)
        }
        .onReceive(NotificationCenter.default.publisher(for: .widgetPlannerDayRequested)) { note in
            guard let day = note.object as? Date else { return }
            viewModel.applyExternalSelectedDay(day)
        }
    }

    private var header: some View {
        ScreenTopSection(
            title: String(localized: "Task Planner"),
            subtitle: String(localized: "Organize your day with ease"),
            collapseProgress: headerCollapseProgress,
            style: .planner
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

    private func calendarCard(snapshot: PlannerMonthSnapshot) -> some View {
        ZStack {
            calendarContent(snapshot: snapshot)
                .id(snapshot.monthAnchor)
                .transition(monthSlideTransition)
        }
        .dsCard {
            DS.GradientToken.pinkPurpleCardBackground
        }
        .contentShape(Rectangle())
        .simultaneousGesture(monthSwipeGesture)
        .animation(monthAnim, value: snapshot.monthAnchor)
    }

    private func calendarContent(snapshot: PlannerMonthSnapshot) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            MonthSwitcherView(
                title: snapshot.monthAnchor.monthTitle(),
                monthAnchor: snapshot.monthAnchor,
                isNavigationLocked: viewModel.isMonthTransitionLocked,
                onPrev: handlePrevMonth,
                onNext: handleNextMonth,
                onSelectMonthAnchor: handleSelectMonthAnchor(_:),
                onToday: handleToday,
                todayTitle: String(localized: "Today")
            )

            WeekdaysRowView(symbols: snapshot.weekdaySymbols)

            CalendarGridView(
                days: snapshot.viewDays(selectedDay: viewModel.selectedDay),
                onSelectDay: { day in
                    viewModel.selectDay(day)
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
                    didTriggerSwipe = true
                    triggerMonthChange(next: true)
                } else if dx >= swipeThreshold {
                    didTriggerSwipe = true
                    triggerMonthChange(next: false)
                }
            }
            .onEnded { _ in
                didTriggerSwipe = false
            }
    }

    private func triggerMonthChange(next: Bool) {
        performMonthNavigation(direction: next ? .next : .prev) {
            next ? viewModel.goToNextMonth() : viewModel.goToPreviousMonth()
        }
    }

    private func handlePrevMonth() {
        performMonthNavigation(direction: .prev, action: viewModel.goToPreviousMonth)
    }

    private func handleNextMonth() {
        performMonthNavigation(direction: .next, action: viewModel.goToNextMonth)
    }

    private func handleSelectMonthAnchor(_ date: Date) {
        performMonthNavigation(direction: .next) {
            viewModel.setMonthAnchor(date)
        }
    }

    private func handleToday() {
        performMonthNavigation(direction: .next, action: viewModel.goToToday)
    }

    private func performMonthNavigation(
        direction: MonthNavDirection,
        action: () -> Bool
    ) {
        guard !viewModel.isMonthTransitionLocked else { return }

        let didChangeMonth = withAnimation(monthAnim) {
            monthDirection = direction
            return action()
        }

        guard didChangeMonth else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func tasksHeader(snapshot: PlannerSelectedDaySnapshot) -> some View {
        HStack {
            Text(
                String.localizedStringWithFormat(
                    String(localized: "Tasks for %@"),
                    snapshot.title
                )
            )
                .font(DS.Typography.sectionTitle)
                .foregroundColor(DS.ColorToken.textPrimary)

            Spacer()

            HStack(spacing: 10) {
                Text(
                    String.localizedStringWithFormat(
                        String(localized: "%lld tasks"),
                        Int64(snapshot.taskCount)
                    )
                )
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(DS.ColorToken.purple)

                Button(action: viewModel.openCreateTask) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 34, height: 34)
                        .dsSurface(
                            Circle(),
                            fill: DS.GradientToken.brand,
                            stroke: DS.Border.inverted
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Create Task")
            }
        }
    }

    private func updateHeaderCollapse(
        _ scrollOffset: CGFloat,
        style: ScreenTopSectionStyle
    ) {
        let nextProgress = style.collapseProgress(for: scrollOffset)
        guard abs(nextProgress - headerCollapseProgress) > 0.001 else { return }
        headerCollapseProgress = nextProgress
    }
}
