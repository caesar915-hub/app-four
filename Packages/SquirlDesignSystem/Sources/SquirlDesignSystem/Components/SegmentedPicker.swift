import SwiftUI

/// The pen's segmented pill picker (Insights month selector): a 38 pt `Surface.track` with
/// equal segments, a white thumb under the selection, 12/500 labels. Disabled segments (the
/// month after the current one) stay visible but inert.
public struct SegmentedPicker<Item: Hashable>: View {
    private let items: [Item]
    @Binding private var selection: Item
    private let label: (Item) -> String
    private let isEnabled: (Item) -> Bool
    @Namespace private var thumb
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(_ items: [Item], selection: Binding<Item>,
                label: @escaping (Item) -> String,
                isEnabled: @escaping (Item) -> Bool = { _ in true }) {
        self.items = items
        _selection = selection
        self.label = label
        self.isEnabled = isEnabled
    }

    public var body: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(items, id: \.self) { item in
                let selected = item == selection
                let enabled = isEnabled(item)
                Button {
                    guard enabled else { return }
                    withAnimation(reduceMotion ? nil : Motion.snappy) { selection = item }
                } label: {
                    Text(label(item))
                        .font(selected ? Typography.segmentLabel : Typography.captionQuiet)
                        .foregroundStyle(selected ? Accent.deepText : (enabled ? Ink.tertiary : Ink.disabled))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, minHeight: 30)
                        .background {
                            if selected {
                                RoundedRectangle(cornerRadius: Radius.segmentThumb)
                                    .fill(Surface.card)
                                    .elevation(Elevation.thumb)
                                    .matchedGeometryEffect(id: "thumb", in: thumb)
                            }
                        }
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .disabled(!enabled)
                .accessibilityAddTraits(selected ? [.isSelected] : [])
            }
        }
        .padding(Spacing.xs)
        .frame(minHeight: Metrics.minTapTarget)
        .background(Surface.track, in: .rect(cornerRadius: Radius.segmentTrack))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.segmentTrack)
                .strokeBorder(Stroke.segmentTrack, lineWidth: Stroke.hairlineWidth)
        }
    }
}
