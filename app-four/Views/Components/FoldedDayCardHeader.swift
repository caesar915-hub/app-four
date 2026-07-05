import SwiftUI

/// The always-visible top of a `DayCard` (Paper & Pollen "#4 Divided · Cream disc", spec 019): a
/// mood-tinted block holding a cream-disc mood badge, the mood word + weekday on one line, and —
/// folded — a full-width divider above the one-line summary (energy · focus · medication-name) from
/// the pure `DayCardSummary`. The summary collapses when expanded, leaving the tinted strip as the
/// day's header (an empty day keeps its calm copy). Exposed to VoiceOver as one combined element
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
        VStack(alignment: .leading, spacing: Spacing.s) {
            titleRow
                .padding(.horizontal, Spacing.l)
            if showsSummary {
                if !summary.isEmpty || !nutritionParts.isEmpty {
                    Rectangle().fill(Theme.separator).frame(height: 1)   // full-width divider
                }
                summaryLine
                    .padding(.horizontal, Spacing.l)
            }
        }
        .padding(.vertical, Spacing.l)
        .frame(maxWidth: .infinity, minHeight: Metrics.minTapTarget, alignment: .leading)
        .background(level?.blockTint ?? .clear)   // full-bleed mood tint (matches the approved "#4" mockup; the card clip rounds the corners)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(isExpanded ? "Expanded, double tap to collapse" : "Double tap to expand")
    }

    private var titleRow: some View {
        HStack(alignment: .center, spacing: Spacing.m) {
            moodBadge
            title
                .font(Typography.dayCardDate)
                .dynamicTypeSize(...DynamicTypeSize.xLarge)   // cap growth so the weekday/date can't balloon
                .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.down")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
                .rotationEffect(.degrees(isExpanded ? 180 : 0))
        }
    }

    /// Mood word (deepened mood colour) · weekday, concatenated as one `Text` so it wraps — never
    /// truncating the mood word — at large Dynamic Type (FR-013). Weekday only when mood is unknown.
    private var title: Text {
        let weekday = Text(day.label).foregroundColor(.primary)
        guard let level else { return weekday }
        return Text(level.displayLabel).foregroundColor(level.wordColor)
            + Text(" · ").foregroundColor(Theme.textSecondary)
            + weekday
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
            FlowLayout(spacing: Spacing.s) {
                ForEach(Array(displayParts.enumerated()), id: \.offset) { idx, part in
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

    private struct Part {
        let kind: GlyphSignal?
        let level: Int?
        let text: String
        let color: Color
        var systemImage: String? = nil   // SF Symbol tokens (nutrition, spec 031); kind wins when both set
    }

    /// What the summary FlowLayout renders: the signal parts, or — on a day with
    /// nutrition data but no check-ins — a quiet lead-in plus the nutrition tokens
    /// (spec 031 approved states mockup).
    private var displayParts: [Part] {
        guard summary.isEmpty else { return parts }
        return [Part(kind: nil, level: nil, text: "No check-ins", color: Theme.textSecondary)] + nutritionParts
    }

    /// Summary signals below the divider — energy · focus · medication name. The mood is no longer
    /// here (it moved up to the title line beside the weekday).
    private var parts: [Part] {
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
        return p + nutritionParts
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
