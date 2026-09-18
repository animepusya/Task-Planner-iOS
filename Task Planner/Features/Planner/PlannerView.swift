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
    @Environment(\.dsAdaptiveMetrics) private var dsMetrics
    @Environment(\.scenePhase) private var scenePhase

    @State private var didTriggerSwipe = false
    @State private var isViewVisible = false
    @State private var headerCollapseProgress: CGFloat = 0
    @State private var headerReservedHeight: CGFloat = 0
    @State private var currentDay = Calendar.current.startOfDay(for: .now)
    private let swipeThreshold: CGFloat = 72
    private let monthAnim = PlannerViewModel.monthTransitionAnimation
    private let plannerHeaderFallbackHeight: CGFloat = 84
    private let isActive: Bool

    private enum MonthNavDirection {
        case next
        case prev

        var insertionEdge: Edge { self == .next ? .trailing : .leading }
        var removalEdge: Edge { self == .next ? .leading : .trailing }
    }

    @State private var monthDirection: MonthNavDirection = .next

    init(
        viewModel: PlannerViewModel,
        isActive: Bool = true
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.isActive = isActive
    }

    init(
        taskRepository: TaskRepository,
        preferencesRepository: PreferencesRepository,
        calendarSync: CalendarSyncService,
        seriesService: TaskSeriesService,
        unscheduledTasksUsageStore: UnscheduledTasksUsageStore,
        isActive: Bool = true,
        onOpenTaskEditor: @escaping (_ taskId: PersistentIdentifier?, _ day: Date) -> Void,
        onOpenNotifications: @escaping () -> Void,
        onOpenUnscheduledTasks: @escaping () -> Void,
        onOpenRecurringBaseTasks: @escaping () -> Void,
        onSuccessfulTaskCompletion: @escaping () -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: PlannerViewModel(
                taskRepository: taskRepository,
                preferencesRepository: preferencesRepository,
                calendarSync: calendarSync,
                seriesService: seriesService,
                unscheduledTasksUsageStore: unscheduledTasksUsageStore,
                onOpenTaskEditor: onOpenTaskEditor,
                onOpenNotifications: onOpenNotifications,
                onOpenUnscheduledTasks: onOpenUnscheduledTasks,
                onOpenRecurringBaseTasks: onOpenRecurringBaseTasks,
                onSuccessfulTaskCompletion: onSuccessfulTaskCompletion
            )
        )
        self.isActive = isActive
    }

    var body: some View {
        let snapshot = viewModel.snapshot
        let monthSnapshot = snapshot.month
        let selectedDaySnapshot = snapshot.selectedDay

        ZStack(alignment: .top) {
            List {
                topContentSpacer

                calendarSection(snapshot: monthSnapshot)
                tasksHeaderSection(snapshot: selectedDaySnapshot)

                if selectedDaySnapshot.isEmpty {
                    emptyTasksSection
                } else {
                    tasksSection(snapshot: selectedDaySnapshot)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .contentMargins(.bottom, dsMetrics.tabBarReservedScrollSpace, for: .scrollContent)
            .background(DS.ColorToken.appBackground.ignoresSafeArea())
            .navigationBarHidden(true)

            headerOverlay
        }
        .background(DS.ColorToken.appBackground.ignoresSafeArea())
        .onAppear {
            refreshCurrentDay()
            handleVisibilityChange(isActive)
        }
        .onChange(of: isActive) { _, newValue in
            handleVisibilityChange(newValue)
        }
        .onDisappear {
            handleVisibilityChange(false)
        }
        .onChange(of: scenePhase) { _, newValue in
            guard newValue == .active else { return }
            refreshCurrentDay()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            refreshCurrentDay()
        }
        .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { note in
            guard let context = note.object as? ModelContext, context == modelContext else { return }
            viewModel.handleModelContextDidSave()
        }
        .onReceive(NotificationCenter.default.publisher(for: .widgetPlannerDayRequested)) { note in
            guard let day = note.object as? Date else { return }
            viewModel.applyExternalSelectedDay(day)
        }
    }

    private var resolvedHeaderReservedHeight: CGFloat {
        headerReservedHeight > 0
        ? headerReservedHeight
        : dsMetrics.controlSize(plannerHeaderFallbackHeight)
    }

    private var topContentSpacer: some View {
        Color.clear
            .frame(height: resolvedHeaderReservedHeight)
            .frame(maxWidth: .infinity)
            .background {
                // Keep the observer attached even while the tab is inactive so the header
                // stays synchronized with the list's real geometry across tab switches and
                // window/layout changes.
                ScrollViewOffsetReader { offset in
                    updateHeaderCollapse(offset, style: .planner)
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .listRowInsets(.init())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .environment(\.defaultMinListRowHeight, 0)
    }

    private var headerOverlay: some View {
        ZStack(alignment: .top) {
            plannerHeader(collapseProgress: headerCollapseProgress)

            plannerHeader(collapseProgress: 0)
                .hidden()
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .background {
                    GeometryReader { proxy in
                        let nextHeight = ceil(proxy.size.height)

                        Color.clear
                            .task(id: nextHeight) {
                                updateHeaderReservedHeight(nextHeight)
                            }
                    }
                }
        }
    }

    private func updateHeaderReservedHeight(_ height: CGFloat) {
        guard height > 0 else { return }
        guard abs(height - headerReservedHeight) > 0.5 else { return }
        headerReservedHeight = height
    }

    private func handleVisibilityChange(_ shouldBeVisible: Bool) {
        guard shouldBeVisible != isViewVisible else { return }
        isViewVisible = shouldBeVisible

        if shouldBeVisible {
            viewModel.onViewAppear()
        } else {
            viewModel.onViewDisappear()
        }
    }

    private func refreshCurrentDay() {
        let nextCurrentDay = Calendar.current.startOfDay(for: .now)
        guard nextCurrentDay != currentDay else { return }
        currentDay = nextCurrentDay
    }

    private func plannerHeader(collapseProgress: CGFloat) -> some View {
        ScreenTopSection(
            title: String(localized: "Task Planner"),
            subtitle: String(localized: "Organize your day with ease"),
            collapseProgress: collapseProgress,
            style: .planner
        ) {
            HStack(spacing: dsMetrics.spacing(10)) {
                unscheduledTasksHeaderButton

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

    private var unscheduledTasksHeaderButton: some View {
        IconCircleButton(systemName: "tray.full") {
            viewModel.openUnscheduledTasks()
        }
        .accessibilityLabel("Unscheduled Tasks")
        .accessibilityValue(
            viewModel.unscheduledTaskCount > 0
            ? "\(viewModel.unscheduledTaskCount)"
            : ""
        )
        .overlay(alignment: .topTrailing) {
            if viewModel.unscheduledTaskCount > 0 {
                unscheduledTasksBadge(count: viewModel.unscheduledTaskCount)
                    .transition(.scale(scale: 0.72).combined(with: .opacity))
            }
        }
        .opacity(viewModel.isUnscheduledTasksButtonVisible ? 1 : 0)
        .scaleEffect(viewModel.isUnscheduledTasksButtonVisible ? 1 : 0.72)
        .allowsHitTesting(viewModel.isUnscheduledTasksButtonVisible)
        .accessibilityHidden(!viewModel.isUnscheduledTasksButtonVisible)
        .animation(
            .spring(response: 0.42, dampingFraction: 0.76),
            value: viewModel.isUnscheduledTasksButtonVisible
        )
        .animation(
            .easeInOut(duration: 0.2),
            value: viewModel.unscheduledTaskCount
        )
    }

    private func unscheduledTasksBadge(count: Int) -> some View {
        let isOverflow = count > 9
        let badgeText = isOverflow ? "∞" : "\(count)"
        let badgeSide = dsMetrics.controlSize(18)

        return Text(badgeText)
            .font(
                .system(
                    size: dsMetrics.fontSize(10, category: .micro),
                    weight: .bold,
                    design: .rounded
                )
            )
            .monospacedDigit()
            .foregroundStyle(.white)
            .minimumScaleFactor(0.8)
            .lineLimit(1)
            .frame(width: badgeSide, height: badgeSide)
            .background(Circle().fill(DS.ColorToken.purple))
            .overlay {
                Circle()
                    .stroke(DS.Surface.chrome, lineWidth: dsMetrics.strokeWidth(1.5))
            }
            .shadow(
                color: DS.ColorToken.purple.opacity(0.28),
                radius: dsMetrics.spacing(3),
                x: 0,
                y: dsMetrics.spacing(1)
            )
            .offset(
                x: dsMetrics.spacing(3),
                y: -dsMetrics.spacing(3)
            )
            .contentTransition(.numericText(value: Double(count)))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private func calendarSection(snapshot: PlannerMonthSnapshot) -> some View {
        VStack(alignment: .leading, spacing: dsMetrics.spacing(DS.Spacing.lg)) {
            calendarCard(snapshot: snapshot)
        }
        .padding(.horizontal, dsMetrics.screenPadding(DS.Spacing.lg))
        .padding(.top, dsMetrics.spacing(DS.Spacing.sm))
        .padding(.bottom, dsMetrics.spacing(DS.Spacing.md))
        .dsContentFrame(.wide)
        .listRowInsets(.init())
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private func tasksHeaderSection(snapshot: PlannerSelectedDaySnapshot) -> some View {
        VStack(alignment: .leading, spacing: dsMetrics.spacing(DS.Spacing.md)) {
            tasksHeader(snapshot: snapshot)
        }
        .padding(.horizontal, dsMetrics.screenPadding(DS.Spacing.lg))
        .padding(.top, dsMetrics.spacing(DS.Spacing.sm))
        .padding(.bottom, dsMetrics.spacing(DS.Spacing.xs))
        .dsContentFrame(.wide)
        .listRowInsets(.init())
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private var emptyTasksSection: some View {
        EmptyTasksCardView(onTap: viewModel.openCreateTask)
            .padding(.horizontal, dsMetrics.screenPadding(DS.Spacing.lg))
            .padding(.bottom, dsMetrics.spacing(DS.Spacing.lg))
            .dsContentFrame(.wide)
            .listRowInsets(.init())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }

    private func tasksSection(snapshot: PlannerSelectedDaySnapshot) -> some View {
        Section {
            ForEach(snapshot.items) { item in
                taskListRow(item)
            }
        }
        .listRowInsets(.init())
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
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
                days: snapshot.viewDays(
                    selectedDay: viewModel.selectedDay,
                    currentDay: currentDay
                ),
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
                .font(
                    dsMetrics.font(
                        18,
                        weight: .semibold,
                        category: .title
                    )
                )
                .foregroundColor(DS.ColorToken.textPrimary)

            Spacer()

            HStack(spacing: dsMetrics.spacing(10)) {
                Text(
                    String.localizedStringWithFormat(
                        String(localized: "%lld tasks"),
                        Int64(snapshot.taskCount)
                    )
                )
                    .font(
                        dsMetrics.font(
                            14,
                            weight: .semibold,
                            category: .micro
                        )
                    )
                    .foregroundColor(DS.ColorToken.purple)

                Button(action: viewModel.openCreateTask) {
                    Image(systemName: "plus")
                        .font(
                            dsMetrics.font(
                                14,
                                weight: .semibold,
                                category: .micro
                            )
                        )
                        .foregroundColor(.white)
                        .frame(
                            width: dsMetrics.controlSize(34),
                            height: dsMetrics.controlSize(34)
                        )
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

    @ViewBuilder
    private func taskListRow(_ item: PlannerSelectedDayItemViewData) -> some View {
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
            .padding(.horizontal, dsMetrics.screenPadding(DS.Spacing.lg))
            .padding(.vertical, dsMetrics.spacing(6))
            .dsContentFrame(.wide)
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
                    .labelStyle(.iconOnly)
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
                            .labelStyle(.iconOnly)
                    }
                    .tint(.red)
                } else {
                    Button(role: .destructive) {
                        viewModel.delete(taskKey: occurrence.taskKey)
                    } label: {
                        Label("Delete", systemImage: "trash")
                            .labelStyle(.iconOnly)
                    }
                }
            }

        case .imported(let row):
            ImportedEventCardView(row: row)
                .padding(.horizontal, dsMetrics.screenPadding(DS.Spacing.lg))
                .padding(.vertical, dsMetrics.spacing(6))
                .dsContentFrame(.wide)
                .listRowInsets(.init())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
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
