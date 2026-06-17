import SwiftUI

/// Three horizontal bead strips — one per signal (mood/energy/focus).
/// Each bead is one check-in day, in chronological order. Tapping a bead
/// triggers `onBeadTap` with the day's date so the caller can open DayDetailSheet.
struct SignalStripsView: View {
    let strips: [SignalStrip]
    let onBeadTap: (Date) -> Void

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
    let onBeadTap: (Date) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                SignalGlyph(strip.kind.glyphSignal, level: 4, size: 18, decorative: true)
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

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: Spacing.xs) {
                    ForEach(strip.beads, id: \.date) { bead in
                        BeadButton(bead: bead) { onBeadTap(bead.date) }
                    }
                }
                .padding(.horizontal, Spacing.l)
                .padding(.vertical, 4)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(strip.kind.label) strip: \(strip.beads.count) check-in\(strip.beads.count == 1 ? "" : "s"), \(strip.summary)")
    }
}

private struct BeadButton: View {
    let bead: SignalBead
    let action: () -> Void

    private let beadSize: CGFloat = 28
    private let hitSize: CGFloat = 44

    var body: some View {
        Button(action: action) {
            beadShape
                .frame(width: hitSize, height: hitSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(beadA11yLabel)
    }

    @ViewBuilder
    private var beadShape: some View {
        if let level = bead.level {
            Circle()
                .fill(level.fillGradient)
                .frame(width: beadSize, height: beadSize)
        } else {
            Circle()
                .strokeBorder(Theme.textSecondary.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
                .frame(width: beadSize, height: beadSize)
        }
    }

    private var beadA11yLabel: String {
        let dateLabel = DateFormatter.localizedString(from: bead.date, dateStyle: .short, timeStyle: .none)
        if let level = bead.level {
            return "\(dateLabel): \(level.displayLabel)"
        }
        return "\(dateLabel): no data"
    }
}

#Preview {
    let cal = Calendar.current
    let strips: [SignalStrip] = SignalKind.allCases.map { kind in
        let beads = (1...12).map { day -> SignalBead in
            let date = cal.date(from: DateComponents(year: 2025, month: 6, day: day))!
            let level: (any SignalLevel)? = switch kind {
            case .mood:   day % 3 == 0 ? nil : MoodLevel(name: ["okay", "good", "great"][day % 3])
            case .energy: EnergyLevel(rawValue: ["steady", "alert", "charged"][day % 3])
            case .focus:  FocusLevel(rawValue: ["present", "sharp", "lockedIn"][day % 3])
            }
            return SignalBead(date: date, level: level, recordingID: nil)
        }
        return SignalStrip(kind: kind, beads: beads, summary: "mostly \(kind.label.lowercased())")
    }
    SignalStripsView(strips: strips, onBeadTap: { _ in })
        .padding(.vertical)
}
