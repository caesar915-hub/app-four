import SwiftUI

/// A settings toggle row — native `Toggle` tinted green-600 (D22: VoiceOver "switch",
/// Switch Control and the HIG size for free), title 14/600, optional description 12/500.
public struct ToggleRow: View {
    private let title: String
    private let description: String?
    @Binding private var isOn: Bool

    public init(_ title: String, description: String? = nil, isOn: Binding<Bool>) {
        self.title = title
        self.description = description
        _isOn = isOn
    }

    public var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(description == nil ? Typography.rowLabel : Typography.rowTitle)
                    .foregroundStyle(Ink.primary)
                if let description {
                    Text(description)
                        .font(Typography.captionMedium)
                        .foregroundStyle(Ink.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .tint(Accent.primaryFill)
        .frame(minHeight: Metrics.minTapTarget)
    }
}
