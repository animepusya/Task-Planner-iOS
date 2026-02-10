//
//  AppPreferencesEntity.swift
//  Task Planner
//
//  Created by Руслан Меланин on 09.02.2026.
//

import Foundation
import SwiftData

@Model
final class AppPreferencesEntity {
    var weekStartsOnMonday: Bool

    init(weekStartsOnMonday: Bool = true) {
        self.weekStartsOnMonday = weekStartsOnMonday
    }
}
