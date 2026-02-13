//
//  MonthYearPickerSheet.swift
//  Task Planner
//
//  Created by Руслан Меланин on 13.02.2026.
//

import SwiftUI

struct MonthYearPickerSheet: View {
    let initialAnchor: Date
    let yearRange: ClosedRange<Int>
    let onToday: () -> Void
    let onDone: (_ month: Int, _ year: Int) -> Void
    let onClose: () -> Void

    @State private var selectedMonth: Int
    @State private var selectedYear: Int

    init(
        initialAnchor: Date,
        yearRange: ClosedRange<Int>,
        onToday: @escaping () -> Void,
        onDone: @escaping (_ month: Int, _ year: Int) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.initialAnchor = initialAnchor
        self.yearRange = yearRange
        self.onToday = onToday
        self.onDone = onDone
        self.onClose = onClose

        let cal = Calendar.current
        let comps = cal.dateComponents([.month, .year], from: initialAnchor)
        _selectedMonth = State(initialValue: comps.month ?? 1)
        _selectedYear = State(initialValue: comps.year ?? cal.component(.year, from: .now))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    Picker("Month", selection: $selectedMonth) {
                        ForEach(1...12, id: \.self) { month in
                            Text(monthName(for: month)).tag(month)
                        }
                    }
                    .pickerStyle(.wheel)

                    Picker("Year", selection: $selectedYear) {
                        ForEach(Array(yearRange), id: \.self) { year in
                            Text("\(year)").tag(year)
                        }
                    }
                    .pickerStyle(.wheel)
                }
                .frame(height: 180)
                .clipped()

                Button {
                    onToday()
                    onClose()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Today")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(DS.ColorToken.purple)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .background(
                        Capsule()
                            .fill(DS.ColorToken.purple.opacity(0.12))
                    )
                }
                .buttonStyle(.plain)
                .padding(.top, 2)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .navigationTitle("Select month")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { onClose() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onDone(selectedMonth, selectedYear)
                        onClose()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func monthName(for month: Int) -> String {
        var comps = DateComponents()
        comps.year = 2000
        comps.month = month
        comps.day = 1

        let cal = Calendar.current
        let date = cal.date(from: comps) ?? .now

        let f = DateFormatter()
        f.calendar = cal
        f.locale = .current
        f.dateFormat = "LLLL"
        return f.string(from: date)
    }
}
