import SwiftUI

/// A folding card for a single day's check-ins (Paper & Pollen "#4 Divided · Cream disc", spec 019).
/// The card surface is cream; the day's *representative* mood tint lives on the header
/// (`FoldedDayCardHeader`), so folded the whole card reads as one mood-tinted block and expanded the
/// tint becomes a strip with the check-in rows dropping onto the cream surface below. Tapping the
/// header toggles expansion. Selection carries no border — top-position + expansion convey it (FR-012).
struct DayCard: View {
    let day: MoodLibraryViewModel.TimelineDay
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    let onTapRecording: (UUID) -> Void

    private let shape = RoundedRectangle(cornerRadius: Radius.newLookCard, style: .continuous)

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
                .padding(.horizontal, Spacing.l)
                .padding(.top, Spacing.m)
                .padding(.bottom, Spacing.l)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NewLook.card)
        .clipShape(shape)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        .shadow(color: .black.opacity(0.03), radius: 2, x: 0, y: 1)
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
