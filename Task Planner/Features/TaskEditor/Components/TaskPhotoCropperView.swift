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
    private let maxScale: CGFloat = 4.0

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
            }
            .navigationTitle("Crop Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use") { use() }
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                }
            }
            .interactiveDismissDisabled(true)
            .onAppear {
                scale = 1.0
                lastScale = 1.0
                offset = .zero
                lastOffset = .zero

                offset = clampOffset(offset, scale: scale)
                lastOffset = offset
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
        let result = TaskPhotoProcessor.makeThumbData(
            source: image,
            cropSidePoints: cropSide,
            scale: scale,
            offset: offset,
            cornerRadius: cornerRadius,
            outputPixels: outputPixelSize,
            quality: 0.70
        )

        guard let data = result else {
            onCancel()
            return
        }
        onUse(data)
    }
}
