import SwiftUI

/// The in-content page title of the Insights and Settings roots — 34/600 green-800 over a
/// 16/500 grey-300 subtitle (DESIGN.md §9.1).
public struct PageTitleBlock: View {
    private let title: String
    private let subtitle: String?

    public init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title)
                .font(Typography.pageTitle)
                .foregroundStyle(Ink.title)
                .accessibilityAddTraits(.isHeader)
            if let subtitle {
                Text(subtitle)
                    .font(Typography.pageSubtitle)
                    .foregroundStyle(Ink.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
