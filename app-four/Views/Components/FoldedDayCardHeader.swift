import SwiftUI

/// The always-visible top of a `DayCard`: a mood-glyph circle, the weekday, and a one-line
/// summary (`mood · energy · focus · medication-name`) derived from the day's most-recent
/// check-in via the pure `DayCardSummary`. The summary line collapses when the card is
/// expanded (shrink-on-open, FR-005); an empty day keeps its calm copy (FR-004). Exposed to
/// VoiceOver as a single combined element (FR-017); the mood glyph is decorative.
struct FoldedDayCardHeader: View {
    let day: MoodLibraryViewModel.TimelineDay
    let isExpanded: Bool

    private var summary: DayCardSummary { DayCardSummary(day: day) }

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.m) {
            moodCircle
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(spacing: Spacing.s) {
                    Text(day.label)
                        .font(.fraunces(19))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer(minLength: Spacing.s)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                if !isExpanded || summary.isEmpty { summaryLine }
            }
        }
        .frame(minHeight: Metrics.minTapTarget)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(isExpanded ? "Expanded, double tap to collapse" : "Double tap to expand")
    }

    private var moodCircle: some View {
        let level = summary.mood.flatMap { MoodLevel(name: $0)?.numericValue }
        let fill = summary.mood.flatMap { MoodLevel(name: $0)?.fill } ?? Color(.systemGray5)
        return ZStack {
            Circle().fill(fill.opacity(Opacity.moodCircle))
            SignalGlyph(.mood, level: level, size: Metrics.headerMoodCircle * 0.5, decorative: true)
        }
        .frame(width: Metrics.headerMoodCircle, height: Metrics.headerMoodCircle)
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
                    HStack(spacing: 3) {
                        if idx > 0 {
                            Text("·").foregroundStyle(Theme.textSecondary)
                        }
                        if let kind = part.kind {
                            SignalGlyph(kind, level: part.level, size: 15, decorative: true)
                        }
                        Text(part.text)
                            .font(part.isMood ? .fraunces(15) : Typography.caption)
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
        let isMood: Bool
    }

    private var parts: [Part] {
        var p: [Part] = []
        if let mood = summary.mood {
            p.append(Part(kind: nil, level: nil, text: mood, color: .primary, isMood: true))
        }
        if let energy = summary.energy {
            p.append(Part(kind: .energy, level: EnergyLevel(rawValue: energy.lowercased())?.numericValue,
                          text: energy, color: .primary, isMood: false))
        }
        if let focus = summary.focus {
            p.append(Part(kind: .focus, level: FocusLevel(rawValue: focus.lowercased())?.numericValue,
                          text: focus, color: .primary, isMood: false))
        }
        if let med = summary.mostRecentMedicationName {
            p.append(Part(kind: .medication, level: nil, text: med, color: Palette.medication, isMood: false))
        }
        return p
    }

    private var accessibilityLabel: String {
        if summary.isEmpty { return "\(day.label). \(DayCardSummary.emptyCopy)" }
        let signals = [summary.mood, summary.energy, summary.focus, summary.mostRecentMedicationName].compactMap { $0 }
        return ([day.label] + signals).joined(separator: ", ")
    }
}
