import SwiftUI

struct SettingsView: View {
    @State private var viewModel: SettingsViewModel
    @State private var showingDebug = false
    @State private var showingClearConfirmation = false

    init(store: RecordingStore, services: AppServices) {
        _viewModel = State(wrappedValue: SettingsViewModel(store: store, services: services))
    }

    var body: some View {
        // List manages its own scroll — ScreenContainer is non-scrollable here
        ScreenContainer(title: "", showsMedicationBar: true, scrollable: false) {
            List {
                aiModelsSection
                systemSection
                checkInSection
                medicationBarSection
                accessibilitySection
                dangerSection
                versionSection
            }
            .listStyle(.insetGrouped)
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
                title: "Whisper Transcription",
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

    @ViewBuilder
    private var medicationBarSection: some View {
        MedicationBarSettingsSection()
    }

    private var accessibilitySection: some View {
        Section("Accessibility") {
            Toggle(isOn: $viewModel.medicalPromptEnabled) {
                Label("Medical Context Prompt", systemImage: "pills")
            }
            Toggle(isOn: $viewModel.reduceMotion) {
                Label("Reduce Motion", systemImage: "figure.walk")
            }
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

    private var versionSection: some View {
        Section {
            HStack {
                Spacer()
                Text("WhisperNotes v1.0.0")
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
    SettingsView(store: .preview, services: .preview)
        .withPreviewEnvironment()
}
