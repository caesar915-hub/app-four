import SwiftUI

/// Focus — an aperture: a scattered dashed ring at low levels tightening to concentric
/// rings + a sharp center at high. Ported from the approved `gFocus` generator
/// (24×26 design space, centred 12,13). Level is encoded by ring count, dashing and the
/// solid core — a shape ladder, never opacity alone.
struct ApertureGlyph: View {
    let level: Int
    let color: Color

    var body: some View {
        Canvas { ctx, size in
            let s = min(size.width / 24, size.height / 26)
            ctx.translateBy(x: (size.width - 24 * s) / 2, y: (size.height - 26 * s) / 2)
            ctx.scaleBy(x: s, y: s)

            let c = CGPoint(x: 12, y: 13)
            func ring(_ r: Double) -> Path {
                Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
            }

            // Outer ring — dashed (scattered) at low levels.
            let outerStyle = StrokeStyle(lineWidth: 1.2, dash: level <= 2 ? [3, 3] : [])
            ctx.stroke(ring(9), with: .color(color.opacity(0.3 + Double(level) * 0.12)), style: outerStyle)

            if level >= 2 {
                ctx.stroke(ring(6), with: .color(color.opacity(0.4 + Double(level) * 0.11)), lineWidth: 1.3)
            }
            if level >= 4 {
                ctx.stroke(ring(3.3), with: .color(color.opacity(0.92)), lineWidth: 1.4)
            }
            if level >= 3 {
                let r = Double(level - 1) * 0.85
                ctx.fill(ring(r), with: .color(color.opacity(0.5 + Double(level) * 0.1)))
            }
        }
    }
}

#Preview {
    HStack(spacing: 12) {
        ForEach(1...5, id: \.self) { ApertureGlyph(level: $0, color: .blue).frame(width: 28, height: 30) }
    }.padding()
}
