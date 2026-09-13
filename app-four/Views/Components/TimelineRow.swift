import SwiftUI

/// One check-in row of the expanded day card, redesigned to Figma a01 (spec 034, node `308:1957`):
/// a 43pt mood disc (tinted with the row's own mood) holding that mood's sprout, the mood word large
/// + bold in its word colour, the time, an outlined ⋯ affordance, and a single wrapping dot-chip line
/// (energy · focus · medication · sleep · ♥ feelings · side-effects). No timeline bead, no connector,
/// no medication-phase ring — rows are separated by whitespace on the white card. Tapping the row
/// (anywhere, including the ⋯) opens the recording detail.
struct TimelineRow: View {
    let node: DayTimeline.Node
    let onTapRecording: (UUID) -> Void

    /// Outlined ⋯ affordance border — a hairline-plus stroke matching a01 (1.5pt).
    private static let affordanceBorder: CGFloat = 1.5

    private var level: MoodLevel? { MoodLevel(name: node.recording?.mood) }

    var body: some View {
        Group {
            if let recording = node.recording {
                Button { onTapRecording(recording.id) } label: { row(recording) }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens recording detail")
            } else {
                row(nil)   // dose-only node (logged dose, no check-in): still shown, no ⋯, not tappable
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Row

    private func row(_ recording: Recording?) -> some View {
        HStack(alignment: .top, spacing: Spacing.l) {
            disc
            VStack(alignment: .leading, spacing: Spacing.s) {
                headline(tappable: recording != nil)
                chipLine(recording)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
    }

    private var disc: some View {
        Circle()
            .fill(level?.badgeTint ?? NewLook.tintNeutral)
            .frame(width: Metrics.rowMoodDisc, height: Metrics.rowMoodDisc)
            .overlay {
                SignalGlyph(.mood, level: level?.numericValue, size: Metrics.rowMoodGlyph, decorative: true)
            }
    }

    private func headline(tappable: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.m) {
            headlineText
                .fixedSize(horizontal: false, vertical: true)   // wrap word↔time at large Dynamic Type, never truncate
            Spacer(minLength: Spacing.s)
            if tappable {
                moreAffordance
            }
        }
    }

    /// Mood word (24pt Bold, word colour) + time, as one concatenated `Text` so the space between
    /// them is the break opportunity — the single-word mood label can never truncate. When no mood
    /// was extracted (a transcribing/pending or untagged check-in) the recording's `displayTitle`
    /// takes the headline slot so the row still reads a status, never a bare timestamp (FR-017).
    private var headlineText: Text {
        let time = Text(node.time, format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
            .font(Typography.text(13, relativeTo: .subheadline))
            .foregroundStyle(NewLook.inkSecondary)
        if let level {
            let word = Text(level.displayLabel).font(Typography.moodWord).foregroundStyle(level.wordColor)
            return Text("\(word)  \(time)")
        }
        if let recording = node.recording {
            let title = Text(recording.displayTitle)
                .font(Typography.text(17, weight: .semibold, relativeTo: .body))
                .foregroundStyle(NewLook.inkPrimary)
            return Text("\(title)  \(time)")
        }
        return time   // dose-only node: no check-in, so the time alone is the headline
    }

    /// Outlined ⋯ circle (a01). Decorative — the whole row already opens the detail.
    private var moreAffordance: some View {
        Image(systemName: "ellipsis")
            .font(.caption)
            .foregroundStyle(NewLook.inkSecondary)
            .frame(width: Metrics.moreAffordance, height: Metrics.moreAffordance)
            .overlay { Circle().strokeBorder(NewLook.inkSecondary, lineWidth: Self.affordanceBorder) }
            .accessibilityHidden(true)
    }

    // MARK: - Chip line

    private struct Chip {
        let kind: GlyphSignal?
        let level: Int?
        let text: String
        let color: Color
    }

    @ViewBuilder
    private func chipLine(_ recording: Recording?) -> some View {
        let items = chips(recording)
        if !items.isEmpty {
            FlowLayout(spacing: Spacing.s) {
                ForEach(Array(items.enumerated()), id: \.offset) { idx, chip in
                    HStack(spacing: Spacing.xs) {
                        if idx > 0 {
                            Text("·").font(Typography.caption).foregroundStyle(NewLook.inkSecondary)
                        }
                        if let kind = chip.kind {
                            SignalGlyph(kind, level: chip.level, size: Metrics.rowSignal, decorative: true)
                        }
                        Text(chip.text)
                            .font(Typography.caption)
                            .foregroundStyle(chip.color)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    private func chips(_ recording: Recording?) -> [Chip] {
        var c: [Chip] = []
        if let energy = recording?.energyLevel, !energy.isEmpty {
            let level = EnergyLevel(rawValue: energy)
            c.append(Chip(kind: .energy, level: level?.numericValue, text: level?.displayLabel ?? energy, color: .primary))
        }
        if let focus = recording?.focusLevel, !focus.isEmpty {
            // Stored value is the enum rawValue ("lockedIn" is camelCase); lowercasing it
            // returned nil for level-5 focus, dropping the glyph fill and printing "lockedIn".
            let level = FocusLevel(rawValue: focus)
            c.append(Chip(kind: .focus, level: level?.numericValue, text: level?.displayLabel ?? focus, color: .primary))
        }
        for name in distinctMedicationNames {
            c.append(Chip(kind: .medication, level: nil, text: name, color: Palette.medication))
        }
        // Sleep: indigo text, no glyph — per a01 node 308:1957 (the folded summary pairs the bed glyph
        // with primary-ink text instead; the two states match their respective Figma nodes).
        if let sleep = recording?.sleepLabel {
            c.append(Chip(kind: nil, level: nil, text: sleep, color: Palette.sleepIndigo))
        }
        if let recording {
            let feelings = recording.feelings()
            if !feelings.shown.isEmpty {
                c.append(Chip(kind: nil, level: nil, text: "♥ " + joined(feelings), color: NewLook.inkSecondary))
            }
            let sideEffects = recording.sideEffects()
            if !sideEffects.shown.isEmpty {
                c.append(Chip(kind: nil, level: nil, text: joined(sideEffects), color: NewLook.inkSecondary))
            }
        }
        return c
    }

    /// Distinct medication names logged at this node (name only — no dose, no "Taken").
    private var distinctMedicationNames: [String] {
        var seen = Set<String>()
        return node.intakeDoses.compactMap { seen.insert($0.name).inserted ? $0.name : nil }
    }

    private func joined(_ capped: (shown: [String], overflow: Int)) -> String {
        var text = capped.shown.joined(separator: ", ")
        if capped.overflow > 0 { text += " +\(capped.overflow)" }
        return text
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        var parts: [String] = []
        if let level { parts.append(level.displayLabel) }
        parts.append(node.time.formatted(.dateTime.hour().minute(.twoDigits)))
        if let energy = node.recording?.energyLevel, !energy.isEmpty { parts.append(EnergyLevel(rawValue: energy)?.displayLabel ?? energy) }
        if let focus = node.recording?.focusLevel, !focus.isEmpty { parts.append(FocusLevel(rawValue: focus)?.displayLabel ?? focus) }
        parts.append(contentsOf: distinctMedicationNames)
        if let sleep = node.recording?.sleepLabel { parts.append(sleep) }
        if let recording = node.recording {
            let feelings = recording.feelings()
            if !feelings.shown.isEmpty { parts.append(joined(feelings)) }
            let sideEffects = recording.sideEffects()
            if !sideEffects.shown.isEmpty { parts.append(joined(sideEffects)) }
        }
        return parts.joined(separator: ", ")
    }
}
