import SwiftUI

/// The one surface every call site uses to render a signal. Maps a `GlyphSignal` (+ level
/// for the self-state signals) to the right Paper & Pollen glyph, resolves its colour from
/// the existing ramps, and owns the accessibility label.
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
                selfStateGlyph(level)
            } else {
                EmptySignalGlyph()
            }
        case .sleep:
            BedIcon(color: Palette.sleepIndigo)
        case .medication:
            CapsuleGlyph(color: Palette.medication)
        }
    }

    @ViewBuilder private func selfStateGlyph(_ level: Int) -> some View {
        let tint = color(for: kind, level: level)
        switch kind {
        case .mood: SproutGlyph(level: level, color: tint)
        case .energy: BoltGlyph(level: level, color: tint)
        case .focus: ApertureGlyph(level: level, color: tint)
        default: EmptyView()
        }
    }

    private func color(for kind: GlyphSignal, level: Int) -> Color {
        switch kind {
        case .mood: MoodLevel.allCases.first { $0.numericValue == level }?.color ?? .secondary
        case .energy: Palette.energyRamp[level - 1]
        case .focus: Palette.focusRamp[level - 1]
        case .sleep: Palette.sleepIndigo
        case .medication: Palette.medication
        }
    }
}

/// Absent-level placeholder — a faint dashed outline, never a misleading level-1 glyph (FR-015).
private struct EmptySignalGlyph: View {
    public var body: some View {
        Circle()
            .strokeBorder(Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
            .padding(2)
    }
}

#Preview("Signal glyphs") {
    VStack(alignment: .leading, spacing: 8) {
        ForEach(GlyphSignal.selfState, id: \.self) { kind in
            HStack(spacing: 8) {
                Text(kind.title).font(.caption).frame(width: 64, alignment: .leading)
                ForEach(1...5, id: \.self) { level in
                    SignalGlyph(kind, level: level, size: 26)
                }
            }
        }
        HStack(spacing: 8) {
            SignalGlyph(.sleep, size: 26)
            SignalGlyph(.medication, size: 26)
            SignalGlyph(.mood, size: 26) // empty (no level)
        }
    }
    .padding()
}
