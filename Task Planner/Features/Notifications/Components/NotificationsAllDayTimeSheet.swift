//
//  NotificationsAllDayTimeSheet.swift
//  Task Planner
//
//  Created by Руслан Меланин on 03.03.2026.
//

import SwiftUI

struct NotificationsAllDayTimeSheet: View {
    let selectedMinutes: Int
    let onSelect: (Int) -> Void
    let onClose: () -> Void

    @State private var tempDate: Date = .now

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            HStack {
                Text("All-day time")
                    .font(DS.Typography.sectionTitle)
                    .foregroundStyle(DS.ColorToken.textPrimary)
                Spacer()
                Button("Close", action: onClose)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
            }
            .padding(.top, 6)

            VStack(alignment: .leading, spacing: 10) {
                Text("Default time for all-day reminders.")
                    .font(DS.Typography.body)
                    .foregroundStyle(DS.ColorToken.textSecondary)

                DatePicker(
                    "",
                    selection: $tempDate,
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()
                .datePickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                .clipped()

                Button {
                    let minutes = TimeOfDayMinutes.minutes(from: tempDate)
                    onSelect(minutes)
                } label: {
                    HStack {
                        Spacer()
                        Text("Apply")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    .padding(.vertical, 12)
                    .background(DS.GradientToken.brand)
                    .cornerRadius(DS.Radius.sm)
                    .shadow(color: DS.Shadow.soft, radius: 14, x: 0, y: 10)
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.bottom, 18)
        .background(DS.ColorToken.appBackground.ignoresSafeArea())
        .onAppear {
            // Build date from selectedMinutes for wheel picker
            let today = Calendar.current.startOfDay(for: .now)
            tempDate = TimeOfDayMinutes.date(on: today, minutes: selectedMinutes)
        }
    }
}
