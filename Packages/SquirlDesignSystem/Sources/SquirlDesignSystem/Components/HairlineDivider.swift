import SwiftUI

/// A 1 pt in-card row divider (DESIGN.md §6.4), inset to the card's padding by default.
public struct HairlineDivider: View {
    private let inset: CGFloat

    public init(inset: CGFloat = 0) {
        self.inset = inset
    }

    public var body: some View {
        Rectangle()
            .fill(Stroke.separator)
            .frame(height: Stroke.hairlineWidth)
            .padding(.horizontal, inset)
            .accessibilityHidden(true)
    }
}
