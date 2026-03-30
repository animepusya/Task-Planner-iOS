//
//  TaskPhotoProcessor.swift
//  Task Planner
//
//  Created by Руслан Меланин on 27.02.2026.
//

import CoreGraphics
import Foundation
import ImageIO
import UIKit
import UniformTypeIdentifiers

enum TaskPhotoProcessor {
    static let cropPreviewSide: CGFloat = 280
    static let maximumZoomScale: CGFloat = 4
    static let thumbnailPixelSize: Int = 112
    static let thumbnailCompressionQuality: CGFloat = 0.72

    private static let processingQueue = DispatchQueue(
        label: "com.taskplanner.task-photo-processor",
        qos: .userInitiated,
        attributes: .concurrent
    )

    static func previewMaxPixelSize(
        for cropSidePoints: CGFloat = cropPreviewSide,
        screenScale: CGFloat
    ) -> Int {
        let scaledCrop = Int(ceil(cropSidePoints * max(1, screenScale) * 2.0))
        return max(thumbnailPixelSize * 8, scaledCrop)
    }

    static func preparePreviewImage(from data: Data, maxPixelSize: Int) async -> UIImage? {
        await runOnProcessingQueue {
            downsampledImage(from: data, maxPixelSize: maxPixelSize)
        }
    }

    static func makeThumbnailData(
        source: UIImage,
        cropSidePoints: CGFloat,
        scale: CGFloat,
        offset: CGSize,
        outputPixels: Int = thumbnailPixelSize,
        compressionQuality: CGFloat = thumbnailCompressionQuality
    ) async -> Data? {
        await runOnProcessingQueue {
            thumbnailDataSync(
                source: source,
                cropSidePoints: cropSidePoints,
                scale: scale,
                offset: offset,
                outputPixels: outputPixels,
                compressionQuality: compressionQuality
            )
        }
    }

    private static func runOnProcessingQueue<T>(
        _ operation: @escaping () -> T
    ) async -> T {
        await withCheckedContinuation { continuation in
            processingQueue.async {
                autoreleasepool {
                    continuation.resume(returning: operation())
                }
            }
        }
    }

    private static func downsampledImage(from data: Data, maxPixelSize: Int) -> UIImage? {
        guard maxPixelSize > 0 else { return nil }

        let sourceOptions = [
            kCGImageSourceShouldCache: false
        ] as CFDictionary

        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            return nil
        }

        let thumbOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ] as CFDictionary

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOptions) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }

    private static func thumbnailDataSync(
        source: UIImage,
        cropSidePoints: CGFloat,
        scale: CGFloat,
        offset: CGSize,
        outputPixels: Int,
        compressionQuality: CGFloat
    ) -> Data? {
        guard outputPixels > 0, cropSidePoints > 1, let cgImage = source.cgImage else {
            return nil
        }

        let safeScale = min(max(scale, 1), maximumZoomScale)
        let sourceWidth = CGFloat(cgImage.width)
        let sourceHeight = CGFloat(cgImage.height)
        let minDimension = min(sourceWidth, sourceHeight)
        guard minDimension >= 1 else { return nil }

        let displayScale = (cropSidePoints / minDimension) * safeScale
        guard displayScale > 0 else { return nil }

        let cropSide = max(1, min(minDimension / safeScale, minDimension))
        let centerX = (sourceWidth / 2) - (offset.width / displayScale)
        let centerY = (sourceHeight / 2) - (offset.height / displayScale)

        let unclampedOriginX = centerX - (cropSide / 2)
        let unclampedOriginY = centerY - (cropSide / 2)

        let originX = min(max(0, unclampedOriginX), max(0, sourceWidth - cropSide))
        let originY = min(max(0, unclampedOriginY), max(0, sourceHeight - cropSide))

        let cropRect = CGRect(
            x: originX.rounded(.down),
            y: originY.rounded(.down),
            width: max(1, cropSide.rounded(.down)),
            height: max(1, cropSide.rounded(.down))
        )

        guard let cropped = cgImage.cropping(to: cropRect) else {
            return nil
        }

        guard let scaled = resizedSquareImage(from: cropped, outputPixels: outputPixels) else {
            return nil
        }

        return jpegData(from: scaled, compressionQuality: compressionQuality)
    }

    private static func resizedSquareImage(from cgImage: CGImage, outputPixels: Int) -> CGImage? {
        let width = max(outputPixels, 1)
        let height = width

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.interpolationQuality = .high
        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        return context.makeImage()
    }

    private static func jpegData(from image: CGImage, compressionQuality: CGFloat) -> Data? {
        let mutableData = NSMutableData()

        guard let destination = CGImageDestinationCreateWithData(
            mutableData,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            return nil
        }

        let options = [
            kCGImageDestinationLossyCompressionQuality: min(max(compressionQuality, 0), 1)
        ] as CFDictionary

        CGImageDestinationAddImage(destination, image, options)
        guard CGImageDestinationFinalize(destination) else { return nil }

        return mutableData as Data
    }
}
