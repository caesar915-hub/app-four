import SwiftUI

/// The three weekday rows of "Your month in three signals", split by hairlines.
struct WeekdayGlyphRows: View {
    let strips: [SignalStrip]

    var body: some View {
        VStack(spacing: Spacing.cardInset) {
            ForEach(Array(strips.enumerated()), id: \.element.kind) { index, strip in
                if index > 0 { HairlineDivider() }
                WeekdayGlyphRow(strip: strip)
            }
        }
        .accessibilityElement(children: .contain)
    }
}

/// One signal's weekday row (DESIGN.md §8.14): identity icon + label + the "Mostly …" status in
/// the signal's text colour, then seven glyph columns (33.55 glyph, 12/500 weekday). An empty
/// weekday is an 18 ⌀ outline circle.
struct WeekdayGlyphRow: View {
    let strip: SignalStrip

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            HStack(spacing: Spacing.s) {
                IdentityIcon(strip.kind.glyphSignal, size: Metrics.glyphHeader)
                Text(strip.kind.label)
                    .font(Typography.rowLabel)
                    .foregroundStyle(Ink.primary)
                Spacer(minLength: Spacing.s)
                Text(strip.summary.sentenceCased)
                    .font(Typography.status)
                    .foregroundStyle(strip.kind.statusColor)
            }
            HStack(spacing: 0) {
                ForEach(strip.beads, id: \.date) { bead in
                    column(bead)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(strip.kind.label) weekday averages: \(strip.summary)")
    }

    private func column(_ bead: SignalBead) -> some View {
        VStack(spacing: Spacing.xs) {
            ZStack {
                if let level = bead.level {
                    SignalGlyph(strip.kind.glyphSignal, level: level.numericValue, size: Metrics.glyphTile, decorative: true)
                } else {
                    Circle()
                        .strokeBorder(Stroke.empty, lineWidth: 1.33)
                        .frame(width: 18, height: 18)
                }
            }
            .frame(width: Metrics.glyphTile, height: Metrics.glyphTile)
            Text(bead.weekdayLabel ?? "")
                .font(Typography.captionMedium)
                .foregroundStyle(Ink.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(columnLabel(bead))
    }

    private func columnLabel(_ bead: SignalBead) -> String {
        let day = bead.weekdayLabel ?? ""
        return bead.level.map { "\(day): \($0.displayLabel)" } ?? "\(day): no data"
    }
}

#Preview {
    let slots: [(Int, String)] = [(2, "Mo"), (3, "Tu"), (4, "We"), (5, "Th"), (6, "Fr"), (7, "Sa"), (1, "Su")]
    let strips: [SignalStrip] = SignalKind.allCases.map { kind in
        let beads = slots.enumerated().map { index, slot -> SignalBead in
            let level: (any SignalLevel)? = switch kind {
            case .mood: MoodLevel.allCases[(index + 1) % 5]
            case .energy: EnergyLevel.allCases[(index + 2) % 5]
            case .focus: FocusLevel.allCases[(index + 3) % 5]
            }
            return SignalBead(date: Date(timeIntervalSinceReferenceDate: Double(slot.0)),
                              level: index == 6 ? nil : level, recordingID: nil, weekdayLabel: slot.1)
        }
        return SignalStrip(kind: kind, beads: beads, summary: "mostly Okay")
    }
    WeekdayGlyphRows(strips: strips)
        .padding(Spacing.gutter)
}
