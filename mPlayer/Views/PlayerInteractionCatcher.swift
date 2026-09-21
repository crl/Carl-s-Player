import AppKit
import SwiftUI

/// Converts wheel, trackpad, and mouse-drag into one Douyin-style pan.
/// `translationY > 0` moves content down (previous); `< 0` moves it up (next).
struct PlayerInteractionCatcher: NSViewRepresentable {
    var pageHeight: CGFloat
    var isPaging: Bool
    var onPan: (_ translationY: CGFloat, _ ended: Bool, _ isClick: Bool, _ isDrag: Bool) -> Void

    func makeNSView(context: Context) -> PlayerInteractionNSView {
        let view = PlayerInteractionNSView()
        view.pageHeight = pageHeight
        view.isPaging = isPaging
        view.onPan = onPan
        return view
    }

    func updateNSView(_ nsView: PlayerInteractionNSView, context: Context) {
        nsView.pageHeight = pageHeight
        nsView.onPan = onPan
        if isPaging, !nsView.isPaging {
            PlayerInteractionNSView.suppressScroll(for: 0.9)
        }
        nsView.isPaging = isPaging
    }
}

final class PlayerInteractionNSView: NSView {
    var pageHeight: CGFloat = 600
    var isPaging = false
    var onPan: ((_ translationY: CGFloat, _ ended: Bool, _ isClick: Bool, _ isDrag: Bool) -> Void)?

    private static var suppressUntil: TimeInterval = 0

    static func suppressScroll(for duration: TimeInterval) {
        suppressUntil = max(suppressUntil, Date().timeIntervalSinceReferenceDate + duration)
    }

    private var dragStartY: CGFloat?
    private var didDrag = false
    private var sessionOffset: CGFloat = 0
    private var sessionSign: CGFloat = 0
    private var lastEventTimestamp: TimeInterval = 0
    private var velocityY: CGFloat = 0
    private var idleEndWork: DispatchWorkItem?
    private var didFinishThisSession = false

    override var isOpaque: Bool { false }
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(point) ? self : nil
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func scrollWheel(with event: NSEvent) {
        if isPaging || Date().timeIntervalSinceReferenceDate < Self.suppressUntil {
            return
        }

        // Leftover inertia from the previous page must never start a new one.
        if !event.momentumPhase.isEmpty {
            return
        }

        // Finger/wheel up → content moves up → next. scrollingDeltaY is already
        // in that direction with natural scrolling on macOS.
        let contentDelta = event.scrollingDeltaY
        let precise = event.hasPreciseScrollingDeltas
        let hasPhase = !event.phase.isEmpty

        if !precise || !hasPhase {
            guard abs(event.scrollingDeltaY) > 0.2 else { return }
            finishSession(offset: contentDelta < 0 ? -pageHeight * 0.4 : pageHeight * 0.4, isDrag: false)
            return
        }

        if event.phase.contains(.began) {
            if didFinishThisSession {
                return
            }
            sessionOffset = 0
            sessionSign = 0
            velocityY = 0
            didFinishThisSession = false
        }

        if didFinishThisSession {
            return
        }

        var delta = contentDelta
        if sessionSign == 0, abs(delta) > 0.01 {
            sessionSign = delta < 0 ? -1 : 1
        }
        if sessionSign != 0, delta * sessionSign < 0 {
            delta = 0
        }

        let now = event.timestamp
        let dt = max(now - lastEventTimestamp, 0.001)
        lastEventTimestamp = now
        if abs(delta) > 0.01 {
            velocityY = delta / CGFloat(dt)
        }
        sessionOffset += delta
        sessionOffset = min(max(sessionOffset, -pageHeight), pageHeight)

        if event.phase.contains(.ended) || event.phase.contains(.cancelled) {
            finishSession(offset: commitOffset(for: sessionOffset), isDrag: false)
            return
        }

        onPan?(sessionOffset, false, false, false)
        armIdleEnd()
    }

    override func mouseDown(with event: NSEvent) {
        idleEndWork?.cancel()
        dragStartY = convert(event.locationInWindow, from: nil).y
        didDrag = false
        sessionOffset = 0
        sessionSign = 0
        velocityY = 0
        didFinishThisSession = false
        lastEventTimestamp = event.timestamp
        window?.makeFirstResponder(self)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let dragStartY else { return }
        let y = convert(event.locationInWindow, from: nil).y
        let previous = sessionOffset
        sessionOffset = y - dragStartY
        let now = event.timestamp
        let dt = max(now - lastEventTimestamp, 0.001)
        lastEventTimestamp = now
        velocityY = (sessionOffset - previous) / CGFloat(dt)
        if abs(sessionOffset) >= 8 {
            didDrag = true
        }
        if didDrag {
            onPan?(sessionOffset, false, false, true)
        }
    }

    override func mouseUp(with event: NSEvent) {
        defer {
            dragStartY = nil
            didDrag = false
            sessionOffset = 0
            sessionSign = 0
            velocityY = 0
        }
        window?.makeFirstResponder(self)
        guard let dragStartY else {
            onPan?(0, true, true, false)
            return
        }
        let y = convert(event.locationInWindow, from: nil).y
        let translation = y - dragStartY
        let isClick = !didDrag && abs(translation) < 8
        if isClick {
            onPan?(0, true, true, false)
            return
        }
        finishSession(offset: translation, isDrag: true)
    }

    private func commitOffset(for offset: CGFloat) -> CGFloat {
        let distanceCommit = abs(offset) >= 12
        let flickCommit = abs(velocityY) >= 480 && abs(offset) >= 8
        guard distanceCommit || flickCommit else { return offset }
        if abs(offset) >= pageHeight * 0.2 {
            return offset
        }
        return offset < 0 ? -pageHeight * 0.4 : pageHeight * 0.4
    }

    private func finishSession(offset: CGFloat, isDrag: Bool) {
        idleEndWork?.cancel()
        idleEndWork = nil
        guard !didFinishThisSession else { return }
        didFinishThisSession = true
        Self.suppressScroll(for: 0.9)
        onPan?(offset, true, false, isDrag)
        sessionOffset = 0
        sessionSign = 0
        velocityY = 0
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
            self?.didFinishThisSession = false
        }
    }

    private func armIdleEnd() {
        idleEndWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, !self.didFinishThisSession else { return }
            self.finishSession(offset: self.commitOffset(for: self.sessionOffset), isDrag: false)
        }
        idleEndWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
    }
}
