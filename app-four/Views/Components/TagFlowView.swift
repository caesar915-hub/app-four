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

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let result = layout(subviews: subviews, in: proposal.replacingUnspecifiedDimensions().width)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        let result = layout(subviews: subviews, in: bounds.width)
        for (index, origin) in result.origins.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y),
                proposal: .unspecified
            )
        }
    }

    private struct LayoutResult {
        let origins: [CGPoint]
        let size: CGSize
    }

    private func layout(subviews: Subviews, in maxWidth: CGFloat) -> LayoutResult {
        var origins: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            origins.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return LayoutResult(
            origins: origins,
            size: CGSize(width: maxWidth, height: y + rowHeight)
        )
    }
}
