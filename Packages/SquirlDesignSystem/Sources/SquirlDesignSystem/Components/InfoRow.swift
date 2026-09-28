import SwiftUI

/// An icon + a hugging multi-line note (Settings accessibility row, Dose Guard footnote).
public struct InfoRow: View {
    private let symbol: String
    private let text: String

    public init(symbol: String, text: String) {
        self.symbol = symbol
        self.text = text
    }

    public var body: some View {
        HStack(alignment: .top, spacing: Spacing.m) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Ink.iconBlack)
                .frame(width: 21, height: 21)
                .accessibilityHidden(true)
            Text(text)
                .font(Typography.cardSubtitle)
                .foregroundStyle(Ink.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
