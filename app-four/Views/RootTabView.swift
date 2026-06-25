import SwiftUI

/// The app's four-tab root navigation.
/// Keyed by `Tab` enum — no magic integers anywhere.
enum Tab: Hashable {
    case calendar
    case checkIn
    case insights
    case settings
}

struct RootTabView: View {
    @Binding var selectedTab: Tab
    @Binding var shouldAutoStartRecording: Bool
    @Environment(RecordingStore.self) private var store
    @Environment(AppServices.self) private var services

    var body: some View {
        TabView(selection: $selectedTab) {
            CalendarLibraryView(store: store, selectedTab: $selectedTab)
                .tabItem { Label("Calendar", systemImage: Icons.calendar) }
                .tag(Tab.calendar)

            CheckInView(store: store, services: services, shouldAutoStart: $shouldAutoStartRecording)
                .tabItem { Label("Check in", systemImage: Icons.checkIn) }
                .tag(Tab.checkIn)

            InsightsView(store: store, selectedTab: $selectedTab)
                .tabItem { Label("Insights", systemImage: Icons.insights) }
                .tag(Tab.insights)

            SettingsView(store: store, services: services, selectedTab: $selectedTab)
                .tabItem { Label("Settings", systemImage: Icons.settings) }
                .tag(Tab.settings)
        }
        .tint(Theme.meadowGreen)
    }
}

#Preview {
    RootTabView(selectedTab: .constant(.calendar), shouldAutoStartRecording: .constant(false))
        .withPreviewEnvironment()

}
