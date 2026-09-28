import SwiftUI

/// A titled chip group (DESIGN.md §8.21): a 14/500 title over a wrapping row of chips.
/// Interactive by default — the rows sit on the 44 pt pitch so no two hit areas overlap (D-K6).
public struct ChipGroupView<Content: View>: View {
    private let title: String
    private let interactive: Bool
    private let content: Content

    public init(_ title: String, interactive: Bool = true, @ViewBuilder content: () -> Content) {
        self.title = title
        self.interactive = interactive
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(title)
                .font(Typography.rowLabel)
                .foregroundStyle(Ink.primary)
                .accessibilityAddTraits(.isHeader)
            ChipRow(interactive: interactive) { content }
        }
    }
}

#Preview {
    ChipGroupView("Pleasant") {
        ChipButton("Excited", selected: true) {}
        ChipButton("Joyful", selected: false) {}
        ChipButton("Proud", selected: false) {}
        ChipButton("Content", selected: false) {}
    }
    .padding(Spacing.gutter)
    .background(Surface.screen)
}
