import SwiftUI

/// Settings › Apple Health (spec 031 US4): pause syncing and delete imported data.
/// Native grouped-list chrome — Settings is exempt from the Paper & Pollen face rule
/// (DESIGN.md 2026-06-24). One switch gates every sync path via `SignalSyncCoordinator`;
/// deletion removes the app's imported copies only (manual + demo data survive).
struct HealthSettingsSection: View {
    @AppStorage("healthSyncEnabled") private var syncEnabled = true
    @AppStorage("healthLastSyncAt") private var lastSyncAt: Double = 0

    @State private var showDeleteConfirmation = false
    @State private var showStopAndDelete = false

    var body: some View {
        Section {
            Toggle("Sync from Apple Health", isOn: $syncEnabled)
                .onChange(of: syncEnabled) { _, enabled in
                    if enabled {
                        // Clear the once-per-day throttle so the next calendar/Insights visit
                        // re-imports this session, not only after relaunch (US4 Scenario 4).
                        AppDependencies.signalSyncCoordinator.resetSyncThrottle()
                    } else {
                        showStopAndDelete = true
                    }
                }

            LabeledContent("Last sync", value: lastSyncLabel)
                .foregroundStyle(.secondary)

            Button("Delete Imported Health Data…", role: .destructive) {
                showDeleteConfirmation = true
            }
        } header: {
            Text("Apple Health")
        } footer: {
            Text("Sleep, activity, heart, cycle, nutrition, and workouts are read from Apple Health once a day and stored only on this device. To change what Squirl can read, open the Health app › Sharing.")
        }
        .confirmationDialog("Delete imported Health data?",
                            isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete Imported Data", role: .destructive, action: deleteImported)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(deleteMessage)
        }
        .confirmationDialog("Stop syncing?", isPresented: $showStopAndDelete, titleVisibility: .visible) {
            Button("Keep Data", role: .cancel) {}
            Button("Delete Imported Data", role: .destructive, action: deleteImported)
        } message: {
            Text("Syncing is paused. \(deleteMessage)")
        }
    }

    private var deleteMessage: String {
        "Removes everything Squirl copied from Apple Health on this device — nutrition, workouts, sleep, activity, heart, and cycle. Manual entries and demo data are kept. Apple Health itself is not changed."
    }

    private var lastSyncLabel: String {
        guard lastSyncAt > 0 else { return "Never" }
        let date = Date(timeIntervalSinceReferenceDate: lastSyncAt)
        return date.formatted(.relative(presentation: .named))
    }

    private func deleteImported() {
        AppDependencies.signalsStore.deleteImportedHealthData()
        try? AppDependencies.signalsStore.save()
        NotificationCenter.default.post(name: .nutritionEventsDidChange, object: nil)
    }
}
