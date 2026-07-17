import AppIntents
import SwiftUI
import SwiftData
import SquirlLiveActivity

@main
struct SquirlApp: App {
    @State private var selectedTab: Tab = .calendar
    @State private var shouldAutoStartRecording = false
    @State private var router = AppDependencies.appIntentRouter

    init() {
        #if DEBUG
        // UI/UX dev: default the mock-data toggle ON so a cold launch lands on a
        // populated timeline. Guarded out under XCTest so the suite keeps the
        // real default (false). Registered before AppDependencies.store, which
        // reads the key eagerly via RecordingStore.loadRecordings().
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
            UserDefaults.standard.register(defaults: ["debugMockMode": true])
        }
        #endif
        // Touch global dependencies at startup so stores begin observing the DB.
        _ = AppDependencies.store
        MetricManager.shared.start()
        // D11: intent dependencies must be registered before any perform() — a
        // background intent launch runs this init first. Values are captured
        // eagerly so the manager's @Sendable autoclosure never hops back to the
        // MainActor-isolated AppDependencies accessors.
        let doseLogService = AppDependencies.doseLogService
        let router = AppDependencies.appIntentRouter
        // 037 — register as the EXACT existential the Live Activity intents resolve
        // (`any RecordingControlSurface`); the SAME instance is threaded into AppServices,
        // so the intents and the view model drive one shared session (a second instance
        // would leave the intents' `session` nil forever → silent no-op).
        let recordingControl: any RecordingControlSurface = AppDependencies.recordingSessionController
        AppDependencyManager.shared.add(dependency: doseLogService)
        AppDependencyManager.shared.add(dependency: router)
        AppDependencyManager.shared.add(dependency: recordingControl)
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
            .environment(router)
            .environment(\.diagnosticsStore, AppDependencies.diagnosticsStore)
            // Feedback button unmounted (spec 024) — it crashed the app. Views/Feedback/* retained.
            // Route the legacy deep link through the shared router (D3/D4) so the
            // App Intent (US2) and this URL hit ONE choke point; the onboarding gate
            // (FR-022) lands inside the router in US2.
            .onOpenURL { url in
                guard url.scheme == "whispernotes", url.host == "checkin" else { return }
                router.requestCheckIn()
            }
            .onChange(of: router.shouldStartCheckIn) { _, armed in
                guard armed, router.consumeCheckIn() else { return }
                selectedTab = .checkIn
                shouldAutoStartRecording = true
            }
            // A background intent (dose, not-configured path) arms the flag around
            // the time a headless launch foregrounds — either side of this body
            // attaching. `initial: true` covers armed-before-attach; the reactive
            // fire covers armed-after. Consumption stays with SettingsView (it
            // scrolls + expands the picker); this observer only switches the tab.
            .onChange(of: router.shouldFocusMyMedication, initial: true) { _, armed in
                guard armed else { return }
                selectedTab = .settings
            }
        }
    }
}

private struct RootContainerView: View {
    @Binding var selectedTab: Tab
    @Binding var shouldAutoStartRecording: Bool
    @Environment(AppServices.self) private var services
    @Environment(\.scenePhase) private var scenePhase
    @Query private var settingsQuery: [AppSettings]
    @State private var showOnboarding: Bool = false
    @State private var downloadKicked = false

    private var hasCompletedOnboarding: Bool {
        settingsQuery.first?.hasCompletedOnboarding ?? false
    }

    var body: some View {
        RootTabView(
            selectedTab: $selectedTab,
            shouldAutoStartRecording: $shouldAutoStartRecording
        )
        .fullScreenCover(isPresented: $showOnboarding) {
            WelcomeView(onComplete: { showOnboarding = false })
        }
        .task {
            #if DEBUG
            // Mock-dev mode (the DEBUG default) implies a returning user: skip the
            // first-run ceremony so dev lands straight on the populated app. Flip
            // Mock Mode off in TestServices to restore the real onboarding gate.
            if CommandLine.arguments.contains("-skipOnboarding")
                || UserDefaults.standard.bool(forKey: "debugMockMode") {
                showOnboarding = false; return
            }
            #endif
            showOnboarding = !hasCompletedOnboarding
        }
        // Background model download — kept off the first-run path (FR-007): it
        // never gates UI; the welcome dismisses immediately while the model
        // arrives on its own schedule. Drains the pending queue on completion.
        .task { await startBackgroundModelDownloadIfNeeded() }
        // Drain any recordings captured before the model was ready (US3): on launch
        // (a download that finished in a prior session) and on every foreground (one
        // that finished while backgrounded). The service no-ops when the model isn't
        // ready or when already draining (FR-013/016).
        .task { await services.pendingTranscriptionService.drainIfModelReady() }
        // 037 — end any stale "recording" Live Activity left by a killed-app run (D15).
        .task { await services.recordingSessionController.recoverIfNeeded() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await services.pendingTranscriptionService.drainIfModelReady() }
            }
        }
        .onChange(of: hasCompletedOnboarding) { _, completed in
            if completed { showOnboarding = false }
        }
    }

    /// Fetch the model in the background, honoring `downloadOverCellular`.
    /// If the model is already installed, do nothing (FR-008). When the active
    /// interface forbids the download (cellular + preference off, or no usable
    /// path), wait for a permitted interface and resume automatically (FR-009).
    private func startBackgroundModelDownloadIfNeeded() async {
        guard !downloadKicked else { return }
        downloadKicked = true

        let aiModelService = services.aiModelService
        let connectivity = services.connectivity
        guard aiModelService.localPath(for: .whisper) == nil else { return }

        if !shouldStartDownload(interface: await connectivity.currentInterface) {
            for await interface in connectivity.interfaceChanges where shouldStartDownload(interface: interface) {
                break
            }
        }

        // The model may have landed (or been installed elsewhere) while we waited.
        guard aiModelService.localPath(for: .whisper) == nil else { return }

        do {
            let progress = try await aiModelService.download(.whisper)
            for try await _ in progress {}
            // Model just landed — drain anything captured while it was downloading (US3).
            await services.pendingTranscriptionService.drainIfModelReady()
        } catch {
            // A background download failure must not surface as a first-run error
            // (FR-010); the model stays retryable from its Settings home.
            AppLogger.log("Background model download failed: \(error)")
        }
    }

    /// Re-reads the live `downloadOverCellular` preference each call so toggling
    /// it on while deferred on cellular also unblocks the download.
    private func shouldStartDownload(interface: NetworkInterface) -> Bool {
        NetworkConnectivity.shouldStartDownload(
            overCellular: settingsQuery.first?.downloadOverCellular ?? false,
            interface: interface
        )
    }
}
