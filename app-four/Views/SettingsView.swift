import SwiftUI

struct SettingsView: View {
    @Binding var selectedTab: Tab
    @State private var viewModel: SettingsViewModel
    @State private var showingDebug = false
    @State private var showingClearConfirmation = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let topID = "settings-top"

    init(store: RecordingStore, services: AppServices, selectedTab: Binding<Tab>) {
        _viewModel = State(wrappedValue: SettingsViewModel(store: store, services: services))
        _selectedTab = selectedTab
    }

    var body: some View {
        // List manages its own scroll — ScreenContainer is non-scrollable here.
        // The inline navigation title is exposed to VoiceOver as a heading by default,
        // so passing it here both shows "Settings" and gives the screen a landmark.
        ScreenContainer(title: "Settings", showsMedicationBar: true, scrollable: false) {
            ScrollViewReader { proxy in
                List {
                    aiModelsSection
                        .id(Self.topID)
                    systemSection
                    checkInSection
                    transcriptionSection
                    dayCardSection
                    medicationBarSection
                    accessibilitySection
                    dangerSection
                    versionSection
                }
                .listStyle(.insetGrouped)
                // TabView keeps this tab alive, so its scroll offset persists.
                // Reset to top each time Settings becomes the active tab.
                .onChange(of: selectedTab) { _, newValue in
                    guard newValue == .settings else { return }
                    withAnimation(reduceMotion ? nil : Motion.smooth) {
                        proxy.scrollTo(Self.topID, anchor: .top)
                    }
                }
            }
        }
        .trackScreen("SettingsView")
        .sheet(isPresented: $showingDebug) {
            TestServicesView()
        }
        .alert("Clear All Data?", isPresented: $showingClearConfirmation) {
            Button("Clear All Data", role: .destructive) {
                viewModel.clearAllData()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This permanently deletes all your recordings and check-ins. Your downloaded transcription model and preferences are kept. This can’t be undone.")
        }
    }

    // MARK: - Sections

    private var aiModelsSection: some View {
        Section("AI Models") {
            ModelDownloadRow(
                title: "Voice Transcription",
                icon: "waveform",
                isInstalled: viewModel.whisperModelInstalled,
                isDownloading: viewModel.isDownloadingWhisper,
                downloadProgress: viewModel.whisperDownloadProgress,
                onDownload: { Task { await viewModel.downloadModel(.whisper) } },
                onDelete: { Task { await viewModel.deleteModel(.whisper) } }
            )
        }
    }

    private var systemSection: some View {
        Section("System") {
            LabeledContent("Storage") {
                let count = viewModel.recordingCount
                Text("\(count) \(count == 1 ? "recording" : "recordings") · \(String(format: "%.1f", viewModel.storageUsedMB)) MB")
                    .foregroundStyle(.secondary)
            }
            Toggle(isOn: $viewModel.downloadOverCellular) {
                Label("Download over Cellular", systemImage: "antenna.radiowaves.left.and.right")
            }
            .onChange(of: viewModel.downloadOverCellular) {
                viewModel.syncDownloadOverCellular()
            }
        }
    }

    private var checkInSection: some View {
        Section {
            Picker("Prompt Pace", selection: $viewModel.promptPace) {
                ForEach(PromptPace.allCases, id: \.self) { pace in
                    Text(pace.displayLabel).tag(pace)
                }
            }
            .onChange(of: viewModel.promptPace) { viewModel.syncPromptPace() }
        } header: {
            Text("Check-in")
        } footer: {
            Text("How long each prompt stays on screen during a voice check-in.")
        }
    }

    private var transcriptionSection: some View {
        Section {
            Toggle(isOn: $viewModel.medicalPromptEnabled) {
                Label("Recognize medication names", systemImage: "pills")
            }
        } header: {
            Text("Transcription")
        } footer: {
            Text("Helps transcription spell medication and side-effect terms correctly.")
        }
    }

    @ViewBuilder
    private var medicationBarSection: some View {
        MedicationBarSettingsSection()
    }

    private var dayCardSection: some View {
        DayCardSettingsSection()
    }

    private var accessibilitySection: some View {
        Section {
            EmptyView()
        } header: {
            Text("Accessibility")
        } footer: {
            Text("Squirl follows the iOS motion setting. Turn on Reduce Motion in Settings › Accessibility to still animations.")
                .font(Typography.caption)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private var dangerSection: some View {
        Section {
            Button(role: .destructive) {
                showingClearConfirmation = true
            } label: {
                Label("Clear All Data", systemImage: "trash")
            }
        }
    }

    private var versionLabel: String {
        let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "Squirl"
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        return "\(name) v\(version)"
    }

    private var versionSection: some View {
        Section {
            HStack {
                Spacer()
                Text(versionLabel)
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
                    #if DEBUG || TESTFLIGHT
                    .onTapGesture(count: 5) { showingDebug = true }
                    #endif
                Spacer()
            }
        }
        .listRowBackground(Color.clear)
    }
}

#Preview {
    SettingsView(store: .preview, services: .preview, selectedTab: .constant(.settings))
        .withPreviewEnvironment()
}
