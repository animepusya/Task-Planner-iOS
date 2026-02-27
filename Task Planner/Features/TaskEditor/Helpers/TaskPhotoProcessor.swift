//
//  TaskPhotoProcessor.swift
//  Task Planner
//
//  Created by Руслан Меланин on 27.02.2026.
//

import SwiftUI

enum TaskPhotoProcessor {

    /// Builds a small rounded thumbnail with REAL rounded pixels (alpha).
    /// - Renders in cropSidePoints coordinate space (same as crop UI).
    /// - Downscales via renderer.scale to outputPixels.
    /// - Saves PNG to preserve transparency for rounded corners.
    static func makeThumbData(
        source: UIImage,
        cropSidePoints: CGFloat,
        scale: CGFloat,
        offset: CGSize,
        cornerRadius: CGFloat,
        outputPixels: Int,
        quality: CGFloat
    ) -> Data? {
        guard outputPixels > 0, cropSidePoints > 1 else { return nil }

        let content = thumbRenderView(
            image: source,
            cropSidePoints: cropSidePoints,
            scale: scale,
            offset: offset,
            cornerRadius: cornerRadius
        )

        let renderer = ImageRenderer(content: content)

        // Render exactly in the same coordinate space as UI crop
        renderer.proposedSize = .init(width: cropSidePoints, height: cropSidePoints)

        // Downscale to target pixels
        renderer.scale = CGFloat(outputPixels) / cropSidePoints

        // ✅ Critical: keep alpha (transparent corners)
        renderer.isOpaque = false

        guard let uiImage = renderer.uiImage else { return nil }

        // ✅ PNG keeps alpha reliably (rounded pixels stay rounded without any clip in TaskCardView)
        return uiImage.pngData()
    }

    private static func thumbRenderView(
        image: UIImage,
        cropSidePoints: CGFloat,
        scale: CGFloat,
        offset: CGSize,
        cornerRadius: CGFloat
    ) -> some View {
        ZStack {
            // ✅ Explicit clear background so corners are truly transparent
            Color.clear

            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: cropSidePoints, height: cropSidePoints)
                .scaleEffect(scale)
                .offset(offset)
        }
        .frame(width: cropSidePoints, height: cropSidePoints)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
