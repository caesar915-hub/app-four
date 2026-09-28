import SwiftUI

struct TagFlowView: View {
    let tags: [DisplayTag]

    var body: some View {
        FlowLayout(spacing: Spacing.s) { // was 6
            ForEach(tags) { tag in
                HStack(spacing: 4) {
                    if let glyph = tag.glyph {
                        SignalGlyph(glyph.kind, level: glyph.level, size: 15, decorative: true)
                    } else {
                        Image(systemName: tag.icon)
                            .accessibilityHidden(true)
                    }
                    Text(tag.label)
                }
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(tag.color)
                    .padding(.horizontal, Spacing.s)
                    .padding(.vertical, Spacing.xs)
                    .background(tag.color.opacity(0.13))
                    .clipShape(.capsule)
            }
        }
    }
}

// `FlowLayout` lives in SquirlDesignSystem (spec 057, UI-10).
