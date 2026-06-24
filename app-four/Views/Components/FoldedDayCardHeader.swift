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
    private var showsSummary: Bool { !isExpanded || summary.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            titleRow
                .padding(.horizontal, Spacing.l)
            if showsSummary {
                if !summary.isEmpty {
                    Rectangle().fill(Theme.separator).frame(height: 1)   // full-width divider
                }
                summaryLine
                    .padding(.horizontal, Spacing.l)
            }
        }
        .padding(.vertical, Spacing.l)
        .frame(maxWidth: .infinity, minHeight: Metrics.minTapTarget, alignment: .leading)
        .background {
            // Inset the tint within a cream frame so the card reads as a mood-tinted panel,
            // not a full-card stain. Inner radius = card radius − inset → concentric corners.
            RoundedRectangle(cornerRadius: Radius.card - Spacing.s, style: .continuous)
                .fill(level?.blockTint ?? .clear)
                .padding(Spacing.s)
        }
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
            SignalGlyph(.mood, level: level?.numericValue, size: Metrics.headerMoodBadge * 0.5, decorative: true)
        }
        .frame(width: Metrics.headerMoodBadge, height: Metrics.headerMoodBadge)
        .accessibilityHidden(true)
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
        return p
    }

    private var accessibilityLabel: String {
        if summary.isEmpty { return "\(day.label). \(DayCardSummary.emptyCopy)" }
        let signals = [summary.mood, summary.energy, summary.focus, summary.mostRecentMedicationName].compactMap { $0 }
        return ([day.label] + signals).joined(separator: ", ")
    }
}
