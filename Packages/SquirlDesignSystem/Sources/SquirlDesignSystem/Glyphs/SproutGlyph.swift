import SwiftUI

/// Mood — the pen's two-leaf sprout. The pen encodes level by colour only; the crown also grows
/// 84 % → 100 % from level 1 to 5 (D3.3), so low and high still read apart in greyscale.
public struct SproutGlyph: View {
    public let level: Int

    public init(level: Int) {
        self.level = level
    }

    public var body: some View {
        Canvas { ctx, size in
            ctx.enterGlyphSpace(size)
            let clamped = min(5, max(1, level))
            let palette = SproutPalette.colors(for: clamped)
            let scale = 0.84 + 0.04 * CGFloat(clamped - 1)
            let anchor = GlyphArt.Sprout.base
            ctx.translateBy(x: anchor.x, y: anchor.y)
            ctx.scaleBy(x: scale, y: scale)
            ctx.translateBy(x: -anchor.x, y: -anchor.y)

            ctx.stroke(GlyphArt.Sprout.stem, with: .color(palette.leafB),
                       style: StrokeStyle(lineWidth: GlyphArt.Sprout.stemWidth, lineCap: .round))
            ctx.fill(GlyphArt.Sprout.leafA, with: .color(palette.leafA))
            ctx.fill(GlyphArt.Sprout.leafB, with: .color(palette.leafB))
            ctx.stroke(GlyphArt.Sprout.veinA, with: .color(palette.leafB),
                       style: StrokeStyle(lineWidth: GlyphArt.Sprout.veinWidth, lineCap: .round))
            ctx.stroke(GlyphArt.Sprout.veinB, with: .color(palette.vein),
                       style: StrokeStyle(lineWidth: GlyphArt.Sprout.veinWidth, lineCap: .round))
        }
    }
}

#Preview {
    HStack(spacing: 12) {
        ForEach(1...5, id: \.self) { SproutGlyph(level: $0).frame(width: 34, height: 34) }
    }.padding()
}
