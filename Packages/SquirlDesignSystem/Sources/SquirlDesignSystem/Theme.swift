import SwiftUI

/// **Retired (spec 057).** The Paper & Pollen semantic survivors, each now an alias of the
/// pen-derived token it maps to. UI-49 deletes this file once the last consumer has moved.
public enum Theme {
    /// Was the bronze link/focus accent — now green text.
    public static let accent = Accent.primaryText
    /// Was `#5F8A4C` — now the text-carrying green fill.
    public static let meadowGreen = Accent.primaryFill
    /// Was `#E0A33A` — now the energy amber (decorative only).
    public static let meadowAmber = Accent.energyAmber

    public static let statusDone = Accent.primaryText
    public static let statusInProgress = Accent.energyText
    /// Was a warm clay — now the single destructive ink (D-C10).
    public static let danger = Ink.destructive

    /// Was green → amber; filled controls are solid green-600 now, so this is a flat green pair.
    public static var meadowGradient: LinearGradient {
        LinearGradient(colors: [Accent.primaryFill, Accent.primaryFill],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
