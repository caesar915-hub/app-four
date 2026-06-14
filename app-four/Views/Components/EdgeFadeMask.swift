import SwiftUI

/// Fades scrollable content into transparency at the top (so it dissolves under a
/// floating medication bar) and at the bottom (so it dissolves into the tab bar),
/// leaving the middle fully visible and interactive.
///
/// Applied to a `ScrollView`; the floating bar is a sibling layer, so it stays opaque.
struct EdgeFadeMask: ViewModifier {
    var topFade: CGFloat
    var bottomFade: CGFloat

    func body(content: Content) -> some View {
        content.mask {
            VStack(spacing: 0) {
                LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                    .frame(height: topFade)
                Color.black
                LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: bottomFade)
            }
            .ignoresSafeArea()
        }
    }
}

extension View {
    /// Dissolves scroll content at the top and bottom edges. Pass the measured
    /// floating-bar height for `top` so the fade tracks the bar across Dynamic Type.
    func edgeFadeMask(top: CGFloat, bottom: CGFloat = 36) -> some View {
        modifier(EdgeFadeMask(topFade: top, bottomFade: bottom))
    }
}
