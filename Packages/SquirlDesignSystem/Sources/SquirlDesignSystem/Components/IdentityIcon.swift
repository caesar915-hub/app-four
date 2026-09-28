import SwiftUI

/// A level-less signal icon for section and row leaders (Insights headers, day-details columns):
/// the sprout in its canonical "great" colours (D3.2), the bolt fully filled, the full-ring
/// target, the full moon. Decorative by default — the adjacent label names the signal.
public struct IdentityIcon: View {
    private let kind: GlyphSignal
    private let size: CGFloat
    private let decorative: Bool

    public init(_ kind: GlyphSignal, size: CGFloat = Metrics.glyphHeader, decorative: Bool = true) {
        self.kind = kind
        self.size = size
        self.decorative = decorative
    }

    public var body: some View {
        glyph
            .frame(width: size, height: size)
            .accessibilityLabel(kind.title)
            .accessibilityHidden(decorative)
    }

    @ViewBuilder private var glyph: some View {
        switch kind {
        case .mood: SproutGlyph(level: 5)
        case .energy: BoltGlyph(level: 5)
        case .focus: TargetGlyph(level: 5)
        case .sleep: MoonGlyph(level: 5)
        case .medication: CapsuleGlyph()
        }
    }
}
