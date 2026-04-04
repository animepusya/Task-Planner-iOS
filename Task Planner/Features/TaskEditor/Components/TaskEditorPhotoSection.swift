//
//  TaskEditorPhotoSection.swift
//  Task Planner
//
//  Created by Руслан Меланин on 27.02.2026.
//

import PhotosUI
import SwiftUI

struct TaskEditorPhotoSection: View {
    @ObservedObject var state: TaskEditorViewModel.PhotoSectionState

    @Environment(\.displayScale) private var displayScale

    @State private var pickerItem: PhotosPickerItem?
    @State private var isPickerPresented = false
    @State private var draftPhoto: DraftPhoto?
    @State private var isLoadingPhoto = false
    @State private var loadErrorMessage: String?
    @State private var pickerLoadTask: Task<Void, Never>?
    @State private var previewImage: UIImage?

    private let previewSide: CGFloat = 68
    private let thumbCornerRadius: CGFloat = DS.Radius.sm

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            header
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsCard(style: .outlined)
        .photosPicker(
            isPresented: $isPickerPresented,
            selection: $pickerItem,
            matching: .images,
            photoLibrary: .shared()
        )
        .sheet(item: $draftPhoto) { draft in
            TaskPhotoCropperView(
                image: draft.image,
                cropSide: TaskPhotoProcessor.cropPreviewSide,
                cornerRadius: thumbCornerRadius,
                outputPixelSize: TaskPhotoProcessor.thumbnailPixelSize,
                onCancel: {
                    draftPhoto = nil
                },
                onUse: { data in
                    state.thumbDataBinding.wrappedValue = data
                    draftPhoto = nil
                }
            )
        }
        .alert(
            "Couldn't Load Photo",
            isPresented: Binding(
                get: { loadErrorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        loadErrorMessage = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(loadErrorMessage ?? "")
        }
        .onAppear(perform: refreshPreviewImage)
        .onChange(of: state.thumbData) { _, _ in
            refreshPreviewImage()
        }
        .onChange(of: pickerItem) { _, newValue in
            pickerLoadTask?.cancel()

            guard let newValue else { return }

            pickerLoadTask = Task {
                await loadFromPicker(newValue)
            }
        }
        .onDisappear {
            pickerLoadTask?.cancel()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Photo")
                .font(DS.Typography.sectionTitle)
                .foregroundStyle(DS.ColorToken.textPrimary)

            Text("Small thumbnail for task cards.")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.ColorToken.textSecondary)
        }
    }

    @ViewBuilder
    private var content: some View {
        if let previewImage {
            attachedPhotoContent(image: previewImage)
        } else {
            addPhotoContent
        }
    }

    private func attachedPhotoContent(image: UIImage) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Menu {
                Button("Replace", systemImage: "photo.badge.plus", action: presentPicker)

                Button("Delete", systemImage: "trash", role: .destructive) {
                    removePhoto()
                }
            } label: {
                photoButtonLabel {
                    attachedThumbnail(image: image)
                }
            }
            .menuIndicator(.hidden)
            .buttonStyle(.plain)
            .disabled(isLoadingPhoto)
            .accessibilityLabel("Photo options")
            .accessibilityHint("Shows options to replace or delete the photo")

            Text("Tap the photo to change it.")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.ColorToken.textSecondary)
                .padding(.leading, 2)
        }
    }

    private var addPhotoContent: some View {
        HStack(spacing: DS.Spacing.sm) {
            Button(action: presentPicker) {
                photoButtonLabel {
                    emptyThumbnail
                }
            }
            .buttonStyle(.plain)
            .disabled(isLoadingPhoto)
            .accessibilityLabel("Add photo")
            .accessibilityHint("Opens photo picker")

            Text("Tap the placeholder to add a photo.")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.ColorToken.textSecondary)
                .padding(.leading, 2)
        }
    }

    private func photoButtonLabel<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .overlay {
                if isLoadingPhoto {
                    loadingOverlay(title: String(localized: "Loading Photo"))
                        .clipShape(
                            RoundedRectangle(cornerRadius: thumbCornerRadius, style: .continuous)
                        )
                        .allowsHitTesting(false)
                }
            }
    }

    private func attachedThumbnail(image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: previewSide, height: previewSide)
            .clipShape(
                RoundedRectangle(cornerRadius: thumbCornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: thumbCornerRadius, style: .continuous)
                    .stroke(DS.Border.subtle, lineWidth: 1)
            )
    }

    private var emptyThumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: thumbCornerRadius, style: .continuous)
                .fill(DS.ColorToken.controlFillStrong)
                .frame(width: previewSide, height: previewSide)

            Image(systemName: "photo.badge.plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(DS.ColorToken.textSecondary)
        }
    }

    private func presentPicker() {
        guard !isLoadingPhoto else { return }
        Task { @MainActor in
            isPickerPresented = true
        }
    }

    private func removePhoto() {
        pickerLoadTask?.cancel()
        pickerItem = nil
        draftPhoto = nil
        previewImage = nil
        state.thumbDataBinding.wrappedValue = nil
        isLoadingPhoto = false
    }

    private func refreshPreviewImage() {
        guard let thumbData = state.thumbData else {
            previewImage = nil
            return
        }

        previewImage = UIImage(data: thumbData)
    }

    private func loadFromPicker(_ item: PhotosPickerItem) async {
        await MainActor.run {
            isLoadingPhoto = true
            loadErrorMessage = nil
        }

        defer {
            Task { @MainActor in
                pickerItem = nil
                isLoadingPhoto = false
            }
        }

        do {
            guard !Task.isCancelled else { return }

            guard let data = try await item.loadTransferable(type: Data.self) else {
                await MainActor.run {
                    loadErrorMessage = String(localized: "The selected photo isn't available right now.")
                }
                return
            }

            guard !Task.isCancelled else { return }

            let maxPixelSize = TaskPhotoProcessor.previewMaxPixelSize(screenScale: displayScale)
            let preparedImage = await TaskPhotoProcessor.preparePreviewImage(
                from: data,
                maxPixelSize: maxPixelSize
            )

            guard !Task.isCancelled else { return }

            guard let preparedImage else {
                await MainActor.run {
                    loadErrorMessage = String(localized: "Try a different image.")
                }
                return
            }

            await MainActor.run {
                draftPhoto = DraftPhoto(image: preparedImage)
            }
        } catch is CancellationError {
            return
        } catch {
            await MainActor.run {
                loadErrorMessage = String(localized: "Try a different image.")
            }
        }
    }

    private func loadingOverlay(title: String) -> some View {
        RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
            .fill(DS.Surface.chrome)
            .overlay {
                HStack(spacing: DS.Spacing.sm) {
                    ProgressView()
                    Text(title)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(DS.ColorToken.textPrimary)
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
            }
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .stroke(DS.Border.subtle, lineWidth: 1)
            )
    }
}

private struct DraftPhoto: Identifiable {
    let id = UUID()
    let image: UIImage
}
