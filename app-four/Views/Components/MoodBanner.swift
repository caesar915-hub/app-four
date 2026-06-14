import SwiftUI

/// The filled, mood-coloured headline for a timeline check-in: a full-width bar
/// holding mood · energy · focus on one line, each led by an SF Symbol
/// (sparkles / bolt / target), with dark ink on the pastel fill.
///
/// One uniform fixed size for the whole banner (no Dynamic Type, no per-entry
/// resize); a genuinely over-long combination truncates with an ellipsis rather
/// than shrinking, so every entry's text stays the same size.
struct MoodBanner: View {
    let mood: String?
    let energy: String?
    let focus: String?
    let fallbackTitle: String
    let fill: Color

    private let font = Font.system(size: 12, weight: .bold)

    var body: some View {
        bannerText
            .font(font)
            .lineLimit(1)
            .truncationMode(.tail)
            .foregroundStyle(MoodLevel.onColor)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 5)
            .padding(.horizontal, Spacing.m)
            .background(fill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .accessibilityElement()
            .accessibilityLabel(accessibilityLabel)
    }

    /// One uniform `Text` built via string interpolation (the icons inherit the
    /// banner font) — avoids the deprecated `Text + Text` concatenation.
    private var bannerText: Text {
        var interpolation = LocalizedStringKey.StringInterpolation(literalCapacity: 0, interpolationCount: 0)
        var hasContent = false
        func add(symbol: String, word: String) {
            if hasContent { interpolation.appendLiteral("  ") }
            interpolation.appendInterpolation(Image(systemName: symbol))
            interpolation.appendLiteral(" \(word.uppercased())")
            hasContent = true
        }
        if let mood, !mood.isEmpty { add(symbol: "sparkles", word: mood) }
        if let energy, !energy.isEmpty { add(symbol: "bolt.fill", word: energy) }
        if let focus, !focus.isEmpty { add(symbol: "target", word: focus) }
        guard hasContent else { return Text(fallbackTitle.uppercased()) }
        return Text(LocalizedStringKey(stringInterpolation: interpolation))
    }

    private var accessibilityLabel: String {
        let parts = [mood, energy, focus].compactMap { $0?.isEmpty == false ? $0 : nil }
        return parts.isEmpty ? fallbackTitle : parts.joined(separator: ", ")
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
