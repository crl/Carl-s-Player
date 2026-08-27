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

    var player: AVPlayer? {
        get { playerLayer.player }
        set { playerLayer.player = newValue }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        playerLayer.videoGravity = .resizeAspect
        layer?.addSublayer(playerLayer)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()
        playerLayer.frame = bounds
    }
}
