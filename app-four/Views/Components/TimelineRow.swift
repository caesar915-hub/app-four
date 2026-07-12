import SwiftUI

/// One row of the day timeline (spec 023): the mood bead (mood glyph + medication-phase ring) with its
/// downward connector on the left, and the check-in content on the right as four bare glyph+text lines —
/// (1) mood word + time + a push chevron, (2) energy + focus, (3) medication + sleep, (4) feelings +
/// side-effects. No pill containers: read-only data reads as quiet text; medication is the single accent.
/// Tapping the row (content or chevron) pushes the recording detail.
struct TimelineRow: View {
    let node: DayTimeline.Node
    let isLast: Bool
    let onTapRecording: (UUID) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.m) {
            beadColumn
            content
                .padding(.bottom, isLast ? 0 : Spacing.section)   // breathing room between check-ins
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Bead + connector

    private var beadColumn: some View {
        VStack(spacing: 0) {
            TimelineBead(node: node)
                .zIndex(1)
            if !isLast {
                Rectangle()
                    .fill(NewLook.hairline)
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
                rowHead(recording)        // line 1 (mood + time) + line 2 (energy + focus)
            }
            medicationSleepLine           // line 3
            if let recording = node.recording {
                feelingsSideEffectsLine(recording)   // line 4
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Metrics.rowHeadTop)   // pull the head toward the bead's top (mid-high)
    }

    // MARK: - Line 1 + 2 (mood · time · chevron / energy · focus)

    private func rowHead(_ recording: Recording) -> some View {
        let level = MoodLevel(name: recording.mood)
        return VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
                Text(level?.displayLabel ?? recording.displayTitle)
                    .font(Typography.text(Metrics.rowMoodText, weight: .semibold))
                    .foregroundStyle(level?.wordColor ?? .primary)
                Text(node.time, format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
                    .font(Typography.mono(Metrics.rowTime))
                    .foregroundStyle(NewLook.inkSecondary)
                Spacer(minLength: Spacing.s)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(NewLook.inkSecondary)
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

    // MARK: - Line 3 (medication · sleep) — the single accent + the sleep blue

    @ViewBuilder
    private var medicationSleepLine: some View {
        let taken = takenLabels
        let sleep = node.recording?.sleepLine
        if !taken.isEmpty || sleep != nil {
            FlowLayout(spacing: Spacing.m) {
                ForEach(taken, id: \.self) { label in
                    dataItem("capsule.righthalf.filled", label, color: Palette.medication, weight: .semibold)
                }
                if let sleep {
                    dataItem("zzz", sleep.label, color: sleep.color)
                }
            }
        }
    }

    // MARK: - Line 4 (feelings · side-effects) — muted context, capped at 4 each

    @ViewBuilder
    private func feelingsSideEffectsLine(_ recording: Recording) -> some View {
        let feelings = recording.feelings()
        let sideEffects = recording.sideEffects()
        if !feelings.shown.isEmpty || !sideEffects.shown.isEmpty {
            FlowLayout(spacing: Spacing.m) {
                if !feelings.shown.isEmpty {
                    dataItem("heart.fill", joined(feelings), color: NewLook.inkSecondary)
                }
                if !sideEffects.shown.isEmpty {
                    dataItem("medical.thermometer", joined(sideEffects), color: NewLook.inkSecondary)
                }
            }
        }
    }

    // MARK: - Shared bare glyph+text item

    private func dataItem(_ systemImage: String, _ text: String, color: Color, weight: Font.Weight = .regular) -> some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: systemImage)
                .font(Typography.caption)
                .accessibilityHidden(true)   // the value text carries the meaning; the glyph is reinforcement
            Text(text)
                .font(Typography.caption.weight(weight))
        }
        .foregroundStyle(color)
    }

    private func joined(_ capped: (shown: [String], overflow: Int)) -> String {
        var text = capped.shown.joined(separator: " · ")
        if capped.overflow > 0 { text += " +\(capped.overflow)" }
        return text
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
