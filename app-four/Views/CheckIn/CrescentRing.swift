import SwiftUI

/// The Paper & Pollen check-in ring: a full circle, green-dominant with amber at the bottom.
/// At rest it **breathes** (idle); while recording it **spins** (active). Decorative.
struct CrescentRing: View {
    var isActive: Bool = false
    var lineWidth: CGFloat = 22

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var spinning = false
    @State private var breathing = false

    private var arc: some View {
        Circle()
            .trim(from: 0, to: 1.0)
            .stroke(
                AngularGradient(
                    gradient: Gradient(stops: [
                        .init(color: Theme.meadowGreen, location: 0.00),
                        .init(color: Theme.meadowAmber, location: 0.50),
                        .init(color: Theme.meadowGreen, location: 1.00),
                    ]),
                    center: .center,
                    startAngle: .degrees(270),
                    endAngle: .degrees(270 + 360)
                ),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt)
            )
            .padding(lineWidth / 2)
    }

    var body: some View {
        Group {
            if isActive {
                arc
                    .rotationEffect(.degrees(spinning ? 360 : 0))
                    .animation(reduceMotion ? nil : .linear(duration: 7).repeatForever(autoreverses: false),
                               value: spinning)
                    .onAppear { spinning = true }
            } else {
                arc
                    .scaleEffect(breathing ? 1.035 : 1.0)
                    .opacity(breathing ? 1.0 : 0.94)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 5).repeatForever(autoreverses: true),
                               value: breathing)
                    .onAppear { breathing = true }
            }
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
