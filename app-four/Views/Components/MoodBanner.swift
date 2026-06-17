import SwiftUI

/// The filled, mood-coloured headline for a timeline check-in: a full-width bar holding
/// mood · energy · focus on one line, each led by its Paper & Pollen glyph (sprout /
/// lightning / aperture), with dark ink on the pastel fill.
///
/// One uniform fixed size for the whole banner (no Dynamic Type, no per-entry resize); a
/// genuinely over-long combination truncates rather than shrinking.
struct MoodBanner: View {
    let mood: String?
    let energy: String?
    let focus: String?
    let fallbackTitle: String
    let fill: Color

    private let glyphSize: CGFloat = 17

    var body: some View {
        content
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(MoodLevel.onColor)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 5)
            .padding(.horizontal, Spacing.m)
            .background(fill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .accessibilityElement()
            .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder private var content: some View {
        let items = signalItems
        if items.isEmpty {
            Text(fallbackTitle.uppercased()).lineLimit(1).truncationMode(.tail)
        } else {
            HStack(spacing: Spacing.s) {
                ForEach(items) { item in
                    HStack(spacing: 3) {
                        SignalGlyph(item.kind, level: item.level, size: glyphSize, decorative: true)
                        Text(item.word.uppercased()).lineLimit(1)
                    }
                }
            }
        }
    }

    private var signalItems: [BannerItem] {
        var items: [BannerItem] = []
        if let mood, !mood.isEmpty {
            items.append(.init(kind: .mood, level: MoodLevel(name: mood)?.numericValue, word: mood))
        }
        if let energy, !energy.isEmpty {
            items.append(.init(kind: .energy, level: EnergyLevel(rawValue: energy.lowercased())?.numericValue, word: energy))
        }
        if let focus, !focus.isEmpty {
            items.append(.init(kind: .focus, level: FocusLevel(rawValue: focus.lowercased())?.numericValue, word: focus))
        }
        return items
    }

    private var accessibilityLabel: String {
        let parts = [mood, energy, focus].compactMap { $0?.isEmpty == false ? $0 : nil }
        return parts.isEmpty ? fallbackTitle : parts.joined(separator: ", ")
    }

    private struct BannerItem: Identifiable {
        let kind: GlyphSignal
        let level: Int?
        let word: String
        var id: GlyphSignal { kind }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: Spacing.s) {
        MoodBanner(mood: "Great", energy: "Charged", focus: "Lockedin", fallbackTitle: "", fill: MoodLevel.great.fill)
        MoodBanner(mood: "Low", energy: nil, focus: nil, fallbackTitle: "", fill: MoodLevel.low.fill)
        MoodBanner(mood: "Okay", energy: nil, focus: "Sharp", fallbackTitle: "", fill: MoodLevel.okay.fill)
    }
    .padding()
    .frame(width: 260)
}
