//
//  UnscheduledTasksViewModel.swift
//  Task Planner
//

import Combine
import Foundation
import SwiftData

@MainActor
final class UnscheduledTasksViewModel: ObservableObject {
    private let taskRepository: TaskRepository
    private let onOpenTaskEditor: (_ taskId: PersistentIdentifier) -> Void
    private var isViewActive = false
    private var cancellables: Set<AnyCancellable> = []

    @Published private(set) var tasks: [UnscheduledTaskRowModel] = []

    init(
        taskRepository: TaskRepository,
        onOpenTaskEditor: @escaping (_ taskId: PersistentIdentifier) -> Void
    ) {
        self.taskRepository = taskRepository
        self.onOpenTaskEditor = onOpenTaskEditor
        bindTaskRepositoryChanges()
    }

    func onViewAppear() {
        isViewActive = true
        reload()
    }

    func onViewDisappear() {
        isViewActive = false
    }

    func open(task: UnscheduledTaskRowModel) {
        onOpenTaskEditor(task.id)
    }

    func delete(task: UnscheduledTaskRowModel) {
        do {
            guard let entity = try taskRepository.fetch(by: task.id),
                  entity.isScheduled == false else {
                reload()
                return
            }

            try taskRepository.delete(entity)
        } catch {
            assertionFailure("Unscheduled task deletion failed: \(error)")
        }
    }

    private func bindTaskRepositoryChanges() {
        taskRepository.changePublisher
            .sink { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in
                    guard self.isViewActive else {
                        return
                    }
                    self.reload()
                }
            }
            .store(in: &cancellables)
    }

    private func reload() {
        do {
            tasks = try taskRepository.fetchUnscheduled()
                .compactMap(UnscheduledTaskRowModel.init(task:))
                .sorted(by: Self.sortByTitle)
        } catch {
            assertionFailure("Unscheduled tasks fetch failed: \(error)")
            tasks = []
        }
    }

    nonisolated private static func sortByTitle(
        _ lhs: UnscheduledTaskRowModel,
        _ rhs: UnscheduledTaskRowModel
    ) -> Bool {
        let comparison = lhs.title.localizedStandardCompare(rhs.title)
        if comparison != .orderedSame {
            return comparison == .orderedAscending
        }
        return String(describing: lhs.id) < String(describing: rhs.id)
    }
}
