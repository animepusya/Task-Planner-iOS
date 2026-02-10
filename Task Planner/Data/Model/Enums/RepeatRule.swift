//
//  RepeatRule.swift
//  Task Planner
//
//  Created by Руслан Меланин on 09.02.2026.
//

import Foundation

enum RepeatRule: String, CaseIterable, Codable {
    case none
    case daily
    case weekly
    case monthly
}
