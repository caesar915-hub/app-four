import SwiftUI

/// Energy — the pen's bolt: a pale base with the amber fill rising 30 % → 100 % by level
/// (the rising fill is a clip mask — D3.1; the export's black block was the mask itself).
public struct BoltGlyph: View {
    public let level: Int

    public init(level: Int) {
        self.level = level
    }

    public var body: some View {
        Canvas { ctx, size in
            ctx.enterGlyphSpace(size)
            let clamped = min(5, max(1, level))
            ctx.fill(GlyphArt.Bolt.outline, with: .color(Accent.energyPale))
            ctx.drawLayer { layer in
                layer.clip(to: layer.risingMask(height: GlyphArt.Bolt.fillHeights[clamped - 1]))
                layer.fill(GlyphArt.Bolt.outline, with: .color(Accent.energyDark))
                layer.fill(GlyphArt.Bolt.facet, with: .color(Accent.energyAmber))
            }
        }
    }
}

#Preview {
    HStack(spacing: 12) {
        ForEach(1...5, id: \.self) { BoltGlyph(level: $0).frame(width: 34, height: 34) }
    }.padding()
}
