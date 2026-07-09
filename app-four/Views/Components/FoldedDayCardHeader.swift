import SwiftUI

/// The always-visible top of a `DayCard` (Paper & Pollen cream-disc header): a mood-tinted block
/// holding a cream-disc mood badge, the mood word + weekday on one line, and — folded — the summary
/// directly below it (no divider, per the approved spec-031 V3 mockup): signals on one line
/// (energy · focus · medication-name) with nutrition (kcal · caffeine) on its own line under them,
/// from the pure `DayCardSummary`. The summary collapses when expanded, leaving the tinted strip as
/// the day's header (an empty day keeps its calm copy). Exposed to VoiceOver as one combined element
/// (FR-017); the mood glyph is decorative.
struct FoldedDayCardHeader: View {
    let day: MoodLibraryViewModel.TimelineDay
    let isExpanded: Bool

    private var summary: DayCardSummary { DayCardSummary(day: day) }
    private var level: MoodLevel? { MoodLevel(name: summary.mood) }
    // Folded → always show the summary. Expanded → hide it (the rows/footer carry the
    // detail), except a truly empty day with nothing to expand keeps its calm copy.
    private var showsSummary: Bool { !isExpanded || (summary.isEmpty && day.nutrition == nil) }

    var body: some View {
        // Disc on the left, the text column (title + summary) in the middle, chevron on the
        // right — the summary is tucked under the title inside the text column, indented past
        // the disc, with no divider (approved spec-031 V3 mockup `.tcol` layout).
        HStack(alignment: .center, spacing: Spacing.m) {
            moodBadge
            VStack(alignment: .leading, spacing: Spacing.xs) {
                title
                    .font(Typography.dayCardDate)
                    .dynamicTypeSize(...DynamicTypeSize.xLarge)   // cap growth so the weekday/date can't balloon
                    .frame(maxWidth: .infinity, alignment: .leading)
                if showsSummary {
                    summaryLine
                }
            }
            Image(systemName: "chevron.down")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
                .rotationEffect(.degrees(isExpanded ? 180 : 0))
        }
        .padding(.horizontal, Spacing.l)
        .padding(.vertical, Spacing.l)
        .frame(maxWidth: .infinity, minHeight: Metrics.minTapTarget, alignment: .leading)
        .background(level?.blockTint ?? .clear)   // full-bleed mood tint; the card clip rounds the corners
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(isExpanded ? "Expanded, double tap to collapse" : "Double tap to expand")
    }

    /// Mood word (deepened mood colour) · weekday, built as one styled `AttributedString` so it
    /// wraps — never truncating the mood word — at large Dynamic Type (FR-013), and avoids the
    /// iOS-26-deprecated `Text` `+` concatenation. Weekday only when mood is unknown.
    private var title: Text {
        var weekday = AttributedString(day.label)
        weekday.foregroundColor = .primary
        guard let level else { return Text(weekday) }
        var mood = AttributedString(level.displayLabel)
        mood.foregroundColor = level.wordColor
        var separator = AttributedString(" · ")
        separator.foregroundColor = Theme.textSecondary
        return Text(mood + separator + weekday)
    }

    private var moodBadge: some View {
        ZStack {
            Circle().fill(level?.badgeTint ?? Color(.systemGray5))
            SignalGlyph(.mood, level: level?.numericValue, size: Metrics.headerMoodBadge * 0.56, decorative: true)
        }
        .frame(width: Metrics.headerMoodBadge, height: Metrics.headerMoodBadge)
        .accessibilityHidden(true)
    }

    @ViewBuilder private var summaryLine: some View {
        if summary.isEmpty && nutritionParts.isEmpty {
            Text(DayCardSummary.emptyCopy)
                .font(Typography.callout)
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(2)
        } else {
            // Two structured lines, no divider between them: the check-in signals
            // (energy · focus · medication) always own the first line; nutrition
            // tokens (kcal · caffeine) always drop to their own line below so a
            // single token never orphans mid-wrap (spec 031 folded layout).
            VStack(alignment: .leading, spacing: Spacing.xs) {
                if !signalParts.isEmpty {
                    tokenRow(signalParts)
                }
                if !nutritionParts.isEmpty {
                    tokenRow(nutritionParts)
                }
            }
        }
    }

    /// One wrapping line of `·`-separated tokens. Each row restarts its own separator
    /// indexing so a nutrition-only line never leads with a stray dot.
    private func tokenRow(_ tokens: [Part]) -> some View {
        FlowLayout(spacing: Spacing.s) {
            ForEach(Array(tokens.enumerated()), id: \.offset) { idx, part in
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

    private struct Part {
        let kind: GlyphSignal?
        let level: Int?
        let text: String
        let color: Color
        var systemImage: String? = nil   // SF Symbol tokens (nutrition, spec 031); kind wins when both set
    }

    /// The first summary line — check-in signals only (energy · focus · medication name),
    /// or the quiet "No check-ins" lead-in on a nutrition-only day. Nutrition never lives
    /// here; it renders on its own line via `nutritionParts`. Mood moved up to the title row.
    private var signalParts: [Part] {
        guard !summary.isEmpty else {
            return nutritionParts.isEmpty
                ? []
                : [Part(kind: nil, level: nil, text: "No check-ins", color: Theme.textSecondary)]
        }
        var p: [Part] = []
        if let energy = summary.energy {
            p.append(Part(kind: .energy, level: EnergyLevel(rawValue: energy.lowercased())?.numericValue,
                          text: energy, color: .primary))
        }
        if let focus = summary.focus {
            p.append(Part(kind: .focus, level: FocusLevel(rawValue: focus.lowercased())?.numericValue,
                          text: focus, color: .primary))
        }
        if let med = summary.mostRecentMedicationName {
            p.append(Part(kind: .medication, level: nil, text: med, color: Palette.medication))
        }
        return p
    }

    /// Folded nutrition tokens (spec 031, approved mockup V3): dietary kcal + caffeine,
    /// capped at two so the FlowLayout stays scannable. Absent metrics render nothing.
    private var nutritionParts: [Part] {
        guard let totals = day.nutrition?.summary else { return [] }
        var p: [Part] = []
        if let kcal = totals.kcalIn {
            p.append(Part(kind: nil, level: nil, text: "\(Int(kcal.rounded()).formatted()) kcal",
                          color: Palette.nutritionFood, systemImage: "fork.knife"))
        }
        if let mg = totals.caffeineMg {
            p.append(Part(kind: nil, level: nil, text: "\(Int(mg.rounded())) mg",
                          color: Palette.nutritionFood, systemImage: "cup.and.saucer.fill"))
        }
        return p
    }

    private var accessibilityLabel: String {
        if summary.isEmpty && nutritionParts.isEmpty { return "\(day.label). \(DayCardSummary.emptyCopy)" }
        var pieces: [String] = [day.label]
        if summary.isEmpty {
            pieces.append("No check-ins")
        } else {
            pieces += [summary.mood, summary.energy, summary.focus, summary.mostRecentMedicationName].compactMap { $0 }
        }
        if let totals = day.nutrition?.summary {
            if let kcal = totals.kcalIn { pieces.append("\(Int(kcal.rounded())) calories eaten") }
            if let mg = totals.caffeineMg { pieces.append("\(Int(mg.rounded())) milligrams caffeine") }
        }
        return pieces.joined(separator: ", ")
    }
}
