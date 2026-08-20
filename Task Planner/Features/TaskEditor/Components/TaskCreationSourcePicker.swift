//
//  TaskCreationSourcePicker.swift
//  Task Planner
//
//  Created by Codex on 20.08.2026.
//

import SwiftUI

struct TaskCreationSourcePicker: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dsAdaptiveMetrics) private var dsMetrics

    @ObservedObject var state: TaskEditorViewModel.CreationSourceState
    @State private var query = ""

    let isAdvancedRepeatLocked: Bool
    let onSelect: (TaskCreationSourceCandidate) -> Void

    private var filteredCandidates: [TaskCreationSourceCandidate] {
        state.filteredCandidates(matching: query)
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            searchField

            Group {
                if let message = state.loadErrorMessage, state.candidates.isEmpty {
                    emptyState(message)
                } else if filteredCandidates.isEmpty {
                    emptyState(
                        query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? String(localized: "No tasks yet")
                            : String(localized: "No matching tasks")
                    )
                } else {
                    sourceList
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(DS.ColorToken.appBackground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(dsMetrics.font(16, weight: .semibold, category: .micro))
                    .foregroundStyle(DS.ColorToken.textPrimary)
                    .frame(
                        width: dsMetrics.controlSize(44),
                        height: dsMetrics.controlSize(44)
                    )
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")

            Spacer()

            Text("Choose a task")
                .font(dsMetrics.font(18, weight: .semibold, category: .title))
                .foregroundStyle(DS.ColorToken.textPrimary)

            Spacer()

            Color.clear.frame(
                width: dsMetrics.controlSize(44),
                height: dsMetrics.controlSize(44)
            )
        }
        .padding(.horizontal, dsMetrics.screenPadding(DS.Spacing.lg))
        .padding(.vertical, dsMetrics.spacing(10))
        .dsContentFrame(.modal)
    }

    private var searchField: some View {
        HStack(spacing: dsMetrics.spacing(10)) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(DS.ColorToken.textSecondary)

            TextField("Search tasks", text: $query)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)

            if query.isEmpty == false {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(DS.ColorToken.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear")
            }
        }
        .font(dsMetrics.font(15, weight: .regular, category: .body))
        .padding(.horizontal, dsMetrics.spacing(14))
        .frame(minHeight: dsMetrics.controlSize(46))
        .background(DS.ColorToken.controlFill)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        .padding(.horizontal, dsMetrics.screenPadding(DS.Spacing.lg))
        .padding(.bottom, dsMetrics.spacing(DS.Spacing.md))
        .dsContentFrame(.modal)
    }

    private var sourceList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: dsMetrics.spacing(DS.Spacing.sm)) {
                ForEach(filteredCandidates) { candidate in
                    Button {
                        onSelect(candidate)
                    } label: {
                        TaskCreationSourceRow(
                            candidate: candidate,
                            showsProBadge: isAdvancedRepeatLocked && candidate.repeatRule.requiresProAccess,
                            trailingSystemName: nil
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, dsMetrics.screenPadding(DS.Spacing.lg))
            .padding(.bottom, dsMetrics.spacing(DS.Spacing.xl))
            .dsContentFrame(.modal)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func emptyState(_ message: String) -> some View {
        VStack(spacing: dsMetrics.spacing(DS.Spacing.sm)) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(dsMetrics.font(28, weight: .regular, category: .title))
                .foregroundStyle(DS.ColorToken.textSecondary)

            Text(message)
                .font(dsMetrics.font(15, weight: .regular, category: .body))
                .foregroundStyle(DS.ColorToken.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(dsMetrics.spacing(DS.Spacing.xl))
    }
}

struct TaskCreationSourceRow: View {
    @Environment(\.dsAdaptiveMetrics) private var dsMetrics

    let candidate: TaskCreationSourceCandidate
    let showsProBadge: Bool
    let trailingSystemName: String?

    private var details: String {
        var components = [candidate.displayCategoryTitle]
        if candidate.repeatRule != .none {
            components.append(candidate.repeatSummary)
        }
        components.append(candidate.timeSummary)
        return components.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: dsMetrics.spacing(12)) {
            Circle()
                .fill(candidate.color.uiColor)
                .frame(
                    width: dsMetrics.controlSize(12),
                    height: dsMetrics.controlSize(12)
                )

            VStack(alignment: .leading, spacing: dsMetrics.spacing(4)) {
                Text(candidate.displayTitle)
                    .font(dsMetrics.font(15, weight: .semibold, category: .body))
                    .foregroundStyle(DS.ColorToken.textPrimary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(details)
                    .font(dsMetrics.font(12, weight: .regular, category: .caption))
                    .foregroundStyle(DS.ColorToken.textSecondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if showsProBadge {
                ProBadge(size: .small)
            }

            if let trailingSystemName {
                Image(systemName: trailingSystemName)
                    .font(dsMetrics.font(12, weight: .semibold, category: .micro))
                    .foregroundStyle(DS.ColorToken.textSecondary)
            }
        }
        .padding(.horizontal, dsMetrics.spacing(12))
        .padding(.vertical, dsMetrics.spacing(10))
        .frame(maxWidth: .infinity, minHeight: dsMetrics.controlSize(56), alignment: .leading)
        .background(DS.ColorToken.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                .stroke(DS.Border.subtle, lineWidth: dsMetrics.strokeWidth(1))
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(candidate.displayTitle), \(details)")
    }
}
