import SwiftUI

// MARK: - The one card modifier

extension View {
    /// Applies the standard native card treatment: secondary background + 12pt corner radius.
    /// This is the single card pattern for the entire app.
    ///
    /// Usage:
    /// ```swift
    /// VStack { ... }
    ///     .card()
    ///
    /// // Tighter padding for dense rows:
    /// HStack { ... }
    ///     .card(padding: Spacing.m)
    /// ```
    func card(padding: CGFloat = Spacing.l, elevated: Bool = false) -> some View {
        let base = self
            .padding(padding)
            .background(Theme.cardBackground, in: .rect(cornerRadius: Radius.card))
        return Group {
            if elevated {
                base.elevated()
            } else {
                base
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: Spacing.l) {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("Card title").font(Typography.headline)
            Text("Supporting text goes here").font(Typography.caption).foregroundStyle(.secondary)
        }
        .card()

        HStack {
            Label("Compact row", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
            Spacer()
        }
        .card(padding: Spacing.m)
    }
    .padding(Spacing.l)
}
