import SwiftUI

/// Primitive colour namespace. The three pen ramps live in `Palette+Ramps`; the members below
/// are pre-057 semantic names kept as aliases of the pen tokens until their consumers migrate
/// (UI-49 deletes them). Views should reach for `Surface` / `Ink` / `Accent` / `Stroke`.
public enum Palette {
    /// Medication violet — violet-500 (chips, tags, the sticker tint, the bar's gradient end).
    public static let medication = Accent.violet
    /// End-stop of the medication bar gradient — violet-500; the start is `Accent.medicationBarStart`.
    public static let medicationFillEnd = Accent.violet
    /// Side-effect tags and cautions — the one amber that clears AA as text.
    public static let warning = Accent.energyText
    /// Sleep is violet in the pen (the moon), not indigo.
    public static let sleepIndigo = Accent.violet
}
