import SwiftUI

/// The one surface every call site uses to render a signal. Maps a `GlyphSignal` (+ level for
/// the ramped signals) to the pen's glyph and owns the accessibility label.
///
/// - `decorative: true` hides the glyph from VoiceOver (use when the surrounding row/chip
///   already announces the signal and value, to avoid a double read).
public struct SignalGlyph: View {
    private let kind: GlyphSignal
    private let level: Int?
    private let size: CGFloat
    private let decorative: Bool

    public init(_ kind: GlyphSignal, level: Int? = nil, size: CGFloat = 22, decorative: Bool = false) {
        self.kind = kind
        self.level = level
        self.size = size
        self.decorative = decorative
    }

    public var body: some View {
        glyph
            .frame(width: size, height: size)
            .accessibilityElement()
            .accessibilityLabel(signalAccessibilityLabel(kind, level: level))
            .accessibilityHidden(decorative)
    }

    @ViewBuilder private var glyph: some View {
        switch kind {
        case .mood, .energy, .focus:
            if let level = clampedSignalLevel(level) {
                rampedGlyph(level)
            } else {
                EmptySignalGlyph()
            }
        case .sleep:
            // Sleep hours can exist without a level — the full moon then stands for "sleep".
            MoonGlyph(level: clampedSignalLevel(level) ?? 5)
        case .medication:
            CapsuleGlyph()
        }
    }

    @ViewBuilder private func rampedGlyph(_ level: Int) -> some View {
        switch kind {
        case .mood: SproutGlyph(level: level)
        case .energy: BoltGlyph(level: level)
        case .focus: TargetGlyph(level: level)
        default: EmptyView()
        }
    }
}

/// Absent-level placeholder — a faint dashed outline, never a misleading level-1 glyph (FR-015).
private struct EmptySignalGlyph: View {
    var body: some View {
        Circle()
            .strokeBorder(Stroke.empty, style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
            .padding(2)
    }
}

#Preview("Signal glyphs") {
    VStack(alignment: .leading, spacing: 8) {
        ForEach([GlyphSignal.mood, .energy, .focus, .sleep], id: \.self) { kind in
            HStack(spacing: 8) {
                Text(kind.title).font(.caption).frame(width: 64, alignment: .leading)
                ForEach(1...5, id: \.self) { level in
                    SignalGlyph(kind, level: level, size: 34)
                }
            }
        }
        HStack(spacing: 8) {
            SignalGlyph(.medication, size: 34)
            SignalGlyph(.mood, size: 34)
        }
    }
    .padding()
}
