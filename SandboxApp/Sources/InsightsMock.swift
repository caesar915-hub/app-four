import SwiftUI
import SquirlDesignSystem

/// Insights re-composed from package atoms + mock data: mood breakdown bubbles, the three
/// signal strips, the average gauges, and a connection card. Pure values, no services.
struct SandboxInsights: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 34) {
                breakdown
                strips
                gauges
                connection
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.background.ignoresSafeArea())
    }

    private func head(_ t: String, _ s: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(t).font(Typography.title).foregroundStyle(Theme.textPrimary)
            if let s { Text(s).font(Typography.callout).foregroundStyle(Theme.textSecondary) }
        }
    }

    // MARK: Breakdown — mood bubbles

    private let moodCounts: [(MoodLevel, Int)] = [(.low, 1), (.flat, 1), (.okay, 3), (.good, 3), (.great, 2)]

    private var breakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            head("Your month in mood", "\(moodCounts.reduce(0) { $0 + $1.1 }) check-ins")
            GeometryReader { geo in
                let total = Double(moodCounts.reduce(0) { $0 + $1.1 })
                let maxFrac = (moodCounts.map { Double($0.1) }.max() ?? 1) / total
                ZStack {
                    ForEach(moodCounts, id: \.0) { level, count in
                        let frac = Double(count) / total
                        let d = 44 + (116 - 44) * (frac / maxFrac).squareRoot()
                        let n = Double(level.numericValue)
                        Circle().fill(level.bubbleFill).frame(width: d, height: d)
                            .overlay(Text("\(Int((frac * 100).rounded()))%").font(Typography.caption).bold()
                                .foregroundStyle(Color.contrastingInk(for: level.color, in: .light)))
                            .position(x: (n - 0.5) / 5 * geo.size.width, y: geo.size.height / 2 - (n - 3) * 13)
                    }
                }
            }
            .frame(height: 160)
            HStack(spacing: 10) {
                ForEach(moodCounts, id: \.0) { level, count in
                    HStack(spacing: 4) {
                        Circle().fill(level.fillGradient).frame(width: 10, height: 10)
                        Text("\(level.displayLabel) (\(count))").font(Typography.caption).foregroundStyle(Theme.textSecondary)
                    }
                }
            }
        }
    }

    // MARK: Signal strips

    private var strips: some View {
        VStack(alignment: .leading, spacing: 14) {
            head("Three signals", "Each bead is one check-in day")
            strip(.mood, "Mood", [3, 5, 4, 2, 3, 3, 4, 3].map(MoodLevel.from), "mostly okay")
            strip(.energy, "Energy", [3, 5, 4, 2, 3, 3, 4, 2].map(EnergyLevel.from), "steady")
            strip(.focus, "Focus", [3, 5, 4, 2, nil, 3, 4, 5].map { $0.flatMap(FocusLevel.from) }, "sharper lately")
            HStack(spacing: 4) {
                SignalGlyph(.sleep, size: 15)
                Text("Sleep · not tracked yet").font(Typography.caption).foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .overlay(Capsule().strokeBorder(Theme.separator, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
        }
    }

    private func strip<L: SignalLevel>(_ kind: GlyphSignal, _ name: String, _ beads: [L?], _ summary: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                SignalGlyph(kind, level: 3, size: 18, decorative: true)
                Text(name).font(Typography.subheadline)
                Spacer()
                Text(summary).font(Typography.caption).foregroundStyle(Theme.textSecondary)
            }
            HStack(spacing: 5) {
                ForEach(Array(beads.enumerated()), id: \.offset) { _, lvl in
                    if let lvl {
                        Circle().fill(lvl.fillGradient).frame(width: 26, height: 26)
                    } else {
                        Circle().strokeBorder(Theme.textSecondary.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
                            .frame(width: 26, height: 26)
                    }
                }
            }
        }
    }

    // MARK: Average gauges

    private var gauges: some View {
        VStack(alignment: .leading, spacing: 12) {
            head("Where you averaged")
            HStack(alignment: .bottom, spacing: 16) {
                gauge(.mood, MoodLevel.good, 0.64, "Okay+")
                gauge(.energy, EnergyLevel.steady, 0.58, "Steady")
                gauge(.focus, FocusLevel.sharp, 0.68, "Sharp")
            }
        }
    }

    private func gauge<L: SignalLevel>(_ kind: GlyphSignal, _ level: L, _ frac: CGFloat, _ label: String) -> some View {
        VStack(spacing: 8) {
            SignalGlyph(kind, level: level.numericValue, size: 26, decorative: true)
            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 10).fill(Theme.cardBackground)
                    RoundedRectangle(cornerRadius: 10).fill(level.fillGradient)
                        .frame(height: geo.size.height * frac)
                        .overlay(alignment: .top) {
                            Text(label).font(Typography.caption).bold()
                                .foregroundStyle(Color.contrastingInk(for: level.color, in: .light))
                                .padding(.top, 6)
                        }
                }
            }
            .frame(height: 200)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Connection

    private var connection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Medication × focus").cardEyebrow()
            Text("On medication days, sharp focus appeared 75% of the time.")
                .font(Typography.title).foregroundStyle(Theme.textPrimary)
            Capsule().fill(Theme.separator).frame(height: 8)
                .overlay(alignment: .leading) { Capsule().fill(Theme.accent).frame(width: 180 * 0.75, height: 8) }
            HStack {
                Text("Med days").font(Typography.caption).foregroundStyle(Theme.textSecondary)
                Spacer()
                Text("75%").font(Typography.caption).bold().foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("Sharp+ focus").font(Typography.caption).foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

private extension MoodLevel { static func from(_ n: Int) -> MoodLevel? { allCases.first { $0.numericValue == n } } }
private extension EnergyLevel { static func from(_ n: Int) -> EnergyLevel? { allCases.first { $0.numericValue == n } } }
private extension FocusLevel { static func from(_ n: Int) -> FocusLevel? { allCases.first { $0.numericValue == n } } }
