import AppIntents
import SwiftUI
import SwiftData

@main
struct SquirlApp: App {
    // Reconnects nsurlsessiond-owned model downloads after a background relaunch.
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var selectedTab: Tab = .calendar
    @State private var shouldAutoStartRecording = false
    @State private var router = AppDependencies.appIntentRouter

    init() {
        // Relocate any pre-1.0 user data out of the Files-app-exposed Documents
        // directory before any store or service reads from disk. Idempotent.
        StorageMigration.run()
        #if DEBUG
        // Mock mode is opt-in via the `-mockData` launch argument (scheme → Run
        // → Arguments) — the debug console that toggled it is unmounted for
        // submission. Any persisted value from that era is cleared, so a plain
        // dev run is production-like: real data and the real onboarding gate.
        // Read before AppDependencies.store, which reads the key eagerly via
        // RecordingStore.loadRecordings().
        if CommandLine.arguments.contains("-mockData") {
            UserDefaults.standard.set(true, forKey: "debugMockMode")
        } else {
            UserDefaults.standard.removeObject(forKey: "debugMockMode")
        }
        #else
        // A container that ever ran a Debug build (or the old TestFlight debug
        // console) can carry a persisted debugMockMode=true — and the data
        // paths honor the key, which would hide every real recording behind
        // the mock filter after a store upgrade. Release never offers the
        // toggle, so clear it before the store reads the key eagerly below.
        UserDefaults.standard.removeObject(forKey: "debugMockMode")
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
        AppDependencyManager.shared.add(dependency: doseLogService)
        AppDependencyManager.shared.add(dependency: router)
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
            WelcomeView(services: services, onComplete: { showOnboarding = false })
        }
        .task {
            #if DEBUG
            // Mock-dev mode (`-mockData` launch arg) implies a returning user:
            // skip the first-run ceremony so dev lands straight on the populated
            // app. A plain dev run keeps the real onboarding gate.
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
        // It also stays out of the onboarding flow entirely: first-run users get
        // the model only via the permission screen's explicit "Download Now",
        // and a "Skip for Now" decline disables this task for good.
        .task { await startBackgroundModelDownloadIfNeeded() }
        // Drain any recordings captured before the model was ready (US3): on launch
        // (a download that finished in a prior session) and on every foreground (one
        // that finished while backgrounded). The service no-ops when the model isn't
        // ready or when already draining (FR-013/016).
        .task { await services.pendingTranscriptionService.drainIfModelReady() }
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
    ///
    /// Two opt-in gates ride on top: the task only serves installs whose
    /// onboarding predates the two-screen flow (or a model that went missing
    /// afterwards). A first-run user still on the permission screen hasn't
    /// consented yet — starting here would both ignore that choice and race
    /// the screen's own "Download Now" (`AIModelService.download` has no
    /// in-flight dedup). An explicit "Skip for Now" decline is remembered in
    /// `AppSettings.declinedOnboardingModelDownload` and honored permanently;
    /// Settings remains the way back.
    private func startBackgroundModelDownloadIfNeeded() async {
        guard !downloadKicked else { return }
        downloadKicked = true

        // Whisper first (transcription unblocks the pending queue), then the
        // ~740 MB insights model (LLM) — each with its own decline flag.
        await downloadModelInBackgroundIfNeeded(.whisper)
        await downloadModelInBackgroundIfNeeded(.llm)
    }

    private func downloadModelInBackgroundIfNeeded(_ type: AIModelType) async {
        let aiModelService = services.aiModelService
        let connectivity = services.connectivity
        guard aiModelService.localPath(for: type) == nil else { return }
        guard hasCompletedOnboarding, !declinedDownload(type) else { return }

        if !shouldStartDownload(interface: await connectivity.currentInterface) {
            for await interface in connectivity.interfaceChanges where shouldStartDownload(interface: interface) {
                break
            }
        }

        // The model may have landed (or been installed elsewhere) while we waited.
        guard aiModelService.localPath(for: type) == nil else { return }

        // The shared driver owns resilience from here (FR-009 spirit): a network
        // blip mid-download or a frozen transfer waits for a permitted interface
        // and retries. The insights model downloads out-of-process via
        // BackgroundLLMDownloadService, which skips already-completed staging
        // files and resumes partial files from persisted byte-range resume data,
        // so each retry picks up where the previous attempt stopped.
        let driver = ResilientModelDownload(
            download: { try await aiModelService.download(type) },
            connectivity: connectivity,
            allowsCellular: { settingsQuery.first?.downloadOverCellular ?? false }
        )
        do {
            try await driver.run()
            if type == .whisper {
                // Model just landed — drain anything captured while it was downloading (US3).
                await services.pendingTranscriptionService.drainIfModelReady()
            }
        } catch is CancellationError {
            // App tore the task down mid-download — quiet exit, no retry.
        } catch {
            // A background download failure must not surface as a first-run error
            // (FR-010); the model stays retryable from its Settings home.
            AppLogger.log("Background model download failed (\(type.rawValue)): \(error)")
        }
    }

    private func declinedDownload(_ type: AIModelType) -> Bool {
        switch type {
        case .whisper: return settingsQuery.first?.declinedOnboardingModelDownload == true
        case .llm: return settingsQuery.first?.declinedOnboardingLLMDownload == true
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
