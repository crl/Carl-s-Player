import AVFoundation
import AppKit
import SwiftUI

struct PlayerPaneView: NSViewRepresentable {
    let player: AVPlayer
    var onReadyForDisplayChange: ((Bool) -> Void)? = nil

    func makeNSView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        view.player = player
        view.onReadyForDisplayChange = onReadyForDisplayChange
        return view
    }

    func updateNSView(_ nsView: PlayerContainerView, context: Context) {
        nsView.onReadyForDisplayChange = onReadyForDisplayChange
        if nsView.player !== player {
            nsView.player = player
        }
    }
}

final class PlayerContainerView: NSView {
    private let playerLayer = AVPlayerLayer()
    private var itemObservation: NSKeyValueObservation?
    private var sizeObservation: NSKeyValueObservation?
    private var readyObservation: NSKeyValueObservation?
    private var lastAspect: CGFloat?

    override var isOpaque: Bool { false }

    var onReadyForDisplayChange: ((Bool) -> Void)?

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
        playerLayer.videoGravity = .resizeAspect
        playerLayer.backgroundColor = NSColor.clear.cgColor
        playerLayer.isOpaque = false
        playerLayer.actions = [
            "bounds": NSNull(),
            "contents": NSNull(),
            "contentsRect": NSNull(),
            "frame": NSNull(),
            "position": NSNull()
        ]
        layer?.addSublayer(playerLayer)
        readyObservation = playerLayer.observe(\.isReadyForDisplay, options: [.initial, .new]) { [weak self] layer, _ in
            DispatchQueue.main.async {
                self?.onReadyForDisplayChange?(layer.isReadyForDisplay)
            }
        }
    }

    required init?(coder: NSCoder) {
        nil
    }

    deinit {
        itemObservation?.invalidate()
        sizeObservation?.invalidate()
        readyObservation?.invalidate()
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        playerLayer.frame = fittedVideoRect(in: bounds)
        CATransaction.commit()
    }

    private func observePlayer(_ player: AVPlayer?) {
        itemObservation?.invalidate()
        sizeObservation?.invalidate()
        guard let player else { return }
        itemObservation = player.observe(\.currentItem, options: [.initial, .new]) { [weak self] player, _ in
            DispatchQueue.main.async {
                self?.lastAspect = nil
                self?.onReadyForDisplayChange?(false)
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
        let aspect: CGFloat
        if size.width > 1, size.height > 1 {
            aspect = size.width / size.height
            lastAspect = aspect
        } else if let lastAspect {
            aspect = lastAspect
        } else {
            return .zero
        }
        guard bounds.width > 1, bounds.height > 1 else { return .zero }
        let viewAspect = bounds.width / bounds.height
        if viewAspect > aspect {
            let width = bounds.height * aspect
            return CGRect(x: ((bounds.width - width) / 2).rounded(.down), y: 0, width: width.rounded(), height: bounds.height)
        }
        let height = bounds.width / aspect
        return CGRect(x: 0, y: ((bounds.height - height) / 2).rounded(.down), width: bounds.width, height: height.rounded())
    }
}
