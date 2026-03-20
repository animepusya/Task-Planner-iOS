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

    @Query(
        sort: [
            SortDescriptor(\TaskEntity.dayDate, order: .forward),
            SortDescriptor(\TaskEntity.startTime, order: .forward)
        ]
    )
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
        let snapshot = viewModel.snapshot

        List {
            Section {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    calendarCard(snapshot: snapshot)
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
                    tasksHeader(snapshot: snapshot)
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.sm)
                .padding(.bottom, DS.Spacing.xs)
            }
            .listRowInsets(.init())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            if snapshot.selectedDaySection.isEmpty {
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
                    ForEach(snapshot.selectedDaySection.items) { item in
                        switch item {
                        case .task(let row):
                            let occ = row.occurrence
                            let isVisuallyDone = viewModel.isVisuallyDone(
                                taskId: occ.task.persistentModelID,
                                modelCompleted: row.modelCompleted
                            )

                            TaskCardView(
                                occurrence: occ,
                                isVisuallyDone: isVisuallyDone
                            )
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
                                        row.modelCompleted ? "Undo" : "Done",
                                        systemImage: row.modelCompleted
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
        .background(DS.ColorToken.appBackground.ignoresSafeArea())
        .contentMargins(.bottom, DS.Layout.tabBarReservedScrollSpace, for: .scrollContent)
        .navigationBarHidden(true)
        .safeAreaInset(edge: .top, spacing: 0) {
            header
        }
        .onAppear {
            viewModel.updateSourceTasks(tasks)
            viewModel.loadPreferences()
            viewModel.refreshExternalEvents()
        }
        .onChange(of: tasksInputFingerprint) { _ in
            viewModel.updateSourceTasks(tasks)
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

    private func calendarCard(snapshot: PlannerScreenSnapshot) -> some View {
        ZStack {
            calendarContent(snapshot: snapshot)
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

    private func calendarContent(snapshot: PlannerScreenSnapshot) -> some View {
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

            WeekdaysRowView(symbols: snapshot.weekdaySymbols)

            CalendarGridView(
                days: snapshot.monthDays,
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

    private func tasksHeader(snapshot: PlannerScreenSnapshot) -> some View {
        HStack {
            Text("Tasks for \(snapshot.selectedDaySection.title)")
                .font(DS.Typography.sectionTitle)
                .foregroundColor(DS.ColorToken.textPrimary)

            Spacer()

            HStack(spacing: 10) {
                Text("\(snapshot.selectedDaySection.taskCount) tasks")
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

    private var tasksInputFingerprint: Int {
        var hasher = Hasher()
        hasher.combine(tasks.count)

        for task in tasks {
            hasher.combine(String(describing: task.persistentModelID))
            hasher.combine(task.title)
            hasher.combine(task.notes ?? "")
            hasher.combine(task.dayDate.timeIntervalSince1970.bitPattern)
            hasher.combine(task.startTime.timeIntervalSince1970.bitPattern)
            hasher.combine(task.endTime.timeIntervalSince1970.bitPattern)
            hasher.combine(task.isAllDay)
            hasher.combine(task.repeatRuleRaw)
            hasher.combine(task.repeatIntervalDays ?? 0)
            hasher.combine(task.statusRaw)
            hasher.combine(task.colorRaw)
            hasher.combine(task.categoryTitle ?? "")
            hasher.combine(task.photoThumbData?.count ?? 0)
            hasher.combine(task.completedDayKeysRaw)
            hasher.combine(task.appleEventIdentifier ?? "")
            hasher.combine(task.reminderEnabled)
            hasher.combine(task.reminderOffsetMinutes)
            hasher.combine(task.reminderAllDayTimeMinutes ?? -1)
            hasher.combine(task.suppressedReminderKeysRaw ?? "")
            hasher.combine(task.seriesSegmentsRaw ?? "")
            hasher.combine(task.seriesOverridesRaw ?? "")
            hasher.combine(task.seriesEndDay?.timeIntervalSince1970.bitPattern ?? 0)
        }

        return hasher.finalize()
    }
}
