//
//  CategoryEntity.swift
//  Task Planner
//
//  Created by Руслан Меланин on 09.02.2026.
//

import Foundation
import SwiftData

@Model
final class CategoryEntity {
    @Attribute(.unique) var id: String
    var title: String

    init(id: String, title: String) {
        self.id = id
        self.title = title
    }
}
