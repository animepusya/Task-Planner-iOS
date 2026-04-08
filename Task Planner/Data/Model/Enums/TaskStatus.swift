//
//  TaskStatus.swift
//  Task Planner
//
//  Created by Руслан Меланин on 09.02.2026.
//

import Foundation

nonisolated enum TaskStatus: String, CaseIterable, Codable, Sendable {
    case todo
    case done
}
