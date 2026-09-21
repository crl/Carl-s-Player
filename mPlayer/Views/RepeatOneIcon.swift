import SwiftUI

/// Two separate curved arrows, not a closed ring.
struct RepeatCycleIcon: View {
    var showsOne = false

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            ZStack {
                Canvas { context, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    let radius = side * (showsOne ? 0.40 : 0.38)
                    let lineWidth = max(1.5, side * 0.10)
                    let headLength = side * 0.30
                    let headWidth = side * 0.26
                    let style = StrokeStyle(lineWidth: lineWidth, lineCap: .round)

                    // ~110° shafts with ~70° gaps so the heads stay distinct.
                    drawArrow(
                        context: &context,
                        center: center,
                        radius: radius,
                        tail: 218,
                        tip: 320,
                        style: style,
                        headLength: headLength,
                        headWidth: headWidth
                    )
                    drawArrow(
                        context: &context,
                        center: center,
                        radius: radius,
                        tail: 38,
                        tip: 140,
                        style: style,
                        headLength: headLength,
                        headWidth: headWidth
                    )
                }
                if showsOne {
                    Text("1")
                        .font(.system(size: side * 0.42, weight: .bold))
                        .offset(y: side * 0.02)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private func drawArrow(
        context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        tail: Double,
        tip: Double,
        style: StrokeStyle,
        headLength: CGFloat,
        headWidth: CGFloat
    ) {
        let headSweep = 28.0
        var shaft = Path()
        shaft.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(tail),
            endAngle: .degrees(tip - headSweep),
            clockwise: true
        )
        context.stroke(shaft, with: .foreground, style: style)
        context.fill(
            arrowhead(
                center: center,
                radius: radius,
                angleDegrees: tip,
                length: headLength,
                width: headWidth
            ),
            with: .foreground
        )
    }

    private func arrowhead(
        center: CGPoint,
        radius: CGFloat,
        angleDegrees: Double,
        length: CGFloat,
        width: CGFloat
    ) -> Path {
        let angle = angleDegrees * .pi / 180
        let tip = CGPoint(
            x: center.x + radius * Foundation.cos(angle),
            y: center.y + radius * Foundation.sin(angle)
        )
        let tx = -Foundation.sin(angle)
        let ty = Foundation.cos(angle)
        let nx = -ty
        let ny = tx
        let base = CGPoint(x: tip.x - tx * length, y: tip.y - ty * length)
        let left = CGPoint(x: base.x + nx * width / 2, y: base.y + ny * width / 2)
        let right = CGPoint(x: base.x - nx * width / 2, y: base.y - ny * width / 2)

        var path = Path()
        path.move(to: tip)
        path.addLine(to: left)
        path.addLine(to: right)
        path.closeSubpath()
        return path
    }
}

struct PlaybackModeIcon: View {
    let mode: PlaybackMode

    var body: some View {
        Group {
            switch mode {
            case .sequential:
                Image(systemName: mode.systemImage)
                    .resizable()
                    .scaledToFit()
            case .loopAll:
                RepeatCycleIcon()
            case .loopOne:
                RepeatCycleIcon(showsOne: true)
            }
        }
        .frame(width: 22, height: 22)
        .frame(width: 28, height: 24)
    }
}
