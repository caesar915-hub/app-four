import SwiftUI

// MARK: - Card section eyebrow

public extension Text {
    /// Uppercase, tracked, muted eyebrow used as a card/section header (e.g. "Summary", "Meds", "Audio").
    public func cardEyebrow() -> some View {
        self
            .font(Typography.label)
            .textCase(.uppercase)
            .tracking(0.7)
            .foregroundStyle(NewLook.inkSecondary)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: Spacing.l) {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("Card title").font(Typography.headline)
            Text("Supporting text goes here").font(Typography.caption).foregroundStyle(.secondary)
        }
        .newLookCard()

        HStack {
            Label("Compact row", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
            Spacer()
        }
        .newLookCard(padding: Spacing.m)
    }
    .padding(Spacing.l)
}
