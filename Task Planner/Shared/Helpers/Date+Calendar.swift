//
//  Date+Calendar.swift
//  Task Planner
//
//  Created by Руслан Меланин on 10.02.2026.
//

import Foundation

extension Date {

    func startOfDay(using calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: self)
    }

    func addingMonths(_ value: Int, using calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .month, value: value, to: self) ?? self
    }
}
