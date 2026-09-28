import SwiftUI

/// The pen's medication badge: a violet-50 disc with a hairline and the diagonal capsule inside
/// (medication bar rows, day-details medication row, the Settings confirmation preview).
public struct MedicationBadge: View {
    private let size: CGFloat
    private let onTint: Bool

    /// - Parameter onTint: `true` when the badge sits on a violet-50 surface, so the disc turns white.
    public init(size: CGFloat = Metrics.medicationBadge, onTint: Bool = false) {
        self.size = size
        self.onTint = onTint
    }

    public var body: some View {
        ZStack {
            Circle().fill(onTint ? Surface.card : Surface.medicationTint)
            Circle().strokeBorder(Stroke.card, lineWidth: 0.5)
            CapsuleGlyph()
                .frame(width: size * 0.5, height: size * 0.5)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// A capsule-shaped progress track with the violet gradient fill — the medication bar
/// (10 pt) and the connection bar (6 pt). The fill never shrinks below its own height.
public struct ProgressTrack: View {
    private let fraction: Double
    private let height: CGFloat

    public init(fraction: Double, height: CGFloat = 10) {
        self.fraction = min(1, max(0, fraction))
        self.height = height
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Surface.track)
                Capsule().strokeBorder(Stroke.card, lineWidth: 0.25)
                Capsule()
                    .fill(Accent.medicationBarGradient)
                    .frame(width: max(height, geo.size.width * fraction))
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

/// The 86 × 4 signal bar on the day-details signal summary — filled `level / 5` in the signal's colour.
public struct SignalMiniBar: View {
    private let fraction: Double
    private let color: Color

    public init(level: Int, color: Color) {
        self.fraction = Double(min(5, max(0, level))) / 5
        self.color = color
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Surface.miniTrack)
                Capsule().fill(color).frame(width: max(4, geo.size.width * fraction))
            }
        }
        .frame(height: 4)
        .accessibilityHidden(true)
    }
}

/// The small two-tone pill illustration on collapsed day cards ("Concerta 36mg").
public struct MedicationPill: View {
    private let size: CGFloat

    public init(size: CGFloat = 12) {
        self.size = size
    }

    public var body: some View {
        Canvas { ctx, canvasSize in
            let w = canvasSize.width, h = canvasSize.height * 0.5
            let rect = CGRect(x: 0, y: (canvasSize.height - h) / 2, width: w, height: h)
            let pill = Path(roundedRect: rect, cornerRadius: h / 2)
            ctx.translateBy(x: w / 2, y: canvasSize.height / 2)
            ctx.rotate(by: .degrees(-35))
            ctx.translateBy(x: -w / 2, y: -canvasSize.height / 2)
            ctx.fill(pill, with: .color(Color(hex: "#f0cf9e")))
            ctx.drawLayer { layer in
                layer.clip(to: Path(CGRect(x: 0, y: 0, width: w / 2, height: canvasSize.height)))
                layer.fill(pill, with: .color(Color(hex: "#ff9522")))
            }
            ctx.stroke(pill, with: .color(Color(hex: "#dd7917")), lineWidth: 0.8)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
