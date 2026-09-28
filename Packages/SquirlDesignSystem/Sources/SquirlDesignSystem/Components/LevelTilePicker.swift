import SwiftUI

/// The pen's five-tile level picker (Edit check-in, the text composer): a row label with the
/// selected level's word in green, five 56-pt tiles showing the glyph at each level, and
/// "Low" / "High" captions. Selected = 2-pt green-600 stroke + a level-tinted fill (D14; the pen's
/// 1-pt tinted ring alone is colour-only). Tapping the selected tile clears the selection.
public struct LevelTilePicker<Level: SignalLevel & CaseIterable & Hashable>: View {
    private let kind: GlyphSignal
    private let label: String
    @Binding private var selection: Level?
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(_ kind: GlyphSignal, label: String? = nil, selection: Binding<Level?>) {
        self.kind = kind
        self.label = label ?? kind.title
        _selection = selection
    }

    private var levels: [Level] { Array(Level.allCases) }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack {
                Text(label)
                    .font(Typography.rowLabel)
                    .foregroundStyle(Ink.primary)
                Spacer()
                if let selection {
                    Text(selection.displayLabel)
                        .font(Typography.status)
                        .foregroundStyle(Accent.primaryText)
                        .transition(.opacity)
                }
            }
            .accessibilityElement(children: .combine)

            ViewThatFits(in: .horizontal) {
                tiles(size: Metrics.levelTile)
                tiles(size: 52)
                tiles(size: 48)
            }

            HStack {
                Text("Low").font(Typography.captionQuiet).foregroundStyle(Ink.nav)
                Spacer()
                Text("High").font(Typography.captionQuiet).foregroundStyle(Ink.nav)
            }
            .accessibilityHidden(true)
        }
        .animation(reduceMotion ? nil : Motion.snappy, value: selection)
    }

    private func tiles(size: CGFloat) -> some View {
        HStack(spacing: Spacing.s) {
            ForEach(levels, id: \.self) { level in
                let selected = selection == level
                Button {
                    selection = selected ? nil : level
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: Radius.tile)
                            .fill(selected ? tint(for: level) : Color.clear)
                        RoundedRectangle(cornerRadius: Radius.tile)
                            .strokeBorder(selected ? Accent.primaryFill : Stroke.tile,
                                          lineWidth: selected ? 2 : Stroke.hairlineWidth)
                        SignalGlyph(kind, level: level.numericValue, size: size * 0.6, decorative: true)
                        if selected && differentiateWithoutColor {
                            Image(systemName: Icons.check)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Ink.onAccent)
                                .padding(3)
                                .background(Accent.primaryFill, in: .circle)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                                .padding(4)
                        }
                    }
                    .frame(width: size, height: size)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(signalAccessibilityLabel(kind, level: level.numericValue))
                .accessibilityAddTraits(selected ? [.isSelected] : [])
            }
        }
    }

    private func tint(for level: Level) -> Color {
        MoodLevel.allCases[level.numericValue - 1].tileRing.opacity(0.35)
    }
}

#Preview("Level tiles") {
    struct Host: View {
        @State private var mood: MoodLevel? = .good
        @State private var energy: EnergyLevel? = .charged
        @State private var focus: FocusLevel? = nil
        var body: some View {
            VStack(spacing: Spacing.xxl) {
                LevelTilePicker(.mood, selection: $mood)
                LevelTilePicker(.energy, label: "Energy level", selection: $energy)
                LevelTilePicker(.focus, label: "Focus level", selection: $focus)
            }
            .padding(Spacing.cardInset)
            .card(.large)
            .padding(Spacing.gutter)
            .background(Surface.screen)
        }
    }
    return Host()
}
