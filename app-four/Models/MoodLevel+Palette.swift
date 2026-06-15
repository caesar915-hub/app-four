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
extension MoodLevel {

    /// Build from a recording's raw mood string (case-insensitive), or nil.
    init?(name: String?) {
        guard let name else { return nil }
        self.init(rawValue: name.lowercased())
    }

    /// Meadow·Burnt base — saturated valence colour (burnt-orange→amber→green). The dark end of every fill.
    var color: Color {
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
    var gradientPartner: Color {
        switch self {
        case .low:   Color(hex: "#EA9248")
        case .flat:  Color(hex: "#FDC06C")
        case .okay:  Color(hex: "#B9DB9C")
        case .good:  Color(hex: "#7EC38A")
        case .great: Color(hex: "#459B6B")
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
