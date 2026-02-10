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
                    dataCard
                }
                .padding(.horizontal, DS.Spacing.md)

                Spacer()
            }
            .background(DS.ColorToken.appBackground)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
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
            Text("Preferences")
                .font(.headline)
            HStack {
                Text("Week starts on Monday")
                    .foregroundStyle(.secondary)
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

    private var dataCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Data")
                .font(.headline)
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
