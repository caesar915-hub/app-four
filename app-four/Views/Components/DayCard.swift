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

    private let shape = RoundedRectangle(cornerRadius: Radius.card, style: .continuous)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggleExpand) {
                FoldedDayCardHeader(day: day, isExpanded: isExpanded)
            }
            .buttonStyle(.plain)

            if isExpanded && (!day.nodes.isEmpty || day.nutrition != nil) {
                expandedBody
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardBackground)
        .clipShape(shape)
    }

    /// Check-ins and nutrition events on one rail (spec 031 US2), then a per-day totals
    /// footer. The VM pre-merges `displayItems`, so the view only renders and tracks `isLast`.
    private var expandedBody: some View {
        let items = day.displayItems
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                let isLast = index == items.count - 1
                switch item {
                case .checkIn(let node):
                    TimelineRow(node: node, isLast: isLast, onTapRecording: onTapRecording)
                case .nutrition(let event):
                    NutritionEventRow(item: event, isLast: isLast)
                }
            }
            if let summary = day.nutrition?.summary {
                DayNutritionFooter(summary: summary, railIndent: items.isEmpty ? 0 : Metrics.timeBead + 2 + Spacing.m)
            }
        }
        .padding(.horizontal, Spacing.l)
        .padding(.top, Spacing.m)
        .padding(.bottom, Spacing.l)
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
