import AppKit
import SwiftUI

struct SidebarResizeHandle: NSViewRepresentable {
    @Binding var width: CGFloat
    var range: ClosedRange<CGFloat> = 220...560

    func makeCoordinator() -> Coordinator {
        Coordinator(width: $width, range: range)
    }

    func makeNSView(context: Context) -> SplitterNSView {
        let view = SplitterNSView()
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ nsView: SplitterNSView, context: Context) {
        context.coordinator.width = $width
        context.coordinator.range = range
        nsView.coordinator = context.coordinator
    }

    final class Coordinator {
        var width: Binding<CGFloat>
        var range: ClosedRange<CGFloat>
        var startWidth: CGFloat = 0
        var startX: CGFloat = 0

        init(width: Binding<CGFloat>, range: ClosedRange<CGFloat>) {
            self.width = width
            self.range = range
        }
    }
}

final class SplitterNSView: NSView {
    var coordinator: SidebarResizeHandle.Coordinator?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var isFlipped: Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .resizeLeftRight)
    }

    override func draw(_ dirtyRect: NSRect) {
        let lineWidth: CGFloat = 1
        let x = ((bounds.width - lineWidth) / 2).rounded(.down)
        NSColor.separatorColor.setFill()
        NSBezierPath(rect: NSRect(x: x, y: 0, width: lineWidth, height: bounds.height)).fill()
    }

    override func mouseDown(with event: NSEvent) {
        guard let coordinator else { return }
        coordinator.startWidth = coordinator.width.wrappedValue
        coordinator.startX = event.locationInWindow.x
        NSCursor.resizeLeftRight.set()
    }

    override func mouseDragged(with event: NSEvent) {
        guard let coordinator else { return }
        let delta = event.locationInWindow.x - coordinator.startX
        let next = min(
            max(coordinator.startWidth + delta, coordinator.range.lowerBound),
            coordinator.range.upperBound
        )
        if next != coordinator.width.wrappedValue {
            coordinator.width.wrappedValue = next
        }
    }

    override func mouseUp(with event: NSEvent) {
        window?.invalidateCursorRects(for: self)
    }
}
