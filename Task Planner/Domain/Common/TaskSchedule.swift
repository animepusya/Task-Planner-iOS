//
//  TaskSchedule.swift
//  Task Planner
//

import Foundation

nonisolated struct TaskSchedule: Equatable, Sendable {
    let dayDate: Date
    let startTime: Date
    let endTime: Date
}

enum TaskSchedulingError: Error, Equatable {
    case seriesManagedTask
}
