import AppKit
import AVFoundation
import Foundation

final class ThumbnailService: @unchecked Sendable {
    static let shared = ThumbnailService()

    private let cache = NSCache<NSURL, NSImage>()

    private init() {
        cache.countLimit = 400
    }

    func image(for item: MediaItem) async -> NSImage? {
        let key = item.url as NSURL
        if let cached = cache.object(forKey: key) {
            return cached
        }
        let generated = await generate(item)
        if let generated {
            cache.setObject(generated, forKey: key)
        }
        return generated
    }

    private func generate(_ item: MediaItem) async -> NSImage? {
        switch item.kind {
        case .video:
            return await videoThumbnail(url: item.url)
        case .audio:
            return await audioArtwork(url: item.url)
        }
    }

    private func videoThumbnail(url: URL) async -> NSImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 320, height: 180)
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.5, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.5, preferredTimescale: 600)

        if let image = await cgImage(from: generator, at: CMTime(seconds: 1, preferredTimescale: 600)) {
            return NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        }
        if let image = await cgImage(from: generator, at: .zero) {
            return NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        }
        return nil
    }

    private func cgImage(from generator: AVAssetImageGenerator, at time: CMTime) async -> CGImage? {
        await withCheckedContinuation { continuation in
            generator.generateCGImageAsynchronously(for: time) { image, _, _ in
                continuation.resume(returning: image)
            }
        }
    }

    private func audioArtwork(url: URL) async -> NSImage? {
        let asset = AVURLAsset(url: url)
        guard let metadata = try? await asset.load(.commonMetadata) else { return nil }
        for item in metadata where item.commonKey == .commonKeyArtwork {
            if let data = try? await item.load(.dataValue), let image = NSImage(data: data) {
                return image
            }
            if let value = try? await item.load(.value) as? Data, let image = NSImage(data: value) {
                return image
            }
        }
        return nil
    }
}
