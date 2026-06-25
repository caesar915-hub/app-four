import SwiftUI

/// Mood — a sprout whose crown grows bud → bloom across levels 1…5.
/// Ported from the approved `gMood` generator (24×26 design space). Level is encoded by
/// crown shape (bud vs open), an internal size lift, fill depth, a stem notch (≥3) and a
/// crown dot (5) — so it survives grayscale, not on hue alone.
public struct SproutGlyph: View {
    public let level: Int
    public let color: Color

    public var body: some View {
        Canvas { ctx, size in
            let lift = 0.66 + Double(level) * 0.068
            let s = min(size.width / 24, size.height / 26) * lift
            ctx.translateBy(x: (size.width - 24 * s) / 2, y: (size.height - 26 * s) / 2)
            ctx.scaleBy(x: s, y: s)

            let open = level >= 4
            let top = open ? 9.0 : 11.0
            let fill = min(1.0, 0.42 + Double(level) * 0.145)

            var stem = Path()
            stem.move(to: CGPoint(x: 12, y: 25))
            stem.addCurve(to: CGPoint(x: 12, y: top),
                          control1: CGPoint(x: 12, y: 18), control2: CGPoint(x: 12, y: 14))
            ctx.stroke(stem, with: .color(color.opacity(0.6)), lineWidth: 1.5)

            var crown = Path()
            crown.move(to: CGPoint(x: 12, y: top))
            crown.addCurve(to: CGPoint(x: 12, y: 1),
                           control1: CGPoint(x: open ? 4 : 6, y: open ? 13 : 14),
                           control2: CGPoint(x: open ? 5 : 6, y: open ? 2 : 5))
            crown.addCurve(to: CGPoint(x: 12, y: top),
                           control1: CGPoint(x: open ? 19 : 18, y: open ? 2 : 5),
                           control2: CGPoint(x: open ? 20 : 18, y: open ? 13 : 14))
            crown.closeSubpath()
            ctx.fill(crown, with: .color(color.opacity(fill)))
            ctx.stroke(crown, with: .color(color), lineWidth: 1.3)

            if level >= 3 {
                var notch = Path()
                notch.move(to: CGPoint(x: 12, y: top))
                notch.addLine(to: CGPoint(x: 12, y: 4))
                ctx.stroke(notch, with: .color(color.opacity(0.5)), lineWidth: 1)
            }
            if level >= 5 {
                ctx.fill(Path(ellipseIn: CGRect(x: 10, y: 4, width: 4, height: 4)), with: .color(color))
            }
        }
    }
}

#Preview {
    HStack(spacing: 12) {
        ForEach(1...5, id: \.self) { SproutGlyph(level: $0, color: .green).frame(width: 28, height: 30) }
    }.padding()
}
