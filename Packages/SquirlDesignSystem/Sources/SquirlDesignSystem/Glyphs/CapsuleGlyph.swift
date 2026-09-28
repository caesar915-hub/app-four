import SwiftUI

/// Medication — the pen's diagonal line-style capsule (one half filled, one hollow), violet-800
/// inside its violet-50 tile. Does not vary by level.
public struct CapsuleGlyph: View {
    public var color: Color = Accent.violetDeep

    public init(color: Color = Accent.violetDeep) {
        self.color = color
    }

    public var body: some View {
        Canvas { ctx, size in
            ctx.enterGlyphSpace(size)
            let c = CGPoint(x: 32, y: 32)
            ctx.translateBy(x: c.x, y: c.y)
            ctx.rotate(by: .degrees(-45))
            ctx.translateBy(x: -c.x, y: -c.y)

            let body = CGRect(x: 10, y: 22, width: 44, height: 20)
            let capsule = Path(roundedRect: body, cornerRadius: 10)
            let stroke: CGFloat = 4
            ctx.drawLayer { layer in
                layer.clip(to: Path(CGRect(x: body.minX, y: body.minY, width: body.width / 2, height: body.height)))
                layer.fill(capsule, with: .color(color))
            }
            ctx.stroke(capsule, with: .color(color), lineWidth: stroke)
            var seam = Path()
            seam.move(to: CGPoint(x: body.midX, y: body.minY))
            seam.addLine(to: CGPoint(x: body.midX, y: body.maxY))
            ctx.stroke(seam, with: .color(color), lineWidth: stroke)
        }
    }
}

#Preview { CapsuleGlyph().frame(width: 40, height: 40).padding() }
