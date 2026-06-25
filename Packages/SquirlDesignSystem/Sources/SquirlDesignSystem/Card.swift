import SwiftUI

// MARK: - The one card modifier

public extension View {
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
    public func card(padding: CGFloat = Spacing.l) -> some View {
        self
            .padding(padding)
            .background(Theme.cardBackground, in: .rect(cornerRadius: Radius.card))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.card)
                    .strokeBorder(Theme.cardStroke, lineWidth: 1)
            )
            .shadow(color: Color(lightHex: "#221E16", darkHex: "#000000").opacity(0.06), radius: 10, y: 3)
    }
}

// MARK: - Card section eyebrow

public extension Text {
    /// Uppercase, tracked, muted eyebrow used as a card/section header (e.g. "Summary", "Meds", "Audio").
    public func cardEyebrow() -> some View {
        self
            .font(Typography.label)
            .textCase(.uppercase)
            .tracking(0.7)
            .foregroundStyle(Theme.textSecondary)
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
