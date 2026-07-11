import SwiftUI

/// Three fixed-slot strips — one per signal (mood/energy/focus).
/// In weekday-average mode each strip shows 7 Mo–Su slots coloured by the averaged level.
/// In date mode each slot is one check-in day; provide `onBeadTap` to make slots interactive.
struct SignalStripsView: View {
    let strips: [SignalStrip]
    var onBeadTap: ((Date) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            ForEach(strips, id: \.kind) { strip in
                StripRow(strip: strip, onBeadTap: onBeadTap)
            }
        }
        .accessibilityElement(children: .contain)
    }
}

private struct StripRow: View {
    let strip: SignalStrip
    let onBeadTap: ((Date) -> Void)?

    private var representativeLevel: Int {
        let levels = strip.beads.compactMap { $0.level?.numericValue }
        guard !levels.isEmpty else { return 3 }
        let counts = Dictionary(grouping: levels, by: { $0 }).mapValues(\.count)
        return counts.max { $0.value < $1.value }?.key ?? 3
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                SignalGlyph(strip.kind.glyphSignal, level: representativeLevel, size: 18, decorative: true)
                Text(strip.kind.label)
                    .font(Typography.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text(strip.summary)
                    .font(Typography.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, Spacing.l)

            HStack(spacing: 0) {
                ForEach(strip.beads, id: \.date) { bead in
                    BeadSlot(
                        bead: bead,
                        glyphSignal: strip.kind.glyphSignal,
                        action: onBeadTap.map { tap in { tap(bead.date) } }
                    )
                }
            }
            .padding(.horizontal, Spacing.l)
            .padding(.vertical, Spacing.xs)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(stripA11yLabel)
    }

    private var stripA11yLabel: String {
        let isWeekday = strip.beads.first?.weekdayLabel != nil
        if isWeekday {
            return "\(strip.kind.label) weekday averages: \(strip.summary)"
        }
        let n = strip.beads.count
        return "\(strip.kind.label) strip: \(n) check-in\(n == 1 ? "" : "s"), \(strip.summary)"
    }
}

private struct BeadSlot: View {
    let bead: SignalBead
    let glyphSignal: GlyphSignal
    let action: (() -> Void)?

    var body: some View {
        Group {
            if let action {
                Button(action: action) { content }
                    .buttonStyle(.plain)
            } else {
                content
            }
        }
        .accessibilityLabel(beadA11yLabel)
    }

    private var content: some View {
        VStack(spacing: Spacing.xs) {
            SignalGlyph(glyphSignal, level: bead.level?.numericValue, size: 28, decorative: true)
            if let label = bead.weekdayLabel {
                Text(label)
                    .font(Typography.text(9, weight: .medium, relativeTo: .caption1))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44)
    }

    private var beadA11yLabel: String {
        if let label = bead.weekdayLabel {
            return bead.level.map { "\(label): \($0.displayLabel)" } ?? "\(label): no data"
        }
        let dateLabel = DateFormatter.localizedString(from: bead.date, dateStyle: .short, timeStyle: .none)
        return bead.level.map { "\(dateLabel): \($0.displayLabel)" } ?? "\(dateLabel): no data"
    }
}

#Preview("Weekday average strips") {
    let slots: [(Int, String)] = [(2,"Mo"),(3,"Tu"),(4,"We"),(5,"Th"),(6,"Fr"),(7,"Sa"),(1,"Su")]
    let strips: [SignalStrip] = SignalKind.allCases.map { kind in
        let beads = slots.enumerated().map { (i, slot) -> SignalBead in
            let (weekday, label) = slot
            let baseLevel: (any SignalLevel)? = switch kind {
            case .mood:   MoodLevel(name: ["okay", "good", "great"][i % 3])
            case .energy: EnergyLevel(rawValue: ["steady", "alert", "charged"][i % 3])
            case .focus:  FocusLevel(rawValue: ["present", "sharp", "lockedIn"][i % 3])
            }
            let level: (any SignalLevel)? = i % 4 == 0 ? nil : baseLevel
            return SignalBead(
                date: Date(timeIntervalSinceReferenceDate: Double(weekday)),
                level: level,
                recordingID: nil,
                weekdayLabel: label
            )
        }
        return SignalStrip(kind: kind, beads: beads, summary: "mostly good")
    }
    SignalStripsView(strips: strips)
        .padding(.vertical)
}
