import SwiftUI

/// One row of the day timeline: the bead (mood glyph + medication-phase ring) with its downward
/// connector on the left, and the check-in content on the right — a head (mood word + inline time +
/// energy/focus ramp glyphs + a details chevron), a "Taken …" pill for any dose logged here, and
/// neutral chips for the remaining inputs. Tapping a row that has a recording opens its detail.
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
                rowHead(recording)
            }
            chips
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Spacing.l)   // centre the head against the bead, level with the time
    }

    // MARK: - Row head (mood word + inline time + ramp glyphs + details chevron)

    private func rowHead(_ recording: Recording) -> some View {
        let level = MoodLevel(name: recording.mood)
        return VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
                Text(level?.displayLabel ?? recording.displayTitle)
                    .font(.fraunces(Metrics.rowMoodText))
                    .foregroundStyle(level?.wordColor ?? .primary)
                Text(node.time, format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
                    .font(.plexMono(Metrics.rowTime))
                    .foregroundStyle(Theme.textSecondary)
                Spacer(minLength: Spacing.s)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            rampLine(energy: recording.energyLevel, focus: recording.focusLevel)
        }
    }

    @ViewBuilder
    private func rampLine(energy: String?, focus: String?) -> some View {
        let items = rampItems(energy: energy, focus: focus)
        if !items.isEmpty {
            HStack(spacing: Spacing.m) {
                ForEach(items) { item in
                    HStack(spacing: Spacing.xs) {
                        SignalGlyph(item.kind, level: item.level, size: Metrics.rowSignal, decorative: true)
                        Text(item.word)
                            .font(Typography.caption)
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
    }

    private struct RampItem: Identifiable {
        let kind: GlyphSignal
        let level: Int?
        let word: String
        var id: GlyphSignal { kind }
    }

    private func rampItems(energy: String?, focus: String?) -> [RampItem] {
        var items: [RampItem] = []
        if let energy, !energy.isEmpty {
            items.append(.init(kind: .energy, level: EnergyLevel(rawValue: energy.lowercased())?.numericValue, word: energy))
        }
        if let focus, !focus.isEmpty {
            items.append(.init(kind: .focus, level: FocusLevel(rawValue: focus.lowercased())?.numericValue, word: focus))
        }
        return items
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
                    TimelineChip(icon: tag.icon, label: tag.label, glyph: tag.glyph)
                }
            }
        }
    }

    /// "Taken Concerta 36mg" for each distinct dose logged at this instant.
    private var takenLabels: [String] {
        var seen = Set<String>()
        return node.intakeDoses.compactMap { dose in
            guard seen.insert(dose.name).inserted else { return nil }
            let med = dose.dose.map { "\(dose.name) \($0)" } ?? dose.name
            return "Taken \(med)"
        }
    }
}
