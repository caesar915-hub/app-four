import SwiftUI

/// Sleep — the pen's crescent moon + star: the violet moon fill and the amber star fill both
/// rise with the level (rising-fill masks, as the bolt). Replaces the single bed icon.
public struct MoonGlyph: View {
    public let level: Int

    public init(level: Int) {
        self.level = level
    }

    public var body: some View {
        Canvas { ctx, size in
            ctx.enterGlyphSpace(size)
            let clamped = min(5, max(1, level))
            let art = GlyphArt.Moon.self

            ctx.fill(art.moon, with: .color(Accent.sleepMoonBase))
            ctx.drawLayer { layer in
                layer.clip(to: layer.risingMask(height: art.moonFillHeights[clamped - 1]))
                layer.fill(art.moon, with: .color(Accent.violet))
                layer.fill(art.highlight, with: .color(Accent.sleepMoonHighlight))
            }
            ctx.fill(art.star, with: .color(Accent.energyPale))
            ctx.drawLayer { layer in
                layer.clip(to: layer.risingMask(height: art.starFillHeights[clamped - 1]))
                layer.fill(art.star, with: .color(Accent.energyAmber))
            }
        }
    }
}

#Preview {
    HStack(spacing: 12) {
        ForEach(1...5, id: \.self) { MoonGlyph(level: $0).frame(width: 34, height: 34) }
    }.padding()
}
