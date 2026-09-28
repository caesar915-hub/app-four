import SwiftUI

/// A section heading on the ground — 16/600 with an optional 14/400 subtitle (DESIGN.md §8.26).
/// Sits 12 pt above its card and 24 pt below the previous one; the caller owns the stack gaps.
public struct SectionHeading: View {
    private let title: String
    private let subtitle: String?

    public init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(Typography.sectionTitle)
                .foregroundStyle(Ink.primary)
                .accessibilityAddTraits(.isHeader)
            if let subtitle {
                Text(subtitle)
                    .font(Typography.cardSubtitle)
                    .foregroundStyle(Ink.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
