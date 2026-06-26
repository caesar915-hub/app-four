import SwiftUI

/// The always-visible top of a `DayCard` (spec 023): a mood-tinted block holding a fixed-size inline
/// mood glyph (no cream disc), the mood word + weekday, and — folded — a one-line summary
/// (energy · focus · medication name). The glyph and text are centre-aligned, so on expand the summary
/// collapses and the title settles to the glyph's vertical centre (the glyph itself never resizes).
/// An empty day drops the glyph and tint and shows calm copy. Exposed to VoiceOver as one combined
/// element; the glyph is decorative.
struct FoldedDayCardHeader: View {
    let day: MoodLibraryViewModel.TimelineDay
    let isExpanded: Bool

    private var summary: DayCardSummary { DayCardSummary(day: day) }
    private var level: MoodLevel? { MoodLevel(name: summary.mood) }
    private var showsSummary: Bool { !isExpanded || summary.isEmpty }

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.m) {
            if let level {
                SignalGlyph(.mood, level: level.numericValue, size: Metrics.dayHeaderGlyph, decorative: true)
            }
            VStack(alignment: .leading, spacing: Spacing.xs) {
                title
                    .font(Typography.dayCardDate)
                    .fixedSize(horizontal: false, vertical: true)   // wrap at large Dynamic Type, never truncate
                if showsSummary {
                    summaryLine
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.down")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
                .rotationEffect(.degrees(isExpanded ? 180 : 0))
        }
        .padding(.horizontal, Spacing.l)
        .padding(.vertical, Spacing.m)
        .frame(maxWidth: .infinity, minHeight: Metrics.minTapTarget, alignment: .leading)
        .background(level?.blockTint ?? .clear)   // empty day → no tint
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(isExpanded ? "Expanded, double tap to collapse" : "Double tap to expand")
    }

    /// Mood word (deepened mood colour) · weekday, concatenated as one `Text` so it wraps — never
    /// truncating the mood word — at large Dynamic Type. Weekday only when mood is unknown.
    private var title: Text {
        let weekday = Text(day.label).foregroundStyle(.primary)
        guard let level else { return weekday }
        let mood = Text(level.displayLabel).foregroundStyle(level.wordColor)
        let separator = Text(" · ").foregroundStyle(Theme.textSecondary)
        return Text("\(mood)\(separator)\(weekday)")
    }

    @ViewBuilder private var summaryLine: some View {
        if summary.isEmpty {
            Text(DayCardSummary.emptyCopy)
                .font(Typography.callout)
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(2)
        } else {
            FlowLayout(spacing: Spacing.s) {
                ForEach(Array(parts.enumerated()), id: \.offset) { idx, part in
                    HStack(spacing: Spacing.xs) {
                        if idx > 0 {
                            Text("·").foregroundStyle(Theme.textSecondary)
                        }
                        if let kind = part.kind {
                            SignalGlyph(kind, level: part.level, size: Metrics.summarySignal, decorative: true)
                        } else if let systemImage = part.systemImage {
                            Image(systemName: systemImage)
                                .font(Typography.caption)
                                .foregroundStyle(part.color)
                                .accessibilityHidden(true)
                        }
                        Text(part.text)
                            .font(Typography.caption)
                            .foregroundStyle(part.color)
                            .lineLimit(1)
                    }
                    .fixedSize()
                }
            }
        }
    }

    /// One summary token: energy/focus keep the custom signal glyph; medication uses the SF capsule
    /// (spec 023 — custom glyphs for the core signals, SF Symbols for context).
    private struct Part {
        let kind: GlyphSignal?
        let systemImage: String?
        let level: Int?
        let text: String
        let color: Color
    }

    private var parts: [Part] {
        var p: [Part] = []
        if let energy = summary.energy {
            p.append(Part(kind: .energy, systemImage: nil,
                          level: EnergyLevel(rawValue: energy.lowercased())?.numericValue, text: energy, color: .primary))
        }
        if let focus = summary.focus {
            p.append(Part(kind: .focus, systemImage: nil,
                          level: FocusLevel(rawValue: focus.lowercased())?.numericValue, text: focus, color: .primary))
        }
        if let med = summary.mostRecentMedicationName {
            p.append(Part(kind: nil, systemImage: "capsule.righthalf.filled", level: nil, text: med, color: Palette.medication))
        }
        return p
    }

    private var accessibilityLabel: String {
        if summary.isEmpty { return "\(day.label). \(DayCardSummary.emptyCopy)" }
        let signals = [summary.mood, summary.energy, summary.focus, summary.mostRecentMedicationName].compactMap { $0 }
        return ([day.label] + signals).joined(separator: ", ")
    }
}
