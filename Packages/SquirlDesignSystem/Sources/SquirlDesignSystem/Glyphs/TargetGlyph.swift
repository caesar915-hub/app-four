import SwiftUI

/// Focus — the pen's target: a pale ring whose blue arc sweeps further with each level
/// (72° → 180° → 216° → full with caps → full), an inner disc, and an amber arrow.
public struct TargetGlyph: View {
    public let level: Int

    public init(level: Int) {
        self.level = level
    }

    public var body: some View {
        Canvas { ctx, size in
            ctx.enterGlyphSpace(size)
            let clamped = min(5, max(1, level))
            let art = GlyphArt.Target.self
            let c = art.center

            ctx.fill(annulus(center: c, outer: art.ringOuter, inner: art.ringInner), with: .color(Accent.focusRing))

            let sweep = art.sweeps[clamped - 1]
            let radius = (art.ringOuter + art.ringInner) / 2
            var arc = Path()
            arc.addArc(center: c, radius: radius, startAngle: .degrees(-90), endAngle: .degrees(-90 + sweep), clockwise: false)
            ctx.stroke(arc, with: .color(Accent.focusBlue),
                       style: StrokeStyle(lineWidth: art.ringOuter - art.ringInner, lineCap: clamped == 5 ? .butt : .round))

            ctx.fill(annulus(center: c, outer: art.discOuter, inner: art.discInner), with: .color(Accent.focusDisc))

            ctx.fill(art.shaft, with: .color(Accent.energyAmber))
            ctx.fill(art.head, with: .color(Accent.energyAmber))
            ctx.fill(Path(ellipseIn: art.centerDot), with: .color(Accent.energyAmber))
            ctx.fill(Path(ellipseIn: art.tipDot), with: .color(Accent.energyAmber))
        }
    }

    private func annulus(center: CGPoint, outer: CGFloat, inner: CGFloat) -> Path {
        var path = Path()
        path.addEllipse(in: CGRect(x: center.x - outer, y: center.y - outer, width: 2 * outer, height: 2 * outer))
        path.addEllipse(in: CGRect(x: center.x - inner, y: center.y - inner, width: 2 * inner, height: 2 * inner))
        return path.normalized(eoFill: true)
    }
}

#Preview {
    HStack(spacing: 12) {
        ForEach(1...5, id: \.self) { TargetGlyph(level: $0).frame(width: 34, height: 34) }
    }.padding()
}
