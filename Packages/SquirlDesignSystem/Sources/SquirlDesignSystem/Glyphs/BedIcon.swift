import SwiftUI

/// Sleep — a single bed icon (does not vary by level; the 1→5 ramp is deferred).
/// Side-profile: headboard + frame, mattress line, pillow. Drawn in a 24×24 space.
public struct BedIcon: View {
    public var color: Color = Palette.sleepIndigo

    public var body: some View {
        Canvas { ctx, size in
            let s = min(size.width, size.height) / 24
            ctx.translateBy(x: (size.width - 24 * s) / 2, y: (size.height - 24 * s) / 2)
            ctx.scaleBy(x: s, y: s)
            let stroke = StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round)

            var frame = Path()
            frame.move(to: CGPoint(x: 3, y: 18))
            frame.addLine(to: CGPoint(x: 3, y: 12))
            frame.addQuadCurve(to: CGPoint(x: 5, y: 10), control: CGPoint(x: 3, y: 10))
            frame.addLine(to: CGPoint(x: 14, y: 10))
            frame.addQuadCurve(to: CGPoint(x: 18, y: 14), control: CGPoint(x: 18, y: 10))
            frame.addLine(to: CGPoint(x: 18, y: 18))
            ctx.stroke(frame, with: .color(color), style: stroke)

            var mattress = Path()
            mattress.move(to: CGPoint(x: 3, y: 14))
            mattress.addLine(to: CGPoint(x: 20, y: 14))
            ctx.stroke(mattress, with: .color(color), style: stroke)

            let pillow = Path(roundedRect: CGRect(x: 6.2, y: 8.4, width: 4.6, height: 1.6), cornerRadius: 0.8)
            ctx.stroke(pillow, with: .color(color), style: StrokeStyle(lineWidth: 1.4, lineJoin: .round))
        }
    }
}

#Preview { BedIcon().frame(width: 32, height: 32).padding() }
