//
//  Date+Formatting.swift
//  Task Planner
//
//  Created by Руслан Меланин on 10.02.2026.
//

import Foundation

extension Date {

    func monthTitle(using calendar: Calendar = .current) -> String {
        let f = DateFormatter()
        f.calendar = calendar
        f.dateFormat = "LLLL yyyy"
        return f.string(from: self)
    }
    
    func monthName(using calendar: Calendar = .current) -> String {
        let f = DateFormatter()
        f.calendar = calendar
        f.dateFormat = "LLLL"
        return f.string(from: self)
    }

    func dayTitle(using calendar: Calendar = .current) -> String {
        let f = DateFormatter()
        f.calendar = calendar
        f.dateFormat = "d MMM yyyy"
        return f.string(from: self)
    }
}
