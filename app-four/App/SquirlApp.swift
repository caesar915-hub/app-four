import SwiftUI
import SwiftData

@main
struct SquirlApp: App {
    @State private var selectedTab: Tab = .calendar
    @State private var shouldAutoStartRecording = false

    init() {
        // Touch global dependencies at startup so stores begin observing the DB.
        _ = AppDependencies.store
        MetricManager.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            RootContainerView(
                selectedTab: $selectedTab,
                shouldAutoStartRecording: $shouldAutoStartRecording
            )
            .modelContainer(AppModelContainer.container)
            // Inject app-level singletons so all descendant views can pull via @Environment.
            .environment(AppDependencies.store)
            .environment(AppDependencies.medicationBarViewModel)
            .environment(AppDependencies.screenTracker)
            .environment(AppDependencies.services)
            .environment(\.diagnosticsStore, AppDependencies.diagnosticsStore)
            .overlay(alignment: .bottomTrailing) {
                #if DEBUG || TESTFLIGHT
                FeedbackButton()
                    .padding(.trailing, Spacing.l)
                    .padding(.bottom, 120) // clears tab bar (49) + home indicator (~34) + extra breathing room
                #endif
            }
            .onOpenURL { url in
                guard url.scheme == "whispernotes", url.host == "checkin" else { return }
                selectedTab = .checkIn
                shouldAutoStartRecording = true
            }
        }
    }
}

private struct RootContainerView: View {
    @Binding var selectedTab: Tab
    @Binding var shouldAutoStartRecording: Bool
    @Environment(AppServices.self) private var services
    @Query private var settingsQuery: [AppSettings]
    @State private var showOnboarding: Bool = false

    private var hasCompletedOnboarding: Bool {
        settingsQuery.first?.hasCompletedOnboarding ?? false
    }

    var body: some View {
        RootTabView(
            selectedTab: $selectedTab,
            shouldAutoStartRecording: $shouldAutoStartRecording
        )
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView(services: services)
        }
        .task {
            showOnboarding = !hasCompletedOnboarding
        }
        .onChange(of: hasCompletedOnboarding) { _, completed in
            if completed { showOnboarding = false }
        }
    }
}
