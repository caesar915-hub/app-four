import SwiftUI

/// The circular "bead" for one timeline node: the mood glyph on a soft mood disc (recording) or a
/// hollow (med-only / neutral) centre. The time moved out to the row head (spec 019); the bead now
/// carries the mood glyph + the medication-phase ring.
///
/// A dose still active from earlier (carry-over) draws its purple effect ring
/// just *inside* the circle's edge, and its percentage in a small badge whose
/// lower edge is flush with the circle's lower edge. A dose taken *at* this
/// check-in shows as a "Taken …" pill in the row content (see `TimelineRow`).
struct TimelineBead: View {
    let node: DayTimeline.Node

    private let beadSize: CGFloat = Metrics.timeBead + 2
    private let circleSize: CGFloat = Metrics.timeBead    // the mood/time circle (fills the bead bar a hair)
    private let ringWidth: CGFloat = Spacing.ringStroke

    /// Diameter of the effect ring — sits just inside the circle's edge.
    private var ringDiameter: CGFloat { circleSize - ringWidth }
    /// y to slide the badge up so its bottom edge meets the circle's bottom edge.
    private var badgeOffsetY: CGFloat { -(beadSize - circleSize) / 2 }

    var body: some View {
        ZStack {
            centre
                .frame(width: circleSize, height: circleSize)
            if let ring = carryoverRing {
                ringArc(ring)
            }
        }
        .frame(width: beadSize, height: beadSize)
        .overlay(alignment: .bottom) { carryoverBadge }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Centre

    @ViewBuilder
    private var centre: some View {
        if node.recording != nil {
            ZStack {
                Circle().fill(MoodLevel(name: node.recording?.mood)?.badgeTint ?? Color(.systemGray5))
                SignalGlyph(.mood, level: MoodLevel(name: node.recording?.mood)?.numericValue,
                            size: circleSize * 0.6, decorative: true)
            }
        } else {
            Circle()
                .fill(NewLook.screen)
                .overlay(Circle().strokeBorder(NewLook.hairline, lineWidth: 1))
        }
    }

    // MARK: - Effect ring (flat purple, inside the circle's edge)

    private func ringArc(_ ring: DayTimeline.Ring) -> some View {
        Circle()
            .trim(from: 0, to: max(0.001, ring.progress))   // tiny purple dot at 0%
            .stroke(Palette.medication, style: StrokeStyle(lineWidth: ringWidth, lineCap: .round))
            .rotationEffect(.degrees(-90))                   // start at 12 o'clock
            .frame(width: ringDiameter, height: ringDiameter)
    }

    // MARK: - Carry-over badge (lower edge flush with the circle)

    /// The oldest dose still active here that was *not* taken at this instant.
    private var carryoverRing: DayTimeline.Ring? {
        let fresh = Set(node.intakeDoses.map(\.id))
        return node.rings.first { !fresh.contains($0.doseID) }
    }

    @ViewBuilder
    private var carryoverBadge: some View {
        if let ring = carryoverRing {
            Text("\(Int(ring.progress * 100))%")
                .font(Typography.mono(10, weight: .heavy))
                .foregroundStyle(Palette.medication)   // systemPurple brightens in dark mode
                .padding(.horizontal, Spacing.xs + 2)
                .padding(.vertical, 1)
                .background(NewLook.card, in: .capsule)
                .overlay(Capsule().strokeBorder(NewLook.hairline.opacity(0.3), lineWidth: 0.5))
                .fixedSize()
                .offset(y: badgeOffsetY)
        }
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        let time = node.time.formatted(.dateTime.hour().minute(.twoDigits))
        var parts: [String] = ["\(time) check-in"]
        if let title = node.recording?.title { parts.append(title) }
        if node.recording == nil, let dose = node.intakeDoses.first {
            parts.append(dose.dose.map { "\(dose.name) \($0)" } ?? dose.name)
        }
        if let ring = carryoverRing {
            parts.append("medication \(Int(ring.progress * 100)) percent")
        }
        return parts.joined(separator: ", ")
    }
}

#Preview("Beads") {
    func node(mood: String?, rings: [Double]) -> DayTimeline.Node {
        let r = mood.map { Recording(audioFileName: "p.m4a", duration: 0, title: "Mood", mood: $0) }
        return DayTimeline.Node(
            id: UUID().uuidString,
            time: Date(),
            recording: r,
            intakeDoses: [],
            rings: rings.map { DayTimeline.Ring(doseID: UUID(), progress: $0, name: "Concerta", dose: "36mg") }
        )
    }
    return VStack(spacing: 20) {
        TimelineBead(node: node(mood: "great", rings: []))
        TimelineBead(node: node(mood: "great", rings: [0.9]))
        TimelineBead(node: node(mood: "low", rings: [0.4]))
        TimelineBead(node: node(mood: nil, rings: [0.0]))
    }
    .padding()
}
