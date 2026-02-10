//
//  TaskEditorView.swift
//  Task Planner
//
//  Created by Руслан Меланин on 09.02.2026.
//

import Foundation
import SwiftUI
import SwiftData

struct TaskEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject var viewModel: TaskEditorViewModel

    @Query(sort: \CategoryEntity.title, order: .forward)
    private var categories: [CategoryEntity]

    private let fallbackCategories = ["Work", "Study", "Hobby"]
    private let emptyTag = "" // пустая строка = nil при сохранении

    @State private var showAlert = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Task Name") {
                    TextField("Enter task name", text: $viewModel.title)
                }

                Section("Category") {
                    if categories.isEmpty {
                        Picker("Category", selection: $viewModel.categoryTitle) {
                            Text("Create category later").tag(emptyTag)
                            ForEach(fallbackCategories, id: \.self) { title in
                                Text(title).tag(title)
                            }
                        }
                        .pickerStyle(.menu)

                        Text("No categories yet. You can pick a default one for now and create categories later.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Category", selection: $viewModel.categoryTitle) {
                            Text("No category").tag(emptyTag)

                            ForEach(categories, id: \.id) { category in
                                Text(category.title).tag(category.title)
                            }

                            if !viewModel.categoryTitle.isEmpty &&
                                !categories.contains(where: { $0.title == viewModel.categoryTitle }) {
                                Text("\(viewModel.categoryTitle) (missing)")
                                    .tag(viewModel.categoryTitle)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                Section("Date & Time") {
                    DatePicker("Date", selection: $viewModel.dayDate, displayedComponents: [.date])
                        .onChange(of: viewModel.dayDate) { _ in
                            viewModel.syncTimesToSelectedDay()
                        }

                    DatePicker("Start Time", selection: $viewModel.startTime, displayedComponents: [.hourAndMinute])
                    DatePicker("End Time", selection: $viewModel.endTime, displayedComponents: [.hourAndMinute])
                }

                Section("Color") {
                    Picker("Color", selection: $viewModel.color) {
                        ForEach(TaskColor.allCases, id: \.self) { c in
                            Text(c.rawValue).tag(c)
                        }
                    }
                }

                Section("Repeat") {
                    Picker("Repeat", selection: $viewModel.repeatRule) {
                        ForEach(RepeatRule.allCases, id: \.self) { r in
                            Text(r.rawValue).tag(r)
                        }
                    }
                }

                Section("Notes") {
                    TextField("Add notes (optional)", text: $viewModel.notes, axis: .vertical)
                        .lineLimit(3...8)
                }
            }
            .navigationTitle(viewModel.navigationTitle)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(viewModel.isBusy)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        viewModel.isBusy = true
                        defer { viewModel.isBusy = false }

                        do {
                            try viewModel.save()
                            dismiss()
                        } catch {
                            viewModel.alertTitle = "Can't save"
                            viewModel.alertMessage = error.localizedDescription
                            showAlert = true
                        }
                    }
                    .disabled(viewModel.isBusy)
                }
            }
            .onChange(of: viewModel.alertTitle) { _, newValue in
                // показываем алерт, если VM выставила ошибку при загрузке
                if newValue != nil { showAlert = true }
            }
            .alert(viewModel.alertTitle ?? "Error", isPresented: $showAlert) {
                Button("Close", role: .cancel) {
                    dismiss()
                }
                if !viewModel.isEditing {
                    Button("OK") { }
                }
            } message: {
                Text(viewModel.alertMessage ?? "")
            }
        }
    }
}


