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
        f.locale = .current
        f.dateFormat = "LLLL yyyy"
        return f.string(from: self).capitalizedStandaloneMonth()
    }

    func monthName(using calendar: Calendar = .current) -> String {
        let f = DateFormatter()
        f.calendar = calendar
        f.locale = .current
        f.dateFormat = "LLLL"
        return f.string(from: self).capitalizedStandaloneMonth()
    }

    func monthShortName(using calendar: Calendar = .current) -> String {
        let f = DateFormatter()
        f.calendar = calendar
        f.locale = .current
        f.dateFormat = "LLL"
        return f.string(from: self).capitalizedStandaloneMonth()
    }

    func dayTitle(using calendar: Calendar = .current) -> String {
        let f = DateFormatter()
        f.calendar = calendar
        f.locale = .current
        f.dateFormat = "d MMM yyyy"
        return f.string(from: self)
    }
}

private extension String {
    func capitalizedStandaloneMonth(locale: Locale = .current) -> String {
        guard let first else { return self }
        return String(first).uppercased(with: locale) + dropFirst()
    }
}
