import SwiftUI

/// The top of a `DayCard`, redesigned to Figma a01 (spec 034).
/// **Folded** (`308:2122`): a mood-tinted card with a bare mood sprout at the left, the mood word
/// large + bold in its word colour, a 3-letter uppercase weekday, and a wrapping glyph-chip
/// summary (energy · focus · medication · sleep) with dot separators.
/// **Expanded**: the header collapses to a slim uppercase band ("GREAT · MON" + up chevron,
/// `308:1958`); the check-in rows render below on the white card.
/// An empty day drops the glyph and tint and shows calm copy. Exposed to VoiceOver as one combined
/// element; glyphs are decorative.
struct FoldedDayCardHeader: View {
    let day: MoodLibraryViewModel.TimelineDay
    let isExpanded: Bool

    private var summary: DayCardSummary { DayCardSummary(day: day) }
    private var level: MoodLevel? { MoodLevel(name: summary.mood) }

    private static let weekdayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f
    }()
    private var weekday: String { Self.weekdayFormatter.string(from: day.date).uppercased() }

    private let caps = Typography.text(13, weight: .semibold, relativeTo: .subheadline)

    var body: some View {
        if isExpanded && !summary.isEmpty {
            collapsedBand
        } else {
            foldedContent
        }
    }

    // MARK: - Folded

    private var foldedContent: some View {
        HStack(alignment: .center, spacing: Spacing.m) {
            if let level {
                SignalGlyph(.mood, level: level.numericValue, size: Metrics.dayHeaderGlyph, decorative: true)
            }
            VStack(alignment: .leading, spacing: Spacing.xs) {
                foldedTitle
                    .fixedSize(horizontal: false, vertical: true)   // wrap at large Dynamic Type, never truncate
                if summary.isEmpty {
                    Text(DayCardSummary.emptyCopy)
                        .font(Typography.callout)
                        .foregroundStyle(NewLook.inkSecondary)
                        .lineLimit(2)
                } else {
                    summaryLine
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.down")
                .font(.caption.weight(.semibold))
                .foregroundStyle(NewLook.inkSecondary)
        }
        .padding(.horizontal, Spacing.l)
        .padding(.vertical, Spacing.m)
        .frame(maxWidth: .infinity, minHeight: Metrics.minTapTarget, alignment: .leading)
        .background(level?.blockTint ?? .clear)   // empty day → no tint
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Double tap to expand")
    }

    /// "Great · MON" — 24pt-Bold mood word (word colour) + 13pt uppercase weekday. One concatenated
    /// `Text` so it wraps (never truncating the mood word) at large Dynamic Type; per-run fonts/tracking.
    private var foldedTitle: Text {
        let wd = Text(weekday).font(caps).tracking(1.3).foregroundStyle(NewLook.inkPrimary)
        guard let level else { return wd }
        let mood = Text(level.displayLabel)
            .font(Typography.moodWord)
            .foregroundStyle(level.wordColor)
        let sep = Text(" · ").font(caps).foregroundStyle(NewLook.inkSecondary)
        return Text("\(mood)\(sep)\(wd)")
    }

    private var summaryLine: some View {
        FlowLayout(spacing: Spacing.s) {
            ForEach(Array(chips.enumerated()), id: \.offset) { idx, chip in
                HStack(spacing: Spacing.xs) {
                    if idx > 0 {
                        Text("·").font(Typography.caption).foregroundStyle(NewLook.inkSecondary)
                    }
                    SignalGlyph(chip.kind, level: chip.level, size: Metrics.summarySignal, decorative: true)
                    Text(chip.text)
                        .font(Typography.caption)
                        .foregroundStyle(chip.color)
                        .lineLimit(1)
                }
                .fixedSize()
            }
        }
    }

    /// Folded summary chips, in a01 order. Medication uses the custom capsule glyph in purple; sleep
    /// uses the bed glyph with primary-ink text (per node `308:2122`); energy/focus are primary ink.
    private struct Chip {
        let kind: GlyphSignal
        let level: Int?
        let text: String
        let color: Color
    }

    private var chips: [Chip] {
        var c: [Chip] = []
        if let energy = summary.energy {
            // summary.energy/.focus are displayLabels ("Charged", "Locked In"); resolve the
            // level by matching displayLabel so multi-word "Locked In" (focus 5) keeps its fill.
            let level = EnergyLevel.allCases.first { $0.displayLabel == energy }?.numericValue
            c.append(Chip(kind: .energy, level: level, text: energy, color: .primary))
        }
        if let focus = summary.focus {
            let level = FocusLevel.allCases.first { $0.displayLabel == focus }?.numericValue
            c.append(Chip(kind: .focus, level: level, text: focus, color: .primary))
        }
        if let med = summary.mostRecentMedicationName {
            c.append(Chip(kind: .medication, level: nil, text: med, color: Palette.medication))
        }
        if let sleep = summary.sleep {
            c.append(Chip(kind: .sleep, level: nil, text: sleep, color: .primary))
        }
        return c
    }

    // MARK: - Collapsed band (expanded state)

    private var collapsedBand: some View {
        HStack(spacing: Spacing.s) {
            bandLabel
            Spacer(minLength: Spacing.s)
            Image(systemName: "chevron.down")
                .font(.caption.weight(.semibold))
                .foregroundStyle(NewLook.inkSecondary)
                .rotationEffect(.degrees(180))
        }
        .padding(.horizontal, Spacing.l)
        .padding(.vertical, Spacing.s)
        .frame(maxWidth: .infinity, minHeight: Metrics.minTapTarget, alignment: .leading)
        .background(level?.blockTint ?? .clear)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Expanded, double tap to collapse")
    }

    /// "GREAT · MON" — all uppercase caps-13 (word colour · secondary dot · primary weekday).
    private var bandLabel: Text {
        let wd = Text(weekday).font(caps).tracking(1.3).foregroundStyle(NewLook.inkPrimary)
        guard let level else { return wd }
        let mood = Text(level.displayLabel.uppercased()).font(caps).tracking(1.3).foregroundStyle(level.wordColor)
        let sep = Text(" · ").font(caps).foregroundStyle(NewLook.inkSecondary)
        return Text("\(mood)\(sep)\(wd)")
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        if summary.isEmpty { return "\(day.label). \(DayCardSummary.emptyCopy)" }
        let signals = [summary.mood, summary.energy, summary.focus, summary.mostRecentMedicationName, summary.sleep].compactMap { $0 }
        return ([day.label] + signals).joined(separator: ", ")
    }
}
