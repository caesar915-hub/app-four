import SwiftUI

/// The shared 1→5 signal glyph ramp used as an **input**: bare glyphs in a left-aligned
/// row, the selected one wrapped in a 1.5pt ring. Tapping the selected level again clears it.
/// Used by Type-note (§06, Paper & Pollen) and the Edit sheet (§07, New Look) so they stay
/// identical in shape. The selected-ring tint is injected (`ringTint`) so each host matches its
/// own accent — default is P&P `Theme.accent`; New Look passes `NewLook.selection` (spec 032).
/// Tokens only — `Spacing`/`Radius`/`Theme`/`NewLook`.
struct GlyphRampPicker<Level: SignalLevel & CaseIterable & Equatable>: View {
    let kind: GlyphSignal
    @Binding var selection: Level?
    var size: CGFloat = 30
    var ringTint: Color = Theme.accent

    var body: some View {
        HStack(spacing: Spacing.m) {
            ForEach(Array(Level.allCases), id: \.numericValue) { level in
                Button {
                    selection = (selection == level) ? nil : level
                } label: {
                    SignalGlyph(kind, level: level.numericValue, size: size, decorative: true)
                        .padding(Spacing.xs)
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.control)
                                .strokeBorder(ringTint, lineWidth: selection == level ? 1.5 : 0)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(kind.title) \(level.displayLabel)")
                .accessibilityAddTraits(selection == level ? [.isSelected] : [])
            }
            Spacer(minLength: 0)
        }
    }
}
