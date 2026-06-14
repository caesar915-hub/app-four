import SwiftUI

/// One row of the day timeline: the bead (with its downward connector line) on the
/// left, and the check-in content on the right — a mood banner (mood · energy ·
/// focus), a "Taken …" pill for any dose logged here, and neutral chips for the
/// remaining inputs. Tapping a row that has a recording opens its detail.
struct TimelineRow: View {
    let node: DayTimeline.Node
    let isLast: Bool
    let onTapRecording: (UUID) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.m) {
            beadColumn
            content
                .padding(.bottom, isLast ? 0 : Spacing.section)   // more breathing room between check-ins
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Bead + connector

    private var beadColumn: some View {
        VStack(spacing: 0) {
            TimelineBead(node: node)
                .zIndex(1)   // keep the carry-over badge above the connector line
            if !isLast {
                Rectangle()
                    .fill(Theme.separator)
                    .frame(width: 1)
                    .frame(maxHeight: .infinity)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if let recording = node.recording {
            Button { onTapRecording(recording.id) } label: { contentBody }
                .buttonStyle(.plain)
                .accessibilityHint("Opens recording detail")
        } else {
            contentBody
        }
    }

    private var contentBody: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            if let recording = node.recording {
                MoodBanner(
                    mood: recording.mood,
                    energy: recording.energyLevel,
                    focus: recording.focusLevel,
                    fallbackTitle: recording.title,
                    fill: recording.moodColor
                )
            }
            chips
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Spacing.l)   // centre the banner against the bead, level with the time
    }

    // MARK: - Chips ("Taken …" pill + inputs)

    @ViewBuilder
    private var chips: some View {
        let taken = takenLabels
        let inputs = node.recording?.chipTags ?? []
        if !taken.isEmpty || !inputs.isEmpty {
            FlowLayout(spacing: Spacing.s) {
                ForEach(taken, id: \.self) { label in
                    TimelineChip.medication(label)
                }
                ForEach(inputs) { tag in
                    TimelineChip(icon: tag.icon, label: tag.label)
                }
            }
        }
    }

    /// "TAKEN CONCERTA 36MG" for each distinct dose logged at this instant.
    private var takenLabels: [String] {
        var seen = Set<String>()
        return node.intakeDoses.compactMap { dose in
            guard seen.insert(dose.name).inserted else { return nil }
            let med = dose.dose.map { "\(dose.name) \($0)" } ?? dose.name
            return "Taken \(med)".uppercased()
        }
    }
}
