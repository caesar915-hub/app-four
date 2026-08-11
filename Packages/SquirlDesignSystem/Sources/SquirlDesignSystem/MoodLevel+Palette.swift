import SwiftUI

/// Calendar + Insights display palette for the extracted ``MoodLevel`` (defined in
/// NoteExtraction). The **app-wide mood SSOT**: the Meadow·Burnt valence ramp
/// (low→great = burnt-orange→amber→green). Calendar timeline, mood library, recording
/// detail, and Insights all read it, so re-coloring here re-colors the whole app.
///
/// Two ends per level:
/// - ``color`` / ``deepFill`` — the saturated **base** (deep shade): header text, accents,
///   the dark end of Insights gradients, and legend dots.
/// - ``gradientPartner`` / ``fill`` — the **light partner**: flat bead/banner surfaces paired
///   with the fixed dark ``onColor`` ink, and the light end of Insights gradients.
public extension MoodLevel {

    /// Build from a recording's raw mood string (case-insensitive), or nil.
    public init?(name: String?) {
        guard let name else { return nil }
        self.init(rawValue: name.lowercased())
    }

    /// Meadow·Burnt base — saturated valence colour (burnt-orange→amber→green). The dark end of every fill.
    public var color: Color {
        switch self {
        case .low:   Color(hex: "#DA7A2A")
        case .flat:  Color(hex: "#EDA94A")
        case .okay:  Color(hex: "#9FCB79")
        case .good:  Color(hex: "#5FB36E")
        case .great: Color(hex: "#2E8B57")
        }
    }

    /// Meadow·Burnt light partner — the light end of every fill, and the flat calendar bead/banner
    /// surface (kept light so the fixed dark ``onColor`` ink stays legible).
    public var gradientPartner: Color {
        switch self {
        case .low:   Color(hex: "#EA9248")
        case .flat:  Color(hex: "#FDC06C")
        case .okay:  Color(hex: "#B9DB9C")
        case .good:  Color(hex: "#7EC38A")
        case .great: Color(hex: "#459B6B")
        }
    }

    /// Soft fill for banners and beads — paired with the dark ``onColor`` ink.
    public var fill: Color { gradientPartner }

    /// Deeper, legible shade of the same hue — used for the day header text.
    public var deepFill: Color { color }

    /// Day-card mood-block tint (spec 019, "#4 Divided · Cream disc"): the representative-mood base
    /// colour at `Opacity.moodBlock`, filling the folded card and the open-state strip header.
    public var blockTint: Color { color.opacity(Opacity.moodBlock) }
    /// Cream-disc mood badge behind the mood glyph (folded header + check-in bead).
    public var badgeTint: Color { color.opacity(Opacity.moodBadge) }
    /// Mood-word colour on the block tint — a deeper, AA-legible shade, per appearance.
    /// Decoupled from ``deepFill`` (which stays the saturated base for marker dots and gradient
    /// ends): in **light** the hue is darkened to clear WCAG AA 4.5:1 on the 0.24 block tint over
    /// the cream card; in **dark** the burnt-orange/green ramp ends are brightened to clear 4.5:1
    /// on the tint over loam. All five levels measure ≥4.9:1 light / ≥5.0:1 dark. (Design-review
    /// finding ①: the old `wordColor = deepFill = color` washed out to as low as 1.54:1 in light.)
    public var wordColor: Color {
        switch self {
        case .low:   Color(lightHex: "#8E470F", darkHex: "#E89A5A")
        case .flat:  Color(lightHex: "#8A5600", darkHex: "#EDA94A")
        case .okay:  Color(lightHex: "#41691F", darkHex: "#B7D897")
        case .good:  Color(lightHex: "#2C6B3B", darkHex: "#79C98E")
        case .great: Color(lightHex: "#1E5C38", darkHex: "#57C98A")
        }
    }

    public var displayLabel: String {
        switch self {
        case .low:   "Low"
        case .flat:  "Flat"
        case .okay:  "Okay"
        case .good:  "Good"
        case .great: "Great"
        }
    }

    /// Dark ink for text/icons on the light fills. Fixed (the fills don't adapt to dark
    /// mode, so the ink stays dark) — a justified exception to the "semantic colours only"
    /// rule, the mood palette itself being custom.
    public static let onColor = Color(hex: "#1C1C1E")

    private init?(numericValue: Int) {
        switch numericValue {
        case 1: self = .low
        case 2: self = .flat
        case 3: self = .okay
        case 4: self = .good
        case 5: self = .great
        default: return nil
        }
    }

    private static func average(_ moods: [String?]) -> MoodLevel? {
        let values = moods.compactMap { MoodLevel(name: $0)?.numericValue }
        guard !values.isEmpty else { return nil }
        let mean = (Double(values.reduce(0, +)) / Double(values.count)).rounded(.up)
        return MoodLevel(numericValue: Int(mean))
    }

    /// Rounded-up average mood level, or nil when no resolvable moods are provided.
    public static func average(of moods: [String?]) -> MoodLevel? { average(moods) }

    /// Rounded-up average deep shade of several moods, for the day header.
    public static func averageDeep(of moods: [String?]) -> Color? { average(moods)?.deepFill }
}
