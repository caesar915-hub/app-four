import SwiftUI

/// Text and icon inks (DESIGN.md §4.2). Contrast policy D14: every caption-size ink clears
/// WCAG AA on `Surface.screen` — grey-300 (5.16:1) replaces the pen's `#6f7f75` (4.19:1) and
/// the retired New Look `#8a8a8e` (3.44:1).
public enum Ink {
    /// Page and nav titles, the timer, "Great", the selected calendar disc — green-800 in light;
    /// green-200 in dark (9.3:1 on the dark card).
    public static let title = Color(lightHex: "#17501d", darkHex: "#9dcca2")
    /// Section titles, row titles, times, dates, chip labels on Insights (grey-500).
    public static let primary = Color(lightHex: "#212529", darkHex: "#f2f3ee")
    /// Captions with weight — medication name, counts, weekday letters, toggle labels (grey-400).
    public static let secondary = Color(lightHex: "#4d5154", darkHex: "#c5c8c3")
    /// Subtitles, descriptions, quiet captions, unselected segment labels (grey-300).
    public static let tertiary = Color(lightHex: "#6a6d70", darkHex: "#9ba09a")
    /// Nav subtitles and hint lines — the pen's green-grey `#6f7f75` retuned to grey-300 (D14).
    public static let nav = tertiary
    /// Chip label ink — the pen's green-black `#193024`.
    public static let chip = Color(lightHex: "#193024", darkHex: "#e6efe8")
    /// Label on a filled accent (button, selected chip, active tab pill).
    public static let onAccent = Color(lightHex: "#ffffff", darkHex: "#ffffff")
    /// Placeholder / de-emphasised caption ("Written by on-device AI…", rhythm "—").
    public static let placeholder = tertiary
    /// Inactive tab-bar icon — grey-300 (5.2:1) instead of the pen's grey-200 (2.8:1), D14.
    public static let tabInactive = tertiary
    /// The app's only destructive ink (Clear All Data, delete). Not drawn in the pen — D-C10.
    public static let destructive = Color(lightHex: "#d54037", darkHex: "#f07b72")
    /// The single pure-black ink the pen uses (Settings accessibility figure).
    public static let iconBlack = Color(lightHex: "#000000", darkHex: "#f2f3ee")
}
