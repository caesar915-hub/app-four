import SwiftUI
import UIKit

/// Squirl typography — native SF (D1: the pen's Inter ramp mapped 1:1 by size and weight).
/// Every role scales with Dynamic Type via `UIFontMetrics` relative to a text style. Role names
/// are DESIGN.md §5.2 verbatim; the pre-057 role names below stay as aliases until every call
/// site has migrated (UI-49 deletes them) — an alias never changes a call site's metrics.
public enum Typography {

    private static func sf(_ size: CGFloat, _ weight: UIFont.Weight, _ style: UIFont.TextStyle, mono: Bool = false) -> Font {
        let base = mono
            ? UIFont.monospacedSystemFont(ofSize: size, weight: weight)
            : UIFont.systemFont(ofSize: size, weight: weight)
        return Font(UIFontMetrics(forTextStyle: style).scaledFont(for: base))
    }

    // MARK: Titles
    /// "Insights", "Settings", "How do you feel?", "Check-in saved" — 34/600.
    public static let pageTitle: Font = sf(34, .semibold, .largeTitle)
    /// Under a page title — 16/500.
    public static let pageSubtitle: Font = sf(16, .medium, .body)
    /// Nav-bar title beside the back pill — 18/600.
    public static let navTitle: Font = sf(18, .semibold, .title3)
    /// Nav-bar subtitle (the date) — 12/500.
    public static let navSubtitle: Font = sf(12, .medium, .caption1)
    /// Listening prompt title — 24/500.
    public static let promptTitle: Font = sf(24, .medium, .title2)
    /// Listening prompt subtitle — 12/500.
    public static let promptSubtitle: Font = sf(12, .medium, .caption1)
    /// On-page question ("How do you feel today?") — 20/600.
    public static let question: Font = sf(20, .semibold, .title3)
    /// Section titles on the ground and card titles — 16/600.
    public static let sectionTitle: Font = sf(16, .semibold, .headline)
    public static let cardTitle: Font = sf(16, .semibold, .headline)
    /// Card subtitle / description — 14/400.
    public static let cardSubtitle: Font = sf(14, .regular, .subheadline)

    // MARK: Rows and body
    /// Row label — 14/500.
    public static let rowLabel: Font = sf(14, .medium, .subheadline)
    /// Strong row title, times — 14/600.
    public static let rowTitle: Font = sf(14, .semibold, .subheadline)
    /// Journal entry title (the mood word) — 14/600.
    public static let entryTitle: Font = sf(14, .semibold, .subheadline)
    /// The AI narrative and any long-form body — 16/400 (D-T2: the pen's 12 pt is refused).
    public static let narrative: Font = sf(16, .regular, .body)
    /// Emphasised body — 12/500.
    public static let bodyEmphasis: Font = sf(12, .medium, .caption1)

    // MARK: Captions
    /// Pen caption with weight — 12/500 (medication name, counts, weekday letters).
    /// Named `captionMedium` while the pre-057 `caption` (12/400) still has call sites;
    /// UI-49 renames it to `caption` once those sites migrate.
    public static let captionMedium: Font = sf(12, .medium, .caption1)
    /// Quiet caption — 12/400 (range labels, "Low"/"High", the AI byline).
    public static let captionQuiet: Font = sf(12, .regular, .caption1)
    /// Chip label — 12/500.
    public static let chipLabel: Font = sf(12, .medium, .caption1)
    /// Status / value word — 12/600 ("Active", "Charged", "MEDICATION × FOCUS").
    public static let status: Font = sf(12, .semibold, .caption1)
    /// Micro captions — 11/500 (rhythm captions). Nothing ships below 11 pt.
    public static let micro: Font = sf(11, .medium, .caption2)

    // MARK: Controls
    public static let buttonSmall: Font = sf(14, .medium, .subheadline)
    public static let buttonMedium: Font = sf(16, .medium, .body)
    public static let buttonLarge: Font = sf(18, .medium, .title3)
    public static let tabLabel: Font = sf(12, .medium, .caption1)
    public static let bubbleValue: Font = sf(14, .medium, .subheadline)
    public static let bubbleWord: Font = sf(12, .medium, .caption1)
    public static let stripDay: Font = sf(12, .medium, .caption1)
    public static let stripNumber: Font = sf(12, .semibold, .caption1)
    public static let segmentLabel: Font = sf(12, .medium, .caption1)
    /// The recording timer — 72/500 with tabular digits, capped by the caller so it stays in the disc.
    public static let timerHero: Font = sf(72, .medium, .largeTitle).monospacedDigit()

    // MARK: Pre-057 roles (aliases — same metrics as before; migrate, then UI-49 deletes)
    public static let display: Font = pageTitle
    public static let largeTitle: Font = pageTitle
    /// 22/600 → the pen's 20/600 question (reviewed in the B1 screenshot pack).
    public static let title: Font = question
    public static let headline: Font = sectionTitle
    public static let subheadline: Font = rowLabel
    public static let body: Font = narrative
    /// 15/400 → the pen's 14/400 card subtitle (reviewed in the B1 screenshot pack).
    public static let callout: Font = cardSubtitle
    /// 12/400 — unchanged; identical to `captionQuiet`.
    public static let caption: Font = captionQuiet
    /// 12/500 — identical to `captionMedium`.
    public static let label: Font = captionMedium
    /// Day-card mood word — keeps its 24/700 until the journal migrates (UI-25).
    public static let moodWord: Font = sf(24, .bold, .title2)
    /// Recording timer — keeps SF Mono 22 until the check-in migrates (UI-22).
    public static let timer: Font = sf(22, .medium, .title2, mono: true)
    public static let duration: Font = sf(12, .regular, .caption1, mono: true)
    public static let mono12: Font = sf(12, .regular, .caption1, mono: true)

    /// SF at an explicit size, scaled relative to `style`.
    public static func text(_ size: CGFloat, weight: UIFont.Weight = .regular, relativeTo style: UIFont.TextStyle = .body) -> Font {
        sf(size, weight, style)
    }
}
