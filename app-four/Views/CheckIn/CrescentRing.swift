import SwiftUI

/// The New Look check-in ring (a04/a05, spec 036): a full circle in a solid `Theme.meadowGreen`,
/// matching the selected Check-in tab. At rest it **breathes** (idle); while recording it rotates
/// (active) — a uniform stroke, so the spin reads as a hold rather than a visible sweep. Decorative.
struct CrescentRing: View {
    var isActive: Bool = false
    var lineWidth: CGFloat = 22

    var body: some View {
        AnimatedArc(isActive: isActive, lineWidth: lineWidth)
            .id(isActive)
            .accessibilityHidden(true)
    }
}

/// Child view that owns animation state. `.id(isActive)` on the parent forces
/// SwiftUI to destroy and recreate this view on every isActive flip, resetting
/// `animating` to false and re-triggering onAppear with the correct animation.
private struct AnimatedArc: View {
    let isActive: Bool
    let lineWidth: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animating = false

    var body: some View {
        let arc = Circle()
            .stroke(
                Theme.meadowGreen,
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt)
            )
            .padding(lineWidth / 2)

        if isActive {
            arc
                .rotationEffect(.degrees(animating ? 360 : 0))
                .animation(reduceMotion ? nil : .linear(duration: 7).repeatForever(autoreverses: false),
                           value: animating)
                .onAppear { animating = true }
        } else {
            arc
                .scaleEffect(animating ? 1.035 : 1.0)
                .opacity(animating ? 1.0 : 0.94)
                .animation(reduceMotion ? nil : .easeInOut(duration: 5).repeatForever(autoreverses: true),
                           value: animating)
                .onAppear { animating = true }
        }
    }
}

#Preview {
    VStack(spacing: Spacing.hero) {
        CrescentRing().frame(width: 300, height: 300)
        CrescentRing(isActive: true).frame(width: 200, height: 200)
    }
}
