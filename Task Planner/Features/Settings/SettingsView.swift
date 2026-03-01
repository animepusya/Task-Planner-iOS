//
//  SettingsView.swift
//  Task Planner
//
//  Created by Руслан Меланин on 09.02.2026.
//

import Foundation
import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject var viewModel: SettingsViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: DS.Spacing.lg) {
                Capsule()
                    .fill(Color.secondary.opacity(0.25))
                    .frame(width: 40, height: 5)
                    .padding(.top, DS.Spacing.sm)

                Text("Settings")
                    .font(.title2).bold()

                VStack(spacing: DS.Spacing.md) {
                    preferencesCard
                    calendarCard
                    categoriesCard
                    dataCard
                }
                .padding(.horizontal, DS.Spacing.md)

                Spacer()
            }
            .background(DS.ColorToken.appBackground)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .padding(10)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                }
            }
        }
        .onAppear { viewModel.load() }
    }

    private var preferencesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preferences").font(.headline)
            HStack {
                Text("Week starts on Monday").foregroundStyle(.secondary)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { viewModel.weekStartsOnMonday },
                    set: { viewModel.setWeekStartsOnMonday($0) }
                ))
                .labelsHidden()
                .tint(.purple)
            }
        }
        .padding()
        .background(DS.ColorToken.cardBackground, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
    }

    private var calendarCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Apple Calendar").font(.headline)

            VStack(spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Show tasks in Apple Calendar")
                        Text("Exports to calendar “Task Planner” (one-way)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { viewModel.showTasksInAppleCalendar },
                        set: { viewModel.setShowTasksInAppleCalendar($0) }
                    ))
                    .labelsHidden()
                    .tint(.purple)
                }

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Show Apple Calendar events in Planner")
                        Text("Read-only overlay, not saved in SwiftData")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { viewModel.showAppleCalendarEventsInPlanner },
                        set: { viewModel.setShowAppleCalendarEventsInPlanner($0) }
                    ))
                    .labelsHidden()
                    .tint(.purple)
                }

                if !viewModel.calendarStatusText.isEmpty {
                    Text(viewModel.calendarStatusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                }

                if let err = viewModel.calendarErrorText {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(spacing: 10) {
                    Button {
                        viewModel.exportNow()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.up.right.square")
                            Text("Export now")
                            Spacer()
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(!viewModel.showTasksInAppleCalendar)

                    Button(role: .destructive) {
                        viewModel.removeExportedEvents()
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Remove exported events")
                            Spacer()
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(!viewModel.showTasksInAppleCalendar)
                }
            }
        }
        .padding()
        .background(DS.ColorToken.cardBackground, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
    }

    private var categoriesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Categories").font(.headline)

            HStack(spacing: 10) {
                TextField("Add category…", text: $viewModel.newCategoryTitle)
                    .textInputAutocapitalization(.words)
                    .disableAutocorrection(true)

                Button("Add") { viewModel.addCategory() }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    .disabled(viewModel.newCategoryTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            VStack(spacing: 8) {
                ForEach(viewModel.categories) { category in
                    HStack {
                        Text(category.title)
                            .foregroundStyle(.primary)
                        Spacer()

                        if viewModel.isDeletable(category) {
                            Button(role: .destructive) {
                                viewModel.deleteCategory(category)
                            } label: {
                                Image(systemName: "trash")
                            }
                        } else {
                            Image(systemName: "lock.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .padding()
        .background(DS.ColorToken.cardBackground, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
    }

    private var dataCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Data").font(.headline)
            Button(role: .destructive) {
                viewModel.clearAllTasks()
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Clear all tasks")
                    Spacer()
                }
            }
        }
        .padding()
        .background(DS.ColorToken.cardBackground, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
    }
}
