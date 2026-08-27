import AppKit
import AVFoundation
import Observation

@Observable
@MainActor
final class LibraryStore {
    private static let videoExtensions: Set<String> = ["mp4", "mov", "m4v", "avi"]
    private static let audioExtensions: Set<String> = ["mp3", "m4a", "aac", "wav", "aiff"]

    var folderURL: URL?
    var folderName: String?
    var items: [MediaItem] = []
    var selectedID: MediaItem.ID?
    var playbackMode: PlaybackMode = .sequential
    var thumbnailSize: Double = 88

    static let thumbnailSizeRange = 64.0...220.0

    var thumbnailSizeT: CGFloat {
        let lower = Self.thumbnailSizeRange.lowerBound
        let span = Self.thumbnailSizeRange.upperBound - lower
        guard span > 0 else { return 0 }
        return CGFloat((thumbnailSize - lower) / span)
    }

    var selectedItem: MediaItem? {
        items.first { $0.id == selectedID }
    }

    private var securityScopedURL: URL?
    private var scanGeneration = 0

    func openFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.message = "选择包含视频或音频的文件夹"
        panel.prompt = "打开"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        load(folder: url)
    }

    func load(folder url: URL) {
        stopAccessing()
        _ = url.startAccessingSecurityScopedResource()
        securityScopedURL = url
        folderURL = url
        folderName = url.lastPathComponent
        selectedID = nil
        items = Self.scan(url)
        scanGeneration += 1
        let generation = scanGeneration
        Task { await loadDurations(generation: generation) }
    }

    func handlePlaybackFinished(_ playback: PlaybackController) {
        switch playbackMode {
        case .loopOne:
            playback.replay()
        case .sequential:
            if let next = nextItem(wrapping: false) {
                selectedID = next.id
            } else {
                playback.pauseAtEnd()
            }
        case .loopAll:
            guard let next = nextItem(wrapping: true) else { return }
            if next.id == selectedID {
                playback.replay()
            } else {
                selectedID = next.id
            }
        }
    }

    private func nextItem(wrapping: Bool) -> MediaItem? {
        guard !items.isEmpty else { return nil }
        guard let selectedID, let index = items.firstIndex(where: { $0.id == selectedID }) else {
            return items.first
        }
        let nextIndex = index + 1
        if nextIndex < items.count {
            return items[nextIndex]
        }
        return wrapping ? items.first : nil
    }

    private func stopAccessing() {
        securityScopedURL?.stopAccessingSecurityScopedResource()
        securityScopedURL = nil
    }

    private func loadDurations(generation: Int) async {
        for index in items.indices {
            guard generation == scanGeneration else { return }
            let url = items[index].url
            let asset = AVURLAsset(url: url)
            guard let duration = try? await asset.load(.duration) else { continue }
            let seconds = duration.seconds
            guard seconds.isFinite, seconds >= 0 else { continue }
            if generation == scanGeneration {
                items[index].duration = seconds
            }
        }
    }

    private static func scan(_ root: URL) -> [MediaItem] {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        var result: [MediaItem] = []
        for case let fileURL as URL in enumerator {
            let ext = fileURL.pathExtension.lowercased()
            let kind: MediaItem.Kind?
            if videoExtensions.contains(ext) {
                kind = .video
            } else if audioExtensions.contains(ext) {
                kind = .audio
            } else {
                kind = nil
            }
            guard let kind else { continue }

            let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey])
            guard values?.isRegularFile == true else { continue }
            result.append(MediaItem(url: fileURL, kind: kind))
        }

        result.sort {
            let nameOrder = $0.name.localizedStandardCompare($1.name)
            if nameOrder != .orderedSame {
                return nameOrder == .orderedAscending
            }
            return $0.url.path.localizedStandardCompare($1.url.path) == .orderedAscending
        }
        return result
    }
}
