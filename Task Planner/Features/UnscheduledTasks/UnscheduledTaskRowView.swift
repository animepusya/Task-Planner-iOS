//
//  UnscheduledTaskRowView.swift
//  Task Planner
//

import SwiftData
import SwiftUI
import UIKit

nonisolated struct UnscheduledTaskRowModel: Identifiable, Equatable, Sendable {
    let id: PersistentIdentifier
    let title: String
    let categoryTitle: String?
    let color: TaskColor
    let photoThumbData: Data?

    @MainActor
    init?(task: TaskEntity) {
        guard task.isScheduled == false else { return nil }

        id = task.persistentModelID
        title = task.title
        categoryTitle = task.categoryTitle
        color = task.color
        photoThumbData = task.photoThumbData
    }
}

struct UnscheduledTaskRowView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dsAdaptiveMetrics) private var dsMetrics

    let task: UnscheduledTaskRowModel

    var body: some View {
        HStack(spacing: dsMetrics.spacing(12)) {
            leadingContent

            Spacer(minLength: 0)

            if let thumbImage {
                thumbContainer(thumbImage)
            }
        }
        .padding(.vertical, dsMetrics.spacing(DS.Spacing.md))
        .padding(.trailing, dsMetrics.spacing(DS.Spacing.md))
        .padding(.leading, dsMetrics.spacing(DS.Spacing.sm))
        .dsCard(padding: 0) {
            cardBackground
        }
    }

    private var leadingContent: some View {
        HStack(spacing: usesDarkAccentTreatment ? dsMetrics.spacing(DS.Spacing.sm) : 0) {
            if usesDarkAccentTreatment {
                accentBar
            }

            VStack(alignment: .leading, spacing: dsMetrics.spacing(6)) {
                Text(LocalizedDisplayText.taskTitle(task.title))
                    .font(
                        dsMetrics.font(
                            15,
                            weight: .semibold,
                            category: .body
                        )
                    )
                    .foregroundStyle(DS.ColorToken.textPrimary)
                    .lineLimit(2)

                Text(CategorySystem.localizedDisplayTitle(for: task.categoryTitle))
                    .font(
                        dsMetrics.font(
                            12,
                            weight: .medium,
                            category: .caption
                        )
                    )
                    .foregroundStyle(DS.ColorToken.textSecondary)
                    .lineLimit(1)
            }
        }
    }

    private func thumbContainer(_ image: UIImage) -> some View {
        let side = dsMetrics.controlSize(52)
        let cornerRadius = dsMetrics.cornerRadius(DS.Radius.sm)

        return ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(DS.Surface.chrome)

            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: side, height: side)
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(DS.Border.subtle, lineWidth: 1)
        )
        .padding(.leading, dsMetrics.spacing(2))
        .accessibilityLabel("Task photo")
    }

    @ViewBuilder
    private var cardBackground: some View {
        if usesDarkAccentTreatment {
            ZStack {
                DS.Surface.card
                task.color.uiColor.opacity(0.12)
            }
        } else {
            task.color.uiColor.opacity(0.40)
        }
    }

    private var accentBar: some View {
        RoundedRectangle(cornerRadius: dsMetrics.detailSize(3), style: .continuous)
            .fill(task.color.uiColor.opacity(0.96))
            .frame(
                width: dsMetrics.detailSize(4),
                height: dsMetrics.controlSize(48)
            )
            .shadow(
                color: task.color.uiColor.opacity(0.24),
                radius: dsMetrics.spacing(10)
            )
    }

    private var thumbImage: UIImage? {
        guard let data = task.photoThumbData else { return nil }
        return UIImage(data: data)
    }

    private var usesDarkAccentTreatment: Bool {
        colorScheme == .dark
    }
}
