import AppKit
import SwiftUI

/// Converts wheel, trackpad, and mouse-drag into one Douyin-style pan.
/// `translationY > 0` moves content down (previous); `< 0` moves it up (next).
struct PlayerInteractionCatcher: NSViewRepresentable {
    var pageHeight: CGFloat
    var onPan: (_ translationY: CGFloat, _ ended: Bool, _ isClick: Bool) -> Void

    func makeNSView(context: Context) -> PlayerInteractionNSView {
        let view = PlayerInteractionNSView()
        view.pageHeight = pageHeight
        view.onPan = onPan
        return view
    }

    func updateNSView(_ nsView: PlayerInteractionNSView, context: Context) {
        nsView.pageHeight = pageHeight
        nsView.onPan = onPan
    }
}

final class PlayerInteractionNSView: NSView {
    var pageHeight: CGFloat = 600
    var onPan: ((_ translationY: CGFloat, _ ended: Bool, _ isClick: Bool) -> Void)?

    private var dragStartY: CGFloat?
    private var didDrag = false
    private var sessionOffset: CGFloat = 0
    private var gestureLocked = false
    private var idleUnlockWork: DispatchWorkItem?

    override var isOpaque: Bool { false }
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func scrollWheel(with event: NSEvent) {
        if gestureLocked {
            armIdleUnlock()
            return
        }

        // Scroll up (positive scrollingDeltaY) → content moves up → negative offset → next.
        let contentDelta = -event.scrollingDeltaY
        let precise = event.hasPreciseScrollingDeltas
        let hasPhase = !event.phase.isEmpty || !event.momentumPhase.isEmpty

        if !precise || !hasPhase {
            guard abs(event.scrollingDeltaY) > 0.2 else { return }
            gestureLocked = true
            let tick = contentDelta < 0 ? -pageHeight * 0.4 : pageHeight * 0.4
            onPan?(tick, true, false)
            sessionOffset = 0
            armIdleUnlock()
            return
        }

        if event.phase.contains(.began) {
            sessionOffset = 0
        }
        sessionOffset += contentDelta
        let ended = event.phase.contains(.ended) || event.momentumPhase.contains(.ended)
        onPan?(sessionOffset, ended, false)
        if ended {
            gestureLocked = true
            sessionOffset = 0
            armIdleUnlock()
        }
    }

    override func mouseDown(with event: NSEvent) {
        dragStartY = convert(event.locationInWindow, from: nil).y
        didDrag = false
        sessionOffset = 0
    }

    override func mouseDragged(with event: NSEvent) {
        guard !gestureLocked, let dragStartY else { return }
        let y = convert(event.locationInWindow, from: nil).y
        sessionOffset = y - dragStartY
        if abs(sessionOffset) >= 8 {
            didDrag = true
        }
        if didDrag {
            onPan?(sessionOffset, false, false)
        }
    }

    override func mouseUp(with event: NSEvent) {
        defer {
            dragStartY = nil
            didDrag = false
            sessionOffset = 0
        }
        if gestureLocked { return }
        guard let dragStartY else {
            onPan?(0, true, true)
            return
        }
        let y = convert(event.locationInWindow, from: nil).y
        let translation = y - dragStartY
        let isClick = !didDrag && abs(translation) < 8
        if !isClick {
            gestureLocked = true
            armIdleUnlock()
        }
        onPan?(translation, true, isClick)
    }

    private func armIdleUnlock() {
        idleUnlockWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.gestureLocked = false
        }
        idleUnlockWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55, execute: work)
    }
}
