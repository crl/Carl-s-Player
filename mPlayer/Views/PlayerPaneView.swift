import AVFoundation
import AppKit
import SwiftUI

struct PlayerPaneView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        view.player = player
        return view
    }

    func updateNSView(_ nsView: PlayerContainerView, context: Context) {
        if nsView.player !== player {
            nsView.player = player
        }
    }
}

final class PlayerContainerView: NSView {
    private let playerLayer = AVPlayerLayer()
    private var itemObservation: NSKeyValueObservation?
    private var sizeObservation: NSKeyValueObservation?

    override var isOpaque: Bool { false }

    var player: AVPlayer? {
        get { playerLayer.player }
        set {
            playerLayer.player = newValue
            observePlayer(newValue)
            needsLayout = true
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.isOpaque = false
        layer?.backgroundColor = NSColor.clear.cgColor
        playerLayer.videoGravity = .resize
        playerLayer.backgroundColor = NSColor.clear.cgColor
        playerLayer.isOpaque = false
        layer?.addSublayer(playerLayer)
    }

    required init?(coder: NSCoder) {
        nil
    }

    deinit {
        itemObservation?.invalidate()
        sizeObservation?.invalidate()
    }

    override func layout() {
        super.layout()
        playerLayer.frame = fittedVideoRect(in: bounds)
    }

    private func observePlayer(_ player: AVPlayer?) {
        itemObservation?.invalidate()
        sizeObservation?.invalidate()
        guard let player else { return }
        itemObservation = player.observe(\.currentItem, options: [.initial, .new]) { [weak self] player, _ in
            DispatchQueue.main.async {
                self?.observePresentationSize(player.currentItem)
            }
        }
    }

    private func observePresentationSize(_ item: AVPlayerItem?) {
        sizeObservation?.invalidate()
        sizeObservation = item?.observe(\.presentationSize, options: [.initial, .new]) { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.needsLayout = true
            }
        }
        needsLayout = true
    }

    private func fittedVideoRect(in bounds: CGRect) -> CGRect {
        let size = playerLayer.player?.currentItem?.presentationSize ?? .zero
        guard size.width > 1, size.height > 1, bounds.width > 1, bounds.height > 1 else {
            return bounds
        }
        let aspect = size.width / size.height
        let viewAspect = bounds.width / bounds.height
        if viewAspect > aspect {
            let width = bounds.height * aspect
            return CGRect(x: ((bounds.width - width) / 2).rounded(.down), y: 0, width: width.rounded(), height: bounds.height)
        }
        let height = bounds.width / aspect
        return CGRect(x: 0, y: ((bounds.height - height) / 2).rounded(.down), width: bounds.width, height: height.rounded())
    }
}
