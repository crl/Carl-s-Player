import AppKit
import AVFoundation
import Foundation

final class ThumbnailService: @unchecked Sendable {
    static let shared = ThumbnailService()

    private let previewCache = NSCache<NSURL, NSImage>()
    private let firstFrameCache = NSCache<NSURL, NSImage>()

    private init() {
        previewCache.countLimit = 400
        firstFrameCache.countLimit = 80
    }

    func cachedImage(for item: MediaItem) -> NSImage? {
        previewCache.object(forKey: item.url as NSURL)
    }

    func cachedFirstFrame(for item: MediaItem) -> NSImage? {
        firstFrameCache.object(forKey: item.url as NSURL)
    }

    func image(for item: MediaItem) async -> NSImage? {
        let key = item.url as NSURL
        if let cached = previewCache.object(forKey: key) {
            return cached
        }
        let generated = await generate(item)
        if let generated {
            previewCache.setObject(generated, forKey: key)
        }
        return generated
    }

    /// Exact first decoded frame, used as the swipe cover so it matches playback at t=0.
    func firstFrame(for item: MediaItem) async -> NSImage? {
        if item.kind == .audio {
            return await image(for: item)
        }
        let key = item.url as NSURL
        if let cached = firstFrameCache.object(forKey: key) {
            return cached
        }
        let generated = await videoFrame(url: item.url, at: .zero, exact: true, maxSize: CGSize(width: 1080, height: 1920))
        if let generated {
            firstFrameCache.setObject(generated, forKey: key)
        }
        return generated
    }

    private func generate(_ item: MediaItem) async -> NSImage? {
        switch item.kind {
        case .video:
            if let preview = await videoFrame(
                url: item.url,
                at: CMTime(seconds: 1, preferredTimescale: 600),
                exact: false,
                maxSize: CGSize(width: 540, height: 960)
            ) {
                return preview
            }
            return await videoFrame(url: item.url, at: .zero, exact: false, maxSize: CGSize(width: 540, height: 960))
        case .audio:
            return await audioArtwork(url: item.url)
        }
    }

    private func videoFrame(url: URL, at time: CMTime, exact: Bool, maxSize: CGSize) async -> NSImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = maxSize
        if exact {
            generator.requestedTimeToleranceBefore = .zero
            generator.requestedTimeToleranceAfter = .zero
        } else {
            generator.requestedTimeToleranceBefore = CMTime(seconds: 0.5, preferredTimescale: 600)
            generator.requestedTimeToleranceAfter = CMTime(seconds: 0.5, preferredTimescale: 600)
        }
        guard let image = await cgImage(from: generator, at: time) else { return nil }
        return NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
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
