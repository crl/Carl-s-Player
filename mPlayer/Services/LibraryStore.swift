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

    /// Set by `requestSelect`; PlayerDetailView animates then calls `commitPendingTransition`.
    var pendingTransition: MediaTransition?

    private var securityScopedURL: URL?
    private var scanGeneration = 0

    struct MediaTransition: Equatable {
        let itemID: MediaItem.ID
        /// `+1` next (swipe up), `-1` previous (swipe down).
        let delta: Int
    }

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
        pendingTransition = nil
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
            if !requestNextLikeScroll(wrapping: false) {
                playback.pauseAtEnd()
            }
        case .loopAll:
            if !requestNextLikeScroll(wrapping: true) {
                playback.replay()
            }
        }
    }

    func item(offset: Int, wrapping: Bool) -> MediaItem? {
        guard !items.isEmpty else { return nil }
        guard let selectedID, let index = items.firstIndex(where: { $0.id == selectedID }) else {
            return items.first
        }
        let target = index + offset
        if wrapping {
            let count = items.count
            let wrapped = ((target % count) + count) % count
            return items[wrapped]
        }
        guard items.indices.contains(target) else { return nil }
        return items[target]
    }

    var wrapsAdjacently: Bool {
        playbackMode == .loopAll
    }

    func requestSelect(_ item: MediaItem) {
        guard items.contains(where: { $0.id == item.id }) else { return }
        if selectedID == nil || selectedID == item.id {
            selectedID = item.id
            pendingTransition = nil
            return
        }
        let delta = direction(to: item)
        guard delta != 0 else {
            selectedID = item.id
            pendingTransition = nil
            return
        }
        pendingTransition = MediaTransition(itemID: item.id, delta: delta)
    }

    func requestAdjacent(delta: Int) -> MediaItem? {
        guard let item = item(offset: delta, wrapping: wrapsAdjacently) else { return nil }
        if item.id == selectedID { return nil }
        pendingTransition = MediaTransition(itemID: item.id, delta: delta)
        return item
    }

    /// Always slides the next item up from below, matching a Douyin-style scroll.
    @discardableResult
    func requestNextLikeScroll(wrapping: Bool) -> Bool {
        guard let next = item(offset: 1, wrapping: wrapping), next.id != selectedID else {
            return false
        }
        pendingTransition = MediaTransition(itemID: next.id, delta: 1)
        return true
    }

    func commitPendingTransition() {
        guard let pending = pendingTransition else { return }
        selectedID = pending.itemID
        pendingTransition = nil
    }

    private func direction(to item: MediaItem) -> Int {
        guard let selectedID,
              let from = items.firstIndex(where: { $0.id == selectedID }),
              let to = items.firstIndex(where: { $0.id == item.id }),
              from != to
        else { return 0 }
        if wrapsAdjacently {
            if from == items.count - 1, to == 0 { return 1 }
            if from == 0, to == items.count - 1 { return -1 }
        }
        return to > from ? 1 : -1
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
