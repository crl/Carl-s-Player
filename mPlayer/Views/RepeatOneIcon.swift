import SwiftUI

struct RepeatOneIcon: View {
    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            ZStack {
                Canvas { context, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    let radius = side * 0.40
                    let lineWidth = max(1.4, side * 0.11)
                    let style = StrokeStyle(lineWidth: lineWidth, lineCap: .round)

                    context.stroke(
                        arc(center: center, radius: radius, start: 205, end: 335),
                        with: .foreground,
                        style: style
                    )
                    context.stroke(
                        arc(center: center, radius: radius, start: 25, end: 155),
                        with: .foreground,
                        style: style
                    )
                    context.fill(
                        arrowhead(center: center, radius: radius, angleDegrees: 335, length: side * 0.20),
                        with: .foreground
                    )
                    context.fill(
                        arrowhead(center: center, radius: radius, angleDegrees: 155, length: side * 0.20),
                        with: .foreground
                    )
                }
                Text("1")
                    .font(.system(size: side * 0.40, weight: .bold, design: .rounded))
                    .offset(y: side * 0.02)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private func arc(center: CGPoint, radius: CGFloat, start: Double, end: Double) -> Path {
        var path = Path()
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(start),
            endAngle: .degrees(end),
            clockwise: false
        )
        return path
    }

    private func arrowhead(
        center: CGPoint,
        radius: CGFloat,
        angleDegrees: Double,
        length: CGFloat
    ) -> Path {
        let angle = angleDegrees * .pi / 180
        let tip = CGPoint(
            x: center.x + radius * Foundation.cos(angle),
            y: center.y + radius * Foundation.sin(angle)
        )
        // Counterclockwise tangent (matches clockwise: false arcs).
        let tx = Foundation.sin(angle)
        let ty = -Foundation.cos(angle)
        let nx = -ty
        let ny = tx
        let base = CGPoint(x: tip.x - tx * length, y: tip.y - ty * length)
        let left = CGPoint(x: base.x + nx * length * 0.52, y: base.y + ny * length * 0.52)
        let right = CGPoint(x: base.x - nx * length * 0.52, y: base.y - ny * length * 0.52)

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
            case .sequential, .loopAll:
                Image(systemName: mode.systemImage)
                    .resizable()
                    .scaledToFit()
            case .loopOne:
                RepeatOneIcon()
            }
        }
        .frame(width: 20, height: 20)
        .frame(width: 28, height: 24)
    }
}
