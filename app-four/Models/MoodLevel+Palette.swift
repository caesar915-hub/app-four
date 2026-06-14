import SwiftUI

/// Calendar + Insights display palette for the extracted ``MoodLevel`` (defined in
/// NoteExtraction). The **app-wide mood SSOT**: the Meadow "M2" valence ramp
/// (low→great = red→amber→green). Calendar timeline, mood library, recording detail,
/// and Insights all read it, so re-coloring here re-colors the whole app.
///
/// Two ends per level:
/// - ``color`` / ``deepFill`` — the saturated **base** (deep shade): header text, accents,
///   the dark end of Insights gradients, and legend dots.
/// - ``gradientPartner`` / ``fill`` — the **light partner**: flat bead/banner surfaces paired
///   with the fixed dark ``onColor`` ink, and the light end of Insights gradients.
extension MoodLevel {

    /// Build from a recording's raw mood string (case-insensitive), or nil.
    init?(name: String?) {
        guard let name else { return nil }
        self.init(rawValue: name.lowercased())
    }

    /// M2 base — saturated valence colour (red→amber→green). The dark end of every fill.
    var color: Color {
        switch self {
        case .low:   Color(hex: "#C2503F")
        case .flat:  Color(hex: "#DE8050")
        case .okay:  Color(hex: "#E5C46A")
        case .good:  Color(hex: "#94C56F")
        case .great: Color(hex: "#4CAF6E")
        }
    }

    /// M2 light partner — the light end of every fill, and the flat calendar bead/banner
    /// surface (kept light so the fixed dark ``onColor`` ink stays legible).
    var gradientPartner: Color {
        switch self {
        case .low:   Color(hex: "#D4705F")
        case .flat:  Color(hex: "#EA9D72")
        case .okay:  Color(hex: "#EFD68C")
        case .good:  Color(hex: "#AED68C")
        case .great: Color(hex: "#6BC68A")
        }
    }

    /// Soft fill for banners and beads — paired with the dark ``onColor`` ink.
    var fill: Color { gradientPartner }

    /// Deeper, legible shade of the same hue — used for the day header text.
    var deepFill: Color { color }

    var displayLabel: String {
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
    static let onColor = Color(hex: "#1C1C1E")

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
        let mean = (Double(values.reduce(0, +)) / Double(values.count)).rounded()
        return MoodLevel(numericValue: Int(mean))
    }

    /// Rounded-average pastel fill of several moods, for the day-card tint.
    static func averageFill(of moods: [String?]) -> Color? { average(moods)?.fill }

    /// Rounded-average deep shade of several moods, for the day header.
    static func averageDeep(of moods: [String?]) -> Color? { average(moods)?.deepFill }
}
