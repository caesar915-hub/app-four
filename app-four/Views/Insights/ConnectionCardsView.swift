import SwiftUI

/// Three insight cards: medication×focus, energy×mood, sleep×mood.
/// Unlocked cards show a serif sentence + mini bar. Gated cards show a
/// dashed border with explicit unlock copy — never ambiguous "not enough data".
struct ConnectionCardsView: View {
    let connections: [Connection]

    var body: some View {
        VStack(spacing: Spacing.m) {
            ForEach(Array(connections.enumerated()), id: \.offset) { _, connection in
                ConnectionCard(connection: connection)
            }
        }
        .padding(.horizontal, Spacing.l)
        .accessibilityElement(children: .contain)
    }
}

private struct ConnectionCard: View {
    let connection: Connection

    var body: some View {
        switch connection.state {
        case let .gated(unlockCopy):
            GatedCard(title: connection.title, unlockCopy: unlockCopy)
        case let .unlocked(sentence, fraction, barLabel, leadingText, trailingText):
            UnlockedCard(
                title: connection.title,
                sentence: sentence,
                fraction: fraction,
                barLabel: barLabel,
                leadingText: leadingText,
                trailingText: trailingText
            )
        }
    }
}

private struct UnlockedCard: View {
    let title: String
    let sentence: String
    let fraction: Double
    let barLabel: String
    let leadingText: String
    let trailingText: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text(title)
                .font(Typography.label)
                .foregroundStyle(NewLook.inkSecondary)
                .textCase(.uppercase)
                .tracking(0.5)

            Text(sentence)
                .font(Typography.display)
                .foregroundStyle(NewLook.inkPrimary)
                .fixedSize(horizontal: false, vertical: true)

            MiniBar(
                fraction: fraction,
                barLabel: barLabel,
                leadingText: leadingText,
                trailingText: trailingText
            )
        }
        .newLookCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(sentence) \(barLabel)")
    }
}

private struct GatedCard: View {
    let title: String
    let unlockCopy: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack {
                Text(title)
                    .font(Typography.label)
                    .foregroundStyle(NewLook.inkSecondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Spacer()
                Image(systemName: "lock")
                    .font(Typography.caption)
                    .foregroundStyle(NewLook.inkSecondary)
            }
            Text(unlockCopy)
                .font(Typography.callout)
                .foregroundStyle(NewLook.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.l)
        .background(NewLook.card, in: .rect(cornerRadius: Radius.newLookCard))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.newLookCard)
                .strokeBorder(
                    NewLook.hairline,
                    style: StrokeStyle(lineWidth: 1, dash: [5, 3])
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): locked. \(unlockCopy)")
    }
}

private struct MiniBar: View {
    let fraction: Double
    let barLabel: String
    let leadingText: String
    let trailingText: String

    private let barHeight: CGFloat = 8

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(NewLook.tintNeutral)
                    Capsule()
                        .fill(Palette.medication)
                        .frame(width: max(barHeight, geo.size.width * fraction))
                }
                .frame(height: barHeight)
            }
            .frame(height: barHeight)

            HStack {
                Text(leadingText)
                    .font(Typography.caption)
                    .foregroundStyle(NewLook.inkSecondary)
                Spacer()
                Text(barLabel)
                    .font(Typography.label)
                    .fontWeight(.semibold)
                    .foregroundStyle(NewLook.inkPrimary)
                Spacer()
                Text(trailingText)
                    .font(Typography.caption)
                    .foregroundStyle(NewLook.inkSecondary)
            }
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
                    fraction: 0.75,
                    barLabel: "75%",
                    leadingText: "Med days",
                    trailingText: "Sharp+ focus"
                )
            ),
            Connection(title: "Energy × mood",
                       state: .gated(unlockCopy: "Log high energy on 2 more days to unlock this connection.")),
            Connection(title: "Sleep × mood",
                       state: .gated(unlockCopy: "Note 1 more good-sleep day and 3 more poor-sleep days to unlock this connection.")),
        ])
        .padding()
    }
}
