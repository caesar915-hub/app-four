import SwiftUI

/// A folding card for a single day's check-ins. Folded, it shows only the constant header
/// (`FoldedDayCardHeader`: mood circle + weekday + one-line summary). Tapping the header
/// toggles expansion (FR-005): the summary collapses and the day's check-ins are revealed as
/// a time-ordered timeline. The card is washed with the day's *average* mood colour so it
/// reads as a tinted surface in both light and dark mode. Selection carries no border — the
/// selected day is conveyed by top-position + expansion only (FR-012).
struct DayCard: View {
    let day: MoodLibraryViewModel.TimelineDay
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    let onTapRecording: (UUID) -> Void

    private let shape = RoundedRectangle(cornerRadius: Radius.card, style: .continuous)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggleExpand) {
                FoldedDayCardHeader(day: day, isExpanded: isExpanded)
            }
            .buttonStyle(.plain)

            if isExpanded && !day.nodes.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(day.nodes.enumerated()), id: \.element.id) { index, node in
                        TimelineRow(
                            node: node,
                            isLast: index == day.nodes.count - 1,
                            onTapRecording: onTapRecording
                        )
                    }
                }
                .padding(.top, Spacing.m)
            }
        }
        .padding(Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                shape.fill(Theme.cardBackground)
                if let tint = MoodLevel.averageFill(of: moods) {
                    shape.fill(tint.opacity(Opacity.moodWash))   // mood wash layered over the surface
                }
            }
        }
    }

    private var moods: [String?] {
        day.nodes.compactMap(\.recording).map(\.mood)
    }
}

#Preview("Folded / expanded") {
    VStack(spacing: Spacing.m) {
        DayCard(
            day: .init(date: .now, label: "Tuesday, 10 Jun", nodes: []),
            isExpanded: false,
            onToggleExpand: {},
            onTapRecording: { _ in }
        )
    }
    .padding()
}
