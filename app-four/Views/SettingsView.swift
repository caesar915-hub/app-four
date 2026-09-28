import SwiftUI
import UniformTypeIdentifiers

/// Settings as the pen draws it (spec 057, `iPhone 17 - 16`): a page title and card groups —
/// heading 16/600 over a `.large` / `.medium` card — instead of the native inset-grouped list,
/// plus the rows the pen omits but the product must keep (D7 / D-ST1): the insights-model row,
/// My medication, the medical disclaimer, journal export (never gated), Clear all data, the
/// privacy statement and the version.
struct SettingsView: View {
    @Binding var selectedTab: Tab
    @State private var viewModel: SettingsViewModel
    @State private var showingClearConfirmation = false
    @State private var medicationPickerExpanded = false
    @State private var scrollPosition = ScrollPosition(idType: String.self)
    @Environment(AppIntentRouter.self) private var router
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
    private static let myMedicationID = "settings-my-medication"

    init(store: RecordingStore, services: AppServices, selectedTab: Binding<Tab>) {
        _viewModel = State(wrappedValue: SettingsViewModel(store: store, services: services))
        _selectedTab = selectedTab
    }

    var body: some View {
        ScreenContainer(title: "", showsMedicationBar: true, scrollable: false) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.cardGap) {
                    PageTitleBlock("Settings", subtitle: "Make the app work for you")
                        .id(Self.topID)
                    group("Check-in calendar") { checkInCalendarCard }
                    group("Voice & storage") { voiceAndStorageCard }
                    group("My medication") {
                        MyMedicationSection(viewModel: viewModel, isPickerExpanded: $medicationPickerExpanded)
                    }
                    .id(Self.myMedicationID)
                    group("Confirmations", style: .medium) { ConfirmationsSection(viewModel: viewModel) }
                    group("Dose guard") { DoseGuardSection(viewModel: viewModel) }
                    // The NFC-sticker walkthrough (030 / US4) stays unmounted for 1.1; `StickerSetupView`
                    // remains compiled so restoring it is one group here.
                    group("Medication bar") { MedicationBarSettingsSection() }
                    group("Accessibility", style: .medium) {
                        InfoRow(symbol: Icons.accessibility,
                                text: "Squirl follows the iOS motion setting. Turn on Reduce Motion in Settings › Accessibility to still animations.")
                    }
                    group("Medication info", style: .medium) { MedicalInfoSection() }
                    group("Your data", style: .medium) { yourDataCard }
                    versionLine
                }
                .scrollTargetLayout()
                .padding(.horizontal, Spacing.gutter)
                .padding(.top, Spacing.m)
                // The Add button floats over the last group at rest (D-ST3) — keep it scrollable clear.
                .padding(.bottom, Spacing.hero * 2)
            }
            .scrollPosition($scrollPosition)
            // TabView keeps this tab alive, so its scroll offset persists. Reset to top each time
            // Settings becomes the active tab — unless a My-Medication focus is pending, which
            // owns the scroll instead.
            .onChange(of: selectedTab) { _, newValue in
                guard newValue == .settings, !router.shouldFocusMyMedication else { return }
                withAnimation(reduceMotion ? nil : Motion.smooth) {
                    scrollPosition.scrollTo(id: Self.topID, anchor: .top)
                }
            }
            // Consumes the intent's one-shot focus (FR-007/D13): scrolls the My medication group
            // into view AND opens its picker. `task(id:)` runs on appear and on re-arm, so it
            // covers a cold headless launch, a tab switch, and the already-on-Settings case alike.
            // The anchor parks the group just below the top edge so the heading keeps its room.
            .task(id: router.shouldFocusMyMedication) {
                guard router.shouldFocusMyMedication, router.consumeMyMedicationFocus() else { return }
                medicationPickerExpanded = true
                withAnimation(reduceMotion ? nil : Motion.smooth) {
                    scrollPosition.scrollTo(id: Self.myMedicationID, anchor: UnitPoint(x: 0, y: 0.12))
                }
            }
        }
        .trackScreen("SettingsView")
        .alert("Clear all data?", isPresented: $showingClearConfirmation) {
            Button("Clear all data", role: .destructive) {
                viewModel.clearAllData()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This permanently deletes all your recordings and check-ins. Your downloaded models and preferences are kept. This can’t be undone.")
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

    // MARK: - Group scaffold

    private func group<Content: View>(_ heading: String, style: CardStyle = .large,
                                      @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text(heading)
                .font(Typography.sectionTitle)
                .foregroundStyle(Ink.primary)
                .accessibilityAddTraits(.isHeader)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .card(style)
        }
    }

    // MARK: - Check-in calendar

    private var checkInCalendarCard: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Voice prompts")
                    .font(Typography.rowTitle)
                    .foregroundStyle(Ink.primary)
                    .accessibilityAddTraits(.isHeader)
                Text("How long each prompt stays on screen during a voice check-in.")
                    .font(Typography.captionMedium)
                    .foregroundStyle(Ink.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ChipRow(interactive: true) {
                ForEach([PromptPace.brisk, .relaxed], id: \.self) { pace in
                    ChipButton(pace.displayLabel, selected: viewModel.promptPace == pace) {
                        viewModel.promptPace = pace
                        viewModel.syncPromptPace()
                    }
                }
            }
            .accessibilityLabel("Prompt pace")
            HairlineDivider()
            DayCardSettingsSection()
        }
    }

    // MARK: - Voice & storage

    private var voiceAndStorageCard: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            ModelDownloadRow(
                title: "Voice Transcription",
                icon: Icons.waveform,
                isInstalled: viewModel.whisperModelInstalled,
                isDownloading: viewModel.isDownloadingWhisper,
                downloadProgress: viewModel.whisperDownloadProgress,
                errorMessage: viewModel.downloadErrors[.whisper].map { viewModel.message(for: $0) },
                canAllowCellular: viewModel.canAllowCellular(for: .whisper),
                onDownload: { Task { await viewModel.downloadModel(.whisper) } },
                onRetry: { Task { await viewModel.downloadModel(.whisper) } },
                onCancel: { viewModel.cancelDownload(.whisper) },
                onAllowCellular: {
                    viewModel.downloadOverCellular = true
                    viewModel.syncDownloadOverCellular()
                    Task { await viewModel.downloadModel(.whisper) }
                },
                onDelete: { Task { await viewModel.deleteModel(.whisper) } }
            )
            HairlineDivider()
            ModelDownloadRow(
                title: "Journal Insights",
                icon: Icons.brain,
                isInstalled: viewModel.llmModelInstalled,
                isDownloading: viewModel.isDownloadingLLM,
                downloadProgress: viewModel.llmDownloadProgress,
                errorMessage: viewModel.downloadErrors[.llm].map { viewModel.message(for: $0) },
                canAllowCellular: viewModel.canAllowCellular(for: .llm),
                onDownload: { Task { await viewModel.downloadModel(.llm) } },
                onRetry: { Task { await viewModel.downloadModel(.llm) } },
                onCancel: { viewModel.cancelDownload(.llm) },
                onAllowCellular: {
                    viewModel.downloadOverCellular = true
                    viewModel.syncDownloadOverCellular()
                    Task { await viewModel.downloadModel(.llm) }
                },
                onDelete: { Task { await viewModel.deleteModel(.llm) } }
            )
            HairlineDivider()
            HStack(spacing: Spacing.m) {
                Image(systemName: Icons.record)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Accent.primaryText)
                    .frame(width: 21, height: 21)
                    .accessibilityHidden(true)
                Text("Storage")
                    .font(Typography.rowLabel)
                    .foregroundStyle(Ink.primary)
                Spacer(minLength: Spacing.s)
                Text(storageValue)
                    .font(Typography.captionMedium)
                    .foregroundStyle(Ink.secondary)
                    .multilineTextAlignment(.trailing)
            }
            .frame(minHeight: Metrics.minTapTarget)
            .accessibilityElement(children: .combine)
            HairlineDivider()
            ToggleRow("Download over cellular",
                      description: "Allow model downloads over mobile data — the voice model and the insights model.",
                      isOn: $viewModel.downloadOverCellular)
                .onChange(of: viewModel.downloadOverCellular) { viewModel.syncDownloadOverCellular() }
        }
    }

    private var storageValue: String {
        let count = viewModel.recordingCount
        return "\(String(format: "%.1f", viewModel.storageUsedMB)) MB · \(count) \(count == 1 ? "recording" : "recordings")"
    }

    // MARK: - Your data (statement, links, export, clear)

    private var yourDataCard: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            YourDataSection()
            HairlineDivider()
            Button(action: startExport) {
                HStack(spacing: Spacing.m) {
                    Image(systemName: Icons.export)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Accent.primaryText)
                        .frame(width: 21, height: 21)
                        .accessibilityHidden(true)
                    Text("Save a copy of my journal — yours to keep")
                        .font(Typography.rowLabel)
                        .foregroundStyle(Ink.primary)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: Spacing.s)
                    if isPreparingExport {
                        ProgressView().tint(Accent.primaryFill)
                    } else {
                        Image(systemName: Icons.chevronRight)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Ink.primary)
                            .accessibilityHidden(true)
                    }
                }
                .frame(minHeight: Metrics.minTapTarget)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .disabled(isPreparingExport)
            Text("Saves one encrypted file you can keep or share. We’ll show you a key to open it — keep it safe. If you lose the key, the backup can’t be recovered — not even by us.")
                .font(Typography.captionMedium)
                .foregroundStyle(Ink.tertiary)
                .fixedSize(horizontal: false, vertical: true)
            HairlineDivider()
            Button(role: .destructive) {
                showingClearConfirmation = true
            } label: {
                HStack(spacing: Spacing.m) {
                    Image(systemName: Icons.trash)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Ink.destructive)
                        .frame(width: 21, height: 21)
                        .accessibilityHidden(true)
                    Text("Clear all data")
                        .font(Typography.rowLabel)
                        .foregroundStyle(Ink.destructive)
                    Spacer(minLength: 0)
                }
                .frame(minHeight: Metrics.minTapTarget)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
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

    // MARK: - Version

    private var versionLabel: String {
        let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "Squirl"
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        return "\(name) v\(version)"
    }

    private var versionLine: some View {
        Text(versionLabel)
            .font(Typography.captionQuiet)
            .foregroundStyle(Ink.tertiary)
            .frame(maxWidth: .infinity)
    }
}

#Preview {
    SettingsView(store: .preview, services: .preview, selectedTab: .constant(.settings))
        .withPreviewEnvironment()
}
