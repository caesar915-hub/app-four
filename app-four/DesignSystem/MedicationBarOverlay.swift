import SwiftUI

// MARK: - Modifier

/// Single placement for the medication bar — used by every screen.
///
/// Behaviour:
/// - Pins `MedicationBarView` at the top via `safeAreaInset(edge: .top)`,
///   so the bar floats below the navigation bar.
/// - The bar is a floating Liquid Glass capsule (`.glassEffect`), matching the
///   system tab bar's appearance — with side margins and a small top gap.
/// - When the medication bar is hidden in Settings, zero space is reserved.
private struct MedicationBarOverlayModifier: ViewModifier {
    var showsMedicationBar: Bool

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .top, spacing: 0) {
                if showsMedicationBar {
                    MedicationBarView()
                        .padding(.horizontal, Spacing.l)
                        .padding(.top, Spacing.s)
                }
            }
    }
}

// MARK: - Extension

extension View {
    /// Pins the medication bar at the top of this view (just below the nav bar),
    /// using a single shared placement with no translucent material.
    func medicationBarOverlay(shown: Bool = true) -> some View {
        modifier(MedicationBarOverlayModifier(showsMedicationBar: shown))
    }
}
