import SwiftUI

/// The How-We-Feel-style check-in ring: a soft, rounded ~295° arc that rotates
/// slowly at rest and faster while recording. Purely decorative.
struct CrescentRing: View {
    var isActive: Bool = false
    var lineWidth: CGFloat = 22

    @State private var spinning = false

    private var revolutionSeconds: Double { isActive ? 7 : 16 }

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.82)
            .stroke(.quaternary, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .padding(lineWidth / 2)
            .rotationEffect(.degrees(spinning ? 360 : 0))
            .animation(
                AccessibilityHelpers.isReduceMotionEnabled
                    ? nil
                    : .linear(duration: revolutionSeconds).repeatForever(autoreverses: false),
                value: spinning
            )
            .onAppear { spinning = true }
            .onChange(of: isActive) {
                // Restart so the new speed takes effect; the phase snap is masked
                // by the hub <-> recording crossfade.
                spinning = false
                Task { @MainActor in spinning = true }
            }
            .accessibilityHidden(true)
    }
}

#Preview {
    VStack(spacing: Spacing.hero) {
        CrescentRing().frame(width: 300, height: 300)
        CrescentRing(isActive: true).frame(width: 200, height: 200)
    }
}
