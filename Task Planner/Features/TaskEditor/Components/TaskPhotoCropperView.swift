//
//  TaskPhotoCropperView.swift
//  Task Planner
//
//  Created by Руслан Меланин on 27.02.2026.
//

import SwiftUI

struct TaskPhotoCropperView: View {
    let image: UIImage

    let cropSide: CGFloat
    let cornerRadius: CGFloat
    let outputPixelSize: Int

    let onCancel: () -> Void
    let onUse: (Data) -> Void

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = TaskPhotoProcessor.maximumZoomScale

    @State private var isExporting = false
    @State private var exportErrorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                DS.ColorToken.appBackground.ignoresSafeArea()

                VStack {
                    Spacer(minLength: 0)

                    cropArea
                        .frame(width: cropSide, height: cropSide)
                        .padding(.top, 6)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.lg)

                if isExporting {
                    processingOverlay(title: "Preparing Photo")
                }
            }
            .navigationTitle("Adjust Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                        .disabled(isExporting)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use") { use() }
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .disabled(isExporting)
                }
            }
            .interactiveDismissDisabled(isExporting)
            .onAppear {
                scale = 1.0
                lastScale = 1.0
                offset = .zero
                lastOffset = .zero

                offset = clampOffset(offset, scale: scale)
                lastOffset = offset
            }
            .alert(
                "Couldn't Use Photo",
                isPresented: Binding(
                    get: { exportErrorMessage != nil },
                    set: { isPresented in
                        if !isPresented {
                            exportErrorMessage = nil
                        }
                    }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(exportErrorMessage ?? "")
            }
        }
    }

    private var cropArea: some View {
        let drag = DragGesture(minimumDistance: 1)
            .onChanged { value in
                let proposed = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
                offset = clampOffset(proposed, scale: scale)
            }
            .onEnded { _ in
                offset = clampOffset(offset, scale: scale)
                lastOffset = offset
            }

        let zoom = MagnificationGesture()
            .onChanged { value in
                let proposedScale = clampScale(lastScale * value)
                scale = proposedScale
                offset = clampOffset(offset, scale: proposedScale)
            }
            .onEnded { _ in
                scale = clampScale(scale)
                offset = clampOffset(offset, scale: scale)
                lastScale = scale
                lastOffset = offset
            }

        let combined = drag.simultaneously(with: zoom)

        return ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(DS.Surface.card)

            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: cropSide, height: cropSide)
                .scaleEffect(scale)
                .offset(offset)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(DS.Border.subtle, lineWidth: 1)
        )
        .allowsHitTesting(!isExporting)
        .highPriorityGesture(combined)
    }

    private func clampScale(_ v: CGFloat) -> CGFloat {
        min(max(v, minScale), maxScale)
    }

    private func clampOffset(_ proposed: CGSize, scale: CGFloat) -> CGSize {
        let iw = max(image.size.width, 1)
        let ih = max(image.size.height, 1)
        let aspect = iw / ih

        let baseW: CGFloat
        let baseH: CGFloat
        if aspect >= 1 {
            baseH = cropSide
            baseW = cropSide * aspect
        } else {
            baseW = cropSide
            baseH = cropSide / aspect
        }

        let contentW = baseW * scale
        let contentH = baseH * scale

        let maxX = max(0, (contentW - cropSide) / 2)
        let maxY = max(0, (contentH - cropSide) / 2)

        let clampedX = min(max(proposed.width, -maxX), maxX)
        let clampedY = min(max(proposed.height, -maxY), maxY)

        return CGSize(width: clampedX, height: clampedY)
    }

    private func use() {
        guard !isExporting else { return }

        let currentScale = scale
        let currentOffset = offset

        isExporting = true

        Task {
            let result = await TaskPhotoProcessor.makeThumbnailData(
                source: image,
                cropSidePoints: cropSide,
                scale: currentScale,
                offset: currentOffset,
                outputPixels: outputPixelSize
            )

            await MainActor.run {
                isExporting = false

                guard let data = result else {
                    exportErrorMessage = "Try a different crop or choose another photo."
                    return
                }

                onUse(data)
            }
        }
    }

    private func processingOverlay(title: String) -> some View {
        VStack(spacing: DS.Spacing.sm) {
            ProgressView()
                .scaleEffect(1.05)

            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(DS.ColorToken.textPrimary)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .fill(DS.Surface.chrome)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .stroke(DS.Border.subtle, lineWidth: 1)
        )
    }
}
