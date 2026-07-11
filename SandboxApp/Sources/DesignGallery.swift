import SwiftUI
import SquirlDesignSystem

/// A live catalog of the real `SquirlDesignSystem` atoms — the glyphs, color ramps, type,
/// buttons, and card, rendered by the actual package (zero drift). Type is the Apple SF system
/// font (no bundled faces to register).
struct DesignGallery: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                glyphs
                colors
                typography
                buttons
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.background.ignoresSafeArea())
    }

    private func title(_ s: String) -> some View {
        Text(s).font(Typography.title).foregroundStyle(Theme.textPrimary)
    }

    // MARK: Glyphs

    private var glyphs: some View {
        VStack(alignment: .leading, spacing: 16) {
            title("Signal glyphs")
            glyphRow("Mood", .mood)
            glyphRow("Energy", .energy)
            glyphRow("Focus", .focus)
            HStack(spacing: 18) {
                Text("Sleep · Med").font(Typography.caption).foregroundStyle(Theme.textSecondary)
                    .frame(width: 80, alignment: .leading)
                SignalGlyph(.sleep, size: 32)
                SignalGlyph(.medication, size: 32)
            }
        }
    }

    private func glyphRow(_ name: String, _ kind: GlyphSignal) -> some View {
        HStack(spacing: 14) {
            Text(name).font(Typography.caption).foregroundStyle(Theme.textSecondary)
                .frame(width: 80, alignment: .leading)
            ForEach(1...5, id: \.self) { lvl in
                SignalGlyph(kind, level: lvl, size: 30)
            }
        }
    }

    // MARK: Color

    private var colors: some View {
        VStack(alignment: .leading, spacing: 14) {
            title("Color")
            swatches("Mood", MoodLevel.allCases.map(\.color))
            swatches("Energy", Palette.energyRamp)
            swatches("Focus", Palette.focusRamp)
            swatches("Surfaces", [Theme.background, Theme.cardBackground, Theme.surface2])
            swatches("Accents", [Theme.accent, Theme.meadowGreen, Theme.meadowAmber, Palette.medication, Palette.sleepIndigo, Theme.danger])
        }
    }

    private func swatches(_ name: String, _ colors: [Color]) -> some View {
        HStack(spacing: 8) {
            Text(name).font(Typography.caption).foregroundStyle(Theme.textSecondary)
                .frame(width: 80, alignment: .leading)
            ForEach(Array(colors.enumerated()), id: \.offset) { _, c in
                RoundedRectangle(cornerRadius: 8, style: .continuous).fill(c)
                    .frame(width: 32, height: 32)
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Theme.separator, lineWidth: 1))
            }
        }
    }

    // MARK: Typography

    private var typography: some View {
        VStack(alignment: .leading, spacing: 8) {
            title("Typography")
            Text("Fraunces · display").font(Typography.display).foregroundStyle(Theme.textPrimary)
            Text("Fraunces · title").font(Typography.title).foregroundStyle(Theme.textPrimary)
            Text("DM Sans · headline").font(Typography.headline).foregroundStyle(Theme.textPrimary)
            Text("DM Sans · body, the quick brown fox jumps").font(Typography.body).foregroundStyle(Theme.textPrimary)
            Text("DM Sans · caption / metadata").font(Typography.caption).foregroundStyle(Theme.textSecondary)
        }
    }

    // MARK: Buttons + card

    private var buttons: some View {
        VStack(alignment: .leading, spacing: 12) {
            title("Buttons & card")
            Button("Primary action") {}.buttonStyle(.primary)
            Button("Secondary action") {}.buttonStyle(.secondary)
            VStack(alignment: .leading, spacing: 6) {
                Text("Summary").cardEyebrow()
                Text("The standard card surface — cream, hairline, soft shadow.")
                    .font(Typography.body).foregroundStyle(Theme.textPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
        }
    }
}
