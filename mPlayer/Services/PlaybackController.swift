import AVFoundation
import Foundation
import Observation

@Observable
@MainActor
final class PlaybackController {
    let player = AVPlayer()

    var isPlaying = false
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    var isSeeking = false
    var hasItem = false
    var finishToken = 0
    var volume: Float = 1 {
        didSet { player.volume = volume }
    }

    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var rateObserver: NSKeyValueObservation?

    init() {
        player.volume = volume
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.25, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            Task { @MainActor in
                guard let self, !self.isSeeking else { return }
                let seconds = time.seconds
                self.currentTime = seconds.isFinite ? seconds : 0
            }
        }
        rateObserver = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            Task { @MainActor in
                self?.isPlaying = player.timeControlStatus == .playing
            }
        }
    }

    func load(_ item: MediaItem) {
        player.pause()
        removeEndObserver()

        let playerItem = AVPlayerItem(url: item.url)
        player.replaceCurrentItem(with: playerItem)
        hasItem = true
        currentTime = 0
        duration = item.duration ?? 0

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.finishToken += 1
            }
        }

        Task {
            if let loaded = try? await playerItem.asset.load(.duration) {
                let seconds = loaded.seconds
                if seconds.isFinite, seconds >= 0 {
                    duration = seconds
                }
            }
            player.play()
            isPlaying = true
        }
    }

    func unload() {
        player.pause()
        removeEndObserver()
        player.replaceCurrentItem(with: nil)
        hasItem = false
        isPlaying = false
        currentTime = 0
        duration = 0
    }

    func togglePlay() {
        guard hasItem else { return }
        if isPlaying {
            player.pause()
            isPlaying = false
            return
        }
        if duration > 0, currentTime >= duration - 0.2 {
            replay()
        } else {
            player.play()
            isPlaying = true
        }
    }

    func replay() {
        player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] finished in
            guard finished else { return }
            Task { @MainActor in
                guard let self else { return }
                self.currentTime = 0
                self.player.play()
                self.isPlaying = true
            }
        }
    }

    func pauseAtEnd() {
        isPlaying = false
        if duration > 0 {
            currentTime = duration
        }
    }

    func seek(to time: TimeInterval) {
        let clamped = max(0, min(time, max(duration, 0)))
        let cmTime = CMTime(seconds: clamped, preferredTimescale: 600)
        player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = clamped
    }

    private func removeEndObserver() {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
    }
}
