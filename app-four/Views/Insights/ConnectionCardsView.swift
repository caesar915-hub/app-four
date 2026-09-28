import SwiftUI

/// The three connection cards (medication × focus, energy × mood, sleep × mood) in the
/// view-model's test-pinned order.
struct ConnectionCardsView: View {
    let connections: [Connection]

    var body: some View {
        VStack(spacing: Spacing.m) {
            ForEach(Array(connections.enumerated()), id: \.offset) { _, connection in
                ConnectionCard(connection: connection)
            }
        }
        .accessibilityElement(children: .contain)
    }
}

/// A connection card (DESIGN.md §8.17): `.medium` card, 42 pt icon tile (violet-50 + lock while
/// gated, lavender + open lock once unlocked), uppercase 12/600 violet title, 12/500 body; the
/// unlocked state adds the gradient bar and its percentage. The gating copy always says exactly
/// what is missing — never "not enough data".
struct ConnectionCard: View {
    let connection: Connection

    private var isUnlocked: Bool {
        if case .unlocked = connection.state { return true }
        return false
    }

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.m) {
            iconTile
            VStack(alignment: .leading, spacing: Spacing.s) {
                Text(connection.title)
                    .font(Typography.status)
                    .foregroundStyle(Accent.violetText)
                    .textCase(.uppercase)
                switch connection.state {
                case let .gated(unlockCopy):
                    Text(unlockCopy)
                        .font(Typography.captionMedium)
                        .foregroundStyle(Ink.primary)
                        .fixedSize(horizontal: false, vertical: true)
                case let .unlocked(sentence, fraction, barLabel, _, _):
                    Text(sentence)
                        .font(Typography.captionMedium)
                        .foregroundStyle(Ink.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: Spacing.s) {
                        ProgressTrack(fraction: fraction, height: 6)
                        Text(barLabel)
                            .font(Typography.status)
                            .foregroundStyle(Ink.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(.medium)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var iconTile: some View {
        RoundedRectangle(cornerRadius: Radius.iconTile)
            .fill(isUnlocked ? Surface.connectionUnlocked : Surface.medicationTint)
            .overlay {
                RoundedRectangle(cornerRadius: Radius.iconTile)
                    .strokeBorder(Stroke.card, lineWidth: 0.45)
            }
            .overlay {
                Image(systemName: isUnlocked ? Icons.unlock : Icons.lock)
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(isUnlocked ? Accent.violetDeep : Accent.connection)
            }
            .frame(width: 42, height: 42)
            .accessibilityHidden(true)
    }

    private var accessibilityLabel: String {
        switch connection.state {
        case let .gated(unlockCopy): "\(connection.title): locked. \(unlockCopy)"
        case let .unlocked(sentence, _, barLabel, _, _): "\(connection.title): \(sentence) \(barLabel)"
        }
    }
}

#Preview {
    ScrollView {
        ConnectionCardsView(connections: [
            Connection(
                title: "Medication × focus",
                state: .unlocked(
                    sentence: "On medication days, sharp focus appeared 75% of the time.",
                    fraction: 0.75, barLabel: "75%", leadingText: "Med days", trailingText: "Sharp+ focus"
                )
            ),
            Connection(title: "Energy × mood",
                       state: .gated(unlockCopy: "Log high energy on 2 more days to unlock this connection.")),
            Connection(title: "Sleep × mood",
                       state: .gated(unlockCopy: "Note 1 more good-sleep day and 3 more poor-sleep days to unlock this connection.")),
        ])
        .padding(Spacing.gutter)
    }
}
