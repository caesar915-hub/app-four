import SwiftUI

// MARK: - Modifier

/// Single placement for the medication bar — pinned at the top of the four tab roots via
/// `safeAreaInset(edge: .top)` (D25), inside the pen's gutter. Zero space is reserved when the
/// bar is hidden in Settings or has nothing to show.
private struct MedicationBarOverlayModifier: ViewModifier {
    var showsMedicationBar: Bool

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .top, spacing: 0) {
                if showsMedicationBar {
                    MedicationBarView()
                        .padding(.horizontal, Spacing.gutter)
                        .padding(.top, Spacing.s)
                }
            }
    }
}

// MARK: - Extension

extension View {
    /// Pins the medication bar at the top of this view, using the single shared placement.
    func medicationBarOverlay(shown: Bool = true) -> some View {
        modifier(MedicationBarOverlayModifier(showsMedicationBar: shown))
    }
}
