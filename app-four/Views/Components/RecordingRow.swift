import SwiftUI

/// The single recording row used by both the Calendar library and the Notes library.
/// Replaces `RecordingCell` (week-grouped list) and the inline row from `MoodCheckInCard`
/// (calendar/mood view).
///
/// Layout:
/// ```
/// ┌── [mood dot] ──────────────────────────────────────────────┐
/// │   Title                                    status badge    │
/// │   Timestamp · duration                                      │
/// │   [tag chip] [tag chip]  ...                                │
/// └─────────────────────────────────────────────────────────────┘
/// ```
struct RecordingRow: View {
    let recording: Recording

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.m) {
            moodDot

            VStack(alignment: .leading, spacing: Spacing.xs) {
                titleRow
                metaRow
                if !recording.displayTags.isEmpty {
                    tagRow
                }
            }
        }
        .card(padding: Spacing.m)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    // MARK: - Sub-views

    private var moodDot: some View {
        Circle()
            .fill(recording.moodColor)
            .frame(width: 10, height: 10)
            .padding(.top, 5) // aligns with first line of text baseline
            .accessibilityHidden(true)
    }

    private var titleRow: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(recording.title)
                .font(Typography.headline)
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            statusBadge
        }
    }

    private var metaRow: some View {
        HStack(spacing: Spacing.xs) {
            Text(recording.createdAt, format: .dateTime.month(.abbreviated).day().hour(.twoDigits(amPM: .abbreviated)).minute(.twoDigits))
                .font(Typography.caption)
                .foregroundStyle(Theme.textSecondary)

            Text("·")
                .font(Typography.caption)
                .foregroundStyle(Theme.textSecondary)

            Text(recording.formattedDuration)
                .font(Typography.caption.monospacedDigit())
                .foregroundStyle(Theme.textSecondary)
        }
    }

    @MainActor
    private var tagRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.xs) {
                ForEach(recording.displayTags) { tag in
                    HStack(spacing: Spacing.xs) { // was 3
                        Image(systemName: tag.icon)
                            .font(Typography.caption)
                        Text(tag.label)
                            .font(Typography.caption)
                    }
                    .foregroundStyle(tag.color)
                    .padding(.horizontal, Spacing.s)
                    .padding(.vertical, Spacing.xs) // was 3
                    .background(tag.color.opacity(0.12), in: .capsule)
                }
            }
        }
        .scrollDisabled(recording.displayTags.count <= 3)
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch recording.status {
        case .transcribing:
            HStack(spacing: Spacing.xs) {
                ProgressView().scaleEffect(0.6).frame(width: 12, height: 12)
                Text("Processing")
                    .font(Typography.caption)
            }
            .foregroundStyle(Theme.textSecondary)
        case .completed where recording.summary != nil:
            Image(systemName: "checkmark.circle.fill")
                .font(Typography.caption)
                .foregroundStyle(Theme.statusDone)
        default:
            EmptyView()
        }
    }

    // MARK: - Accessibility

    private var accessibilityDescription: String {
        var parts = [recording.title]
        parts.append(recording.createdAt.formatted(.dateTime.month().day().hour().minute(.twoDigits)))
        parts.append(recording.formattedDuration)
        if recording.status == .transcribing {
            parts.append("Processing")
        } else if recording.summary != nil {
            parts.append("Summary available")
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Preview

#Preview {
    List {
        NavigationLink {
            Text("Detail")
        } label: {
            RecordingRow(recording: PreviewData.recordings[0])
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: Spacing.xs, leading: Spacing.l, bottom: Spacing.xs, trailing: Spacing.l))

        NavigationLink {
            Text("Detail")
        } label: {
            RecordingRow(recording: PreviewData.recordings[1])
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: Spacing.xs, leading: Spacing.l, bottom: Spacing.xs, trailing: Spacing.l))
    }
    .listStyle(.plain)
    .navigationTitle("Preview")
}
