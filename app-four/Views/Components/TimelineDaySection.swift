import SwiftUI

/// One day's section in the calendar timeline: a date header followed by its
/// time-ordered nodes. Extracted from `CalendarLibraryView` as a dedicated subview.
struct TimelineDaySection: View {
    let day: MoodLibraryViewModel.TimelineDay
    let onTapRecording: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(day.label.uppercased())
                .font(Typography.label)
                .foregroundStyle(Theme.textSecondary)
                .padding(.top, Spacing.xl)
                .padding(.bottom, Spacing.m)
                .accessibilityAddTraits(.isHeader)

            ForEach(Array(day.nodes.enumerated()), id: \.element.id) { index, node in
                TimelineRow(
                    node: node,
                    isLast: index == day.nodes.count - 1,
                    onTapRecording: onTapRecording
                )
            }
        }
    }
}
