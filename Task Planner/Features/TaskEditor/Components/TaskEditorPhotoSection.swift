//
//  TaskEditorPhotoSection.swift
//  Task Planner
//
//  Created by Руслан Меланин on 27.02.2026.
//

import SwiftUI
import PhotosUI

struct TaskEditorPhotoSection: View {
    @Binding var thumbData: Data?

    @State private var pickerItem: PhotosPickerItem?
    @State private var selectedUIImage: UIImage?
    @State private var showCropper = false

    private let previewSide: CGFloat = 68
    private let thumbCornerRadius: CGFloat = DS.Radius.sm

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Photo")
                .font(DS.Typography.sectionTitle)
                .foregroundStyle(DS.ColorToken.textPrimary)

            content
        }
        .dsCard()
        .sheet(isPresented: $showCropper) {
            if let img = selectedUIImage {
                TaskPhotoCropperView(
                    image: img,
                    cropSide: 280,
                    cornerRadius: thumbCornerRadius,
                    outputPixelSize: 112,
                    onCancel: {
                        selectedUIImage = nil
                        showCropper = false
                        pickerItem = nil
                    },
                    onUse: { data in
                        thumbData = data
                        selectedUIImage = nil
                        showCropper = false
                        pickerItem = nil
                    }
                )
            }
        }
        .onChange(of: pickerItem) { _, newValue in
            guard let newValue else { return }
            Task { await loadFromPicker(newValue) }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let thumbData, let ui = UIImage(data: thumbData) {
            HStack(spacing: DS.Spacing.md) {
                // ✅ Tap on image = Change
                PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                        .frame(width: previewSide, height: previewSide)
                        .cornerRadius(thumbCornerRadius)
                        .overlay(
                            RoundedRectangle(cornerRadius: thumbCornerRadius, style: .continuous)
                                .stroke(Color.black.opacity(0.06), lineWidth: 1)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Change photo")
                .accessibilityHint("Opens photo picker")

                Text("Photo attached")
                    .font(DS.Typography.body)
                    .foregroundStyle(DS.ColorToken.textPrimary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 10) {
                    changeButton
                    removeButton
                }
            }
        } else {
            HStack(spacing: DS.Spacing.md) {
                Text("Add photo")
                    .font(DS.Typography.body)
                    .foregroundStyle(DS.ColorToken.textPrimary)

                Spacer(minLength: 0)

                addButton
            }
        }
    }

    private var addButton: some View {
        PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
            pill("Add")
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add photo")
        .accessibilityHint("Opens photo picker")
    }

    private var changeButton: some View {
        PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
            pill("Change")
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Change photo")
        .accessibilityHint("Opens photo picker")
    }

    private var removeButton: some View {
        Button {
            thumbData = nil
        } label: {
            pill("Remove", isDestructive: true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Remove photo")
        .accessibilityHint("Removes photo attachment")
    }

    private func pill(_ title: String, isDestructive: Bool = false) -> some View {
        Text(title)
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(isDestructive ? Color.red.opacity(0.92) : DS.ColorToken.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.pill, style: .continuous)
                    .fill((isDestructive ? Color.red : DS.ColorToken.textSecondary).opacity(0.10))
            )
    }

    private func loadFromPicker(_ item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let ui = UIImage(data: data) else {
                await MainActor.run { pickerItem = nil }
                return
            }

            await MainActor.run {
                selectedUIImage = ui
                showCropper = true
            }
        } catch {
            await MainActor.run { pickerItem = nil }
        }
    }
}
