import SwiftUI

/// A card grouping all of a single day's check-ins as a mood/medication timeline.
/// The card is an elevated surface washed with the day's *average* mood colour
/// (Daylio-style), so it reads as a tinted card in both light and dark mode. The
/// header takes the average's deeper shade on light, brighter shade on dark.
struct DayCard: View {
    let day: MoodLibraryViewModel.TimelineDay
    let onTapRecording: (UUID) -> Void

    @Environment(\.colorScheme) private var colorScheme

    private let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(day.label)
                .font(.system(size: 14, weight: .heavy))   // fixed (no Dynamic Type scaling)
                .textCase(.uppercase)
                .foregroundStyle(headerColor)
                .padding(.bottom, Spacing.m)
                .accessibilityAddTraits(.isHeader)

            if day.nodes.isEmpty {
                Text("No check-ins")
                    .font(Typography.callout)
                    .foregroundStyle(Theme.textSecondary)
            } else {
                ForEach(Array(day.nodes.enumerated()), id: \.element.id) { index, node in
                    TimelineRow(
                        node: node,
                        isLast: index == day.nodes.count - 1,
                        onTapRecording: onTapRecording
                    )
                }
            }
        }
        .padding(Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                shape.fill(Theme.cardBackground)
                if let tint = MoodLevel.averageFill(of: moods) {
                    shape.fill(tint.opacity(0.16))   // mood wash layered over the surface
                }
            }
        }
    }

    private var moods: [String?] {
        day.nodes.compactMap(\.recording).map(\.mood)
    }

    /// Deeper average-mood shade on light; the brighter pastel on dark (the deep
    /// shade is too dark to read on a dark card). Neutral when no moods.
    private var headerColor: Color {
        let avg = colorScheme == .dark
            ? MoodLevel.averageFill(of: moods)
            : MoodLevel.averageDeep(of: moods)
        return avg ?? Theme.textSecondary
    }
}

#Preview("Empty day") {
    DayCard(
        day: .init(date: .now, label: "TUESDAY, 10 JUN", nodes: []),
        onTapRecording: { _ in }
    )
    .padding()
}
