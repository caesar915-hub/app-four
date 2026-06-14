import SwiftUI

/// One canonical shadow recipe so nobody hand-rolls per-card shadows.
/// Subtle by default — the app is mostly flat/native; use only where depth helps.
extension View {
    func elevated() -> some View {
        self.shadow(color: Color(.label).opacity(0.08), radius: 8, y: 2)
    }
}
