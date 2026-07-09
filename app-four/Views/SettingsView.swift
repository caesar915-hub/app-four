import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Binding var selectedTab: Tab
    @State private var viewModel: SettingsViewModel
    @State private var showingDebug = false
    @State private var showingClearConfirmation = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Encrypted-export flow. The recovery key lives only here, in transient view
    // state for the duration of the key sheet — it is never persisted (US3, T034).
    @State private var isPreparingExport = false
    @State private var exportDocument: EncryptedJournalDocument?
    @State private var isPresentingFileExporter = false
    @State private var pendingRecoveryKey: String?
    @State private var recoveryKey: RecoveryKey?
    @State private var exportFailed = false

    /// Identifiable wrapper so the recovery key can drive `.sheet(item:)`.
    private struct RecoveryKey: Identifiable {
        let value: String
        var id: String { value }
    }

    private var exportFilename: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "Squirl Journal \(formatter.string(from: .now))"
    }

    private static let topID = "settings-top"

    init(store: RecordingStore, services: AppServices, selectedTab: Binding<Tab>) {
        _viewModel = State(wrappedValue: SettingsViewModel(store: store, services: services))
        _selectedTab = selectedTab
    }

    var body: some View {
        // List manages its own scroll — ScreenContainer is non-scrollable here.
        // The inline navigation title is exposed to VoiceOver as a heading by default,
        // so passing it here both shows "Settings" and gives the screen a landmark.
        ScreenContainer(title: "", showsMedicationBar: true, scrollable: false) {
            ScrollViewReader { proxy in
                List {
                    aiModelsSection
                        .id(Self.topID)
                    systemSection
                    checkInSection
                    dayCardSection
                    MyMedicationSection(viewModel: viewModel)
                    DoseGuardSection(viewModel: viewModel)
                    medicationBarSection
                    accessibilitySection
                    YourDataSection()
                    journalExportSection
                    dangerSection
                    versionSection
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)        // reveal Theme.background (paper) under the grouped list
                .listRowBackground(Theme.cardBackground)  // cream inset cards instead of system grouped gray
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
        .fileExporter(
            isPresented: $isPresentingFileExporter,
            document: exportDocument,
            contentType: .data,
            defaultFilename: exportFilename
        ) { result in
            exportDocument = nil
            // Surface the recovery key only after the file is safely written, so the
            // user has the backup in hand before being shown its only key.
            if case .success = result, let key = pendingRecoveryKey {
                recoveryKey = RecoveryKey(value: key)
            }
            pendingRecoveryKey = nil
        }
        .sheet(item: $recoveryKey) { key in
            RecoveryKeySheet(keyBase64: key.value) { recoveryKey = nil }
        }
        .alert("Couldn’t save a copy", isPresented: $exportFailed) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Something went wrong preparing your backup. Please try again.")
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
                errorMessage: viewModel.downloadError.map { viewModel.message(for: $0) },
                canAllowCellular: viewModel.canAllowCellular,
                onDownload: { Task { await viewModel.downloadModel(.whisper) } },
                onRetry: { Task { await viewModel.downloadModel(.whisper) } },
                onCancel: { viewModel.cancelDownload() },
                onAllowCellular: {
                    viewModel.downloadOverCellular = true
                    viewModel.syncDownloadOverCellular()
                    Task { await viewModel.downloadModel(.whisper) }
                },
                onDelete: { Task { await viewModel.deleteModel(.whisper) } }
            )
        }
    }

    private var systemSection: some View {
        Section("System") {
            LabeledContent("Storage") {
                let count = viewModel.recordingCount
                Text("\(count) \(count == 1 ? "recording" : "recordings") · \(String(format: "%.1f", viewModel.storageUsedMB)) MB")
                    .foregroundStyle(Theme.textSecondary)
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

    private var dayCardSection: some View {
        DayCardSettingsSection()
    }

    private var accessibilitySection: some View {
        Section("Accessibility") {
            Text("Squirl follows the iOS motion setting. Turn on Reduce Motion in Settings › Accessibility to still animations.")
                .font(Typography.caption)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private var journalExportSection: some View {
        Section {
            Button(action: startExport) {
                HStack {
                    Label("Save a copy of my journal — yours to keep", systemImage: "lock.doc")
                    if isPreparingExport {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled(isPreparingExport)
        } footer: {
            Text("Saves one encrypted file you can keep or share. We’ll show you a key to open it — keep it safe. If you lose the key, the backup can’t be recovered — not even by us.")
        }
    }

    private func startExport() {
        guard !isPreparingExport else { return }
        isPreparingExport = true
        Task {
            defer { isPreparingExport = false }
            do {
                let result = try await viewModel.exportJournal()
                exportDocument = EncryptedJournalDocument(data: result.data)
                pendingRecoveryKey = result.keyBase64
                isPresentingFileExporter = true
            } catch {
                exportFailed = true
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
                    .foregroundStyle(Theme.textSecondary)
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
