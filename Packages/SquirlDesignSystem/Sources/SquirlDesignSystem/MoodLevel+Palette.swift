import SwiftUI

/// The app-wide mood palette (DESIGN.md §4.4), as the pen draws it: one chart ramp (bubbles,
/// legend dots, range bars, mini bars) plus per-level word, avatar, day-card and tile-ring
/// tints. Levels 3–4 were not drawn for the tints; their values are mixes of the ramp colour
/// toward the surface and are marked derived. Dark pairs are the same mixes toward the dark card.
public extension MoodLevel {

    /// Chart ramp — `#da7a2a · #eda94a · #9dcca2 · #55a75d · #2a9134`. Static across appearances.
    public var color: Color {
        switch self {
        case .low:   Color(hex: "#DA7A2A")
        case .flat:  Color(hex: "#EDA94A")
        case .okay:  Color(hex: "#9DCCA2")
        case .good:  Color(hex: "#55A75D")
        case .great: Color(hex: "#2A9134")
        }
    }

    /// Lighter partner of the ramp colour (35 % toward white) — gradient light ends, flat beads.
    public var gradientPartner: Color {
        switch self {
        case .low:   Color(hex: "#E7A975")
        case .flat:  Color(hex: "#F3C789")
        case .okay:  Color(hex: "#BFDEC3")
        case .good:  Color(hex: "#90C696")
        case .great: Color(hex: "#75B87B")
        }
    }

    public var fill: Color { gradientPartner }
    public var deepFill: Color { color }

    /// Pre-057 tints (spec 019) — kept for the folded day card until UI-25 replaces them with
    /// `avatarTint` / `dayCardFill`.
    public var blockTint: Color { color.opacity(Opacity.moodBlock) }
    public var badgeTint: Color { color.opacity(Opacity.moodBadge) }

    /// The mood word ("Great", "Low"). Light: the pen's word colours, with flat darkened so it
    /// clears AA on its card (`#da7a2a` is 3.0:1). Dark: the ramp partners (≥ 5:1 on the tints).
    public var wordColor: Color {
        switch self {
        case .low:   Color(lightHex: "#842626", darkHex: "#E7A975")
        case .flat:  Color(lightHex: "#8A5600", darkHex: "#F3C789")
        case .okay:  Color(lightHex: "#1E6725", darkHex: "#BFDEC3")
        case .good:  Color(lightHex: "#1B5E23", darkHex: "#90C696") // derived
        case .great: Color(lightHex: "#17501D", darkHex: "#75B87B")
        }
    }

    /// 44 ⌀ avatar tint behind the sprout on journal rows and previous-day cards.
    public var avatarTint: Color {
        switch self {
        case .low:   Color(lightHex: "#F4DDDD", darkHex: "#46321D")
        case .flat:  Color(lightHex: "#FEE8D1", darkHex: "#4A3D24")
        case .okay:  Color(lightHex: "#E5F7E5", darkHex: "#384437")
        case .good:  Color(lightHex: "#DDEDDF", darkHex: "#293C28") // derived
        case .great: Color(lightHex: "#DDF4DE", darkHex: "#1F371F")
        }
    }

    /// Collapsed day-card fill.
    public var dayCardFill: Color {
        switch self {
        case .low:   Color(lightHex: "#FFFDFD", darkHex: "#22201D")
        case .flat:  Color(lightHex: "#FEFDFA", darkHex: "#22211C")
        case .okay:  Color(lightHex: "#FCFDFC", darkHex: "#1E211E") // derived
        case .good:  Color(lightHex: "#F9FCF9", darkHex: "#1C211C") // derived
        case .great: Color(lightHex: "#F8FFFC", darkHex: "#1A221B")
        }
    }

    /// Collapsed day-card stroke (drawn at 0.5 opacity in the pen).
    public var dayCardStroke: Color {
        switch self {
        case .low:   Color(lightHex: "#F3B09A", darkHex: "#724721")
        case .flat:  Color(lightHex: "#F6CC8A", darkHex: "#7A5D2F")
        case .okay:  Color(lightHex: "#C9E3CC", darkHex: "#566C57") // derived
        case .good:  Color(lightHex: "#A2CFA6", darkHex: "#365C38") // derived
        case .great: Color(lightHex: "#ABBBA3", darkHex: "#225225")
        }
    }

    /// Level-tile selected ring tint (D-E2 — the selected treatment adds a green-600 stroke).
    public var tileRing: Color {
        switch self {
        case .low:   Color(lightHex: "#F3B09A", darkHex: "#724721")
        case .flat:  Color(lightHex: "#F6CC8A", darkHex: "#7A5D2F")
        case .okay:  Color(lightHex: "#B6D9B9", darkHex: "#566C57") // derived
        case .good:  Color(lightHex: "#80BD86", darkHex: "#365C38") // derived
        case .great: Color(lightHex: "#70B577", darkHex: "#225225")
        }
    }

    /// Bubble-chart fill — the ramp colour, except the great bubble, which carries a white label
    /// and so takes green-600 (D14: white on green-500 is 4.04:1, on green-600 4.75:1).
    public var bubbleFill: Color {
        self == .great ? Color(hex: "#26842F") : color
    }

    /// Ink on the bubble of this level — dark on 1–4, white only on the great bubble.
    public var bubbleInk: Color {
        self == .great ? Color(hex: "#FFFFFF") : Color(hex: "#1C1B1F")
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

    /// Dark ink for text on the light ramp partners (fixed — the partners do not adapt).
    public static let onColor = Color(hex: "#1C1B1F")

    /// Rounded half-up average deep shade of several moods, for the day header.
    public static func averageDeep(of moods: [String?]) -> Color? { average(of: moods)?.deepFill }
}
