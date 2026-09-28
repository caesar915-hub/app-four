import SwiftUI

/// One tab of the floating bar: a filled symbol when active, an outline symbol otherwise.
public struct FloatingTabItem<ID: Hashable>: Identifiable {
    public let id: ID
    public let label: String
    public let activeSymbol: String
    public let inactiveSymbol: String

    public init(id: ID, label: String, activeSymbol: String, inactiveSymbol: String) {
        self.id = id
        self.label = label
        self.activeSymbol = activeSymbol
        self.inactiveSymbol = inactiveSymbol
    }
}

/// The pen's floating tab bar (Frame 4, compact layout — D4): a 60 pt white pill on a
/// green-black shadow; the active tab is a 64 × 44 green pill with a white icon, the others
/// a grey-300 outline icon. VoiceOver: a tab-bar container, each item "n of N" + selected.
public struct FloatingTabBar<ID: Hashable>: View {
    private let items: [FloatingTabItem<ID>]
    @Binding private var selection: ID
    @Namespace private var pill
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(items: [FloatingTabItem<ID>], selection: Binding<ID>) {
        self.items = items
        _selection = selection
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                let selected = item.id == selection
                Button {
                    withAnimation(reduceMotion ? nil : Motion.snappy) { selection = item.id }
                } label: {
                    ZStack {
                        if selected {
                            Capsule()
                                .fill(Accent.primaryFill)
                                .frame(width: Metrics.tabPillWidth, height: Metrics.tabPillHeight)
                                .matchedGeometryEffect(id: "pill", in: pill)
                        }
                        Image(systemName: selected ? item.activeSymbol : item.inactiveSymbol)
                            .font(.system(size: Metrics.tabIcon, weight: .medium))
                            .foregroundStyle(selected ? Ink.onAccent : Ink.tabInactive)
                    }
                    .frame(maxWidth: .infinity, minHeight: Metrics.minTapTarget)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.label)
                .accessibilityValue("\(index + 1) of \(items.count)")
                .accessibilityAddTraits(selected ? [.isSelected] : [])
            }
        }
        .padding(.horizontal, Spacing.s)
        .frame(height: Metrics.tabBarHeight)
        .background(Surface.card, in: .capsule)
        .overlay { Capsule().strokeBorder(Stroke.card, lineWidth: Stroke.cardWidth) }
        .elevation(Elevation.tabBar)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isTabBar)
    }
}

/// The pen's violet Add button (Frame 15): 50 ⌀, a light plus, a black shadow.
public struct AddButton: View {
    private let label: String
    private let action: () -> Void

    public init(label: String = "New check-in", action: @escaping () -> Void) {
        self.label = label
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: Icons.add)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(Ink.onAccent)
                .frame(width: Metrics.fab, height: Metrics.fab)
                .background(Accent.violet, in: .circle)
                .elevation(Elevation.fab)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// The bottom chrome row: the tab bar filling the column, the Add button at its trailing end
/// (hidden on the Check In root — D4: the hub already carries the same primary action).
public struct FloatingChrome<ID: Hashable>: View {
    private let items: [FloatingTabItem<ID>]
    @Binding private var selection: ID
    private let showsAddButton: Bool
    private let onAdd: () -> Void

    public init(items: [FloatingTabItem<ID>], selection: Binding<ID>, showsAddButton: Bool, onAdd: @escaping () -> Void) {
        self.items = items
        _selection = selection
        self.showsAddButton = showsAddButton
        self.onAdd = onAdd
    }

    public var body: some View {
        HStack(spacing: Spacing.xl) {
            FloatingTabBar(items: items, selection: $selection)
            if showsAddButton {
                AddButton(action: onAdd)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, Spacing.gutter)
    }
}

#Preview("Chrome") {
    struct Host: View {
        @State private var tab = 0
        var body: some View {
            VStack {
                Spacer()
                FloatingChrome(items: [
                    FloatingTabItem(id: 0, label: "Calendar", activeSymbol: Icons.calendar, inactiveSymbol: Icons.calendar),
                    FloatingTabItem(id: 1, label: "Check in", activeSymbol: Icons.checkIn, inactiveSymbol: Icons.checkInOutline),
                    FloatingTabItem(id: 2, label: "Insights", activeSymbol: Icons.insights, inactiveSymbol: Icons.insightsOutline),
                    FloatingTabItem(id: 3, label: "Settings", activeSymbol: Icons.settings, inactiveSymbol: Icons.settingsOutline),
                ], selection: $tab, showsAddButton: tab != 1) {}
            }
            .background(Surface.screen)
        }
    }
    return Host()
}
