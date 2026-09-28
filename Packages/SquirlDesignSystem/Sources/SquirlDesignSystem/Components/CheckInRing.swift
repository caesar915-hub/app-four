import SwiftUI

/// The pen's check-in ring (DESIGN.md §8.11): a mint disc, a green-100 track and a gradient
/// arc that reads as a three-step flow indicator — ⅓ idle, ⅔ listening, full when saved.
/// The arc starts at 3 o'clock and sweeps clockwise; the diameter scales with the frame.
public struct CheckInRing: View {
    private let progress: Double
    private let diameter: CGFloat
    private let strokeWidth: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// - Parameters:
    ///   - progress: 0…1 of the arc.
    ///   - diameter: the pen's 347 (idle / listening) or 211 (saved); callers clamp to the width.
    ///     The stroke follows the diameter (`Metrics.CheckIn.ringStrokeRatio`), so the 160 pt
    ///     accessibility ring and the Welcome ring keep the pen's proportion.
    public init(progress: Double, diameter: CGFloat = Metrics.CheckIn.ringDiameter) {
        self.progress = min(1, max(0, progress))
        self.diameter = diameter
        self.strokeWidth = diameter * Metrics.CheckIn.ringStrokeRatio
    }

    public var body: some View {
        ZStack {
            Circle()
                .fill(Surface.ringDisc)
            Circle()
                .strokeBorder(Surface.ringTrack, lineWidth: strokeWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Accent.ringGradient, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .butt))
                .padding(strokeWidth / 2)
                .animation(reduceMotion ? nil : Motion.settle, value: progress)
        }
        .frame(width: diameter, height: diameter)
        .elevation(Elevation.ring)
        .accessibilityHidden(true)
    }
}

#Preview("Ring") {
    VStack(spacing: 24) {
        CheckInRing(progress: 1.0 / 3.0, diameter: 260)
        CheckInRing(progress: 2.0 / 3.0, diameter: 260)
        CheckInRing(progress: 1, diameter: Metrics.CheckIn.ringSavedDiameter)
    }
    .padding()
    .background(Surface.screen)
}
