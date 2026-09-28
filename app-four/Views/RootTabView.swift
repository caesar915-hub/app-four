import SwiftUI

/// The app's four-tab root navigation.
/// Keyed by `Tab` enum — no magic integers anywhere.
enum Tab: Hashable {
    case calendar
    case checkIn
    case insights
    case settings
}

/// The four roots inside a `TabView` (state, lifecycle, deep links) with the system bar hidden
/// and the pen's floating chrome overlaid (D4): the pill tab bar plus the Add button, which
/// starts a voice check-in through the shared router (D5) and is hidden on the Check In root.
/// Screens hide the chrome while capturing or editing via `hidesFloatingChrome`.
struct RootTabView: View {
    @Binding var selectedTab: Tab
    @Binding var shouldAutoStartRecording: Bool
    @Environment(RecordingStore.self) private var store
    @Environment(AppServices.self) private var services
    @Environment(AppIntentRouter.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var chromeHidden = false

    private static let tabs: [FloatingTabItem<Tab>] = [
        FloatingTabItem(id: .calendar, label: "Calendar", activeSymbol: Icons.calendar, inactiveSymbol: Icons.calendar),
        FloatingTabItem(id: .checkIn, label: "Check in", activeSymbol: Icons.checkIn, inactiveSymbol: Icons.checkInOutline),
        FloatingTabItem(id: .insights, label: "Insights", activeSymbol: Icons.insights, inactiveSymbol: Icons.insightsOutline),
        FloatingTabItem(id: .settings, label: "Settings", activeSymbol: Icons.settings, inactiveSymbol: Icons.settingsOutline),
    ]

    var body: some View {
        TabView(selection: $selectedTab) {
            SwiftUI.Tab("Calendar", systemImage: Icons.calendar, value: Tab.calendar) {
                CalendarLibraryView(store: store, selectedTab: $selectedTab)
            }
            SwiftUI.Tab("Check in", systemImage: Icons.checkIn, value: Tab.checkIn) {
                CheckInView(store: store, services: services, shouldAutoStart: $shouldAutoStartRecording)
            }
            SwiftUI.Tab("Insights", systemImage: Icons.insights, value: Tab.insights) {
                InsightsView(store: store, selectedTab: $selectedTab)
            }
            SwiftUI.Tab("Settings", systemImage: Icons.settings, value: Tab.settings) {
                SettingsView(store: store, services: services, selectedTab: $selectedTab)
            }
        }
        .tint(Accent.primaryFill)
        .onPreferenceChange(HidesFloatingChromeKey.self) { hidden in
            withAnimation(reduceMotion ? nil : Motion.smooth) { chromeHidden = hidden }
        }
        .overlay(alignment: .bottom) {
            if !chromeHidden {
                FloatingChrome(items: Self.tabs, selection: $selectedTab, showsAddButton: selectedTab != .checkIn) {
                    router.requestCheckIn()
                }
                .padding(.bottom, Spacing.xs)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
}

#Preview {
    RootTabView(selectedTab: .constant(.calendar), shouldAutoStartRecording: .constant(false))
        .withPreviewEnvironment()
}
