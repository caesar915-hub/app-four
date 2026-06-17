import SwiftUI

/// Energy — a lightning bolt that grows and fills across levels 1…5.
/// Ported from the approved `gEnergy` generator (24×26 design space). Level is encoded by
/// an internal size lift, fill depth and stroke weight, so low and high read apart in grayscale.
struct BoltGlyph: View {
    let level: Int
    let color: Color

    var body: some View {
        Canvas { ctx, size in
            let lift = 0.6 + Double(level) * 0.08
            let s = min(size.width / 24, size.height / 26) * lift
            ctx.translateBy(x: (size.width - 24 * s) / 2, y: (size.height - 26 * s) / 2)
            ctx.scaleBy(x: s, y: s)

            let fill = min(1.0, 0.35 + Double(level) * 0.15)
            let stroke = 0.9 + Double(level) * 0.16

            var bolt = Path()
            bolt.move(to: CGPoint(x: 14, y: 2))
            for p in [CGPoint(x: 6, y: 15), CGPoint(x: 11, y: 15), CGPoint(x: 9.5, y: 24),
                      CGPoint(x: 19, y: 11), CGPoint(x: 13, y: 11)] {
                bolt.addLine(to: p)
            }
            bolt.closeSubpath()

            ctx.fill(bolt, with: .color(color.opacity(fill)))
            ctx.stroke(bolt, with: .color(color),
                       style: StrokeStyle(lineWidth: stroke, lineJoin: .round))
        }
    }
}

#Preview {
    HStack(spacing: 12) {
        ForEach(1...5, id: \.self) { BoltGlyph(level: $0, color: .yellow).frame(width: 28, height: 30) }
    }.padding()
}
