import SwiftUI
import SwiftData

/// Compact per-day read surface for the four signals. Sleep renders as the bed icon +
/// indigo + named `SleepLevel` (no colour beads — deferred per DESIGN.md); the others
/// are plain values. A trailing glyph marks each group's source. Tapping edit opens the
/// manual editor. (Apple Health sync is wired in User Story 2.)
struct DaySignalsSummaryView: View {
    let dayStart: Date
    let store: SignalsStore
    let coordinator: SignalSyncCoordinator
    let health: HealthDataReading

    @State private var row: DailySignals?
    @State private var showingEditor = false
    @State private var showingPrimer = false
    @AppStorage("didOfferHealthAccess") private var didOfferHealthAccess = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Signals").font(.headline)
                Spacer()
                Button { showingEditor = true } label: {
                    Image(systemName: "square.and.pencil")
                }
                .accessibilityLabel("Edit day signals")
            }
            sleepRow
            signalRow("Activity", value: activityText, source: row?.activitySource ?? .none)
            signalRow("Heart", value: heartText, source: row?.heartSource ?? .none)
            signalRow("Cycle", value: cycleText, source: row?.cycleSource ?? .none)
        }
        .padding()
        .task { await onAppear() }
        .refreshable { await forceSyncAndRefresh() }
        .sheet(isPresented: $showingEditor, onDismiss: refresh) {
            DaySignalsEditorSheet(
                viewModel: DaySignalsEditorViewModel(dayStart: dayStart, store: store)
            )
        }
        .sheet(isPresented: $showingPrimer, onDismiss: { Task { await forceSyncAndRefresh() } }) {
            HealthAccessPrimerView(health: health) { _ in didOfferHealthAccess = true }
        }
    }

    /// Cached-first: render stored data immediately, then — if HealthKit is available —
    /// either offer the one-time access primer (first run, FR-005) or run the once-per-day
    /// sync. The manual path is fully usable regardless.
    private func onAppear() async {
        refresh()
        guard await health.authorizationState() != .unavailable else { return }
        if didOfferHealthAccess {
            await syncRecentAndRefresh()
        } else {
            showingPrimer = true
        }
    }

    private func syncRecentAndRefresh() async {
        do {
            try await coordinator.syncRecentIfNeeded(lastDays: 30)
        } catch is CancellationError {
        } catch {
            AppLogger.log("DaySignals sync failed: \(error)")
        }
        refresh()
    }

    /// Pull-to-refresh / post-grant: force a fresh 30-day read.
    private func forceSyncAndRefresh() async {
        do {
            try await coordinator.sync(lastDays: 30)
        } catch is CancellationError {
        } catch {
            AppLogger.log("DaySignals sync failed: \(error)")
        }
        refresh()
    }

    private func refresh() {
        row = store.fetch(dayStart: dayStart)
    }

    private var sleepRow: some View {
        HStack(spacing: 8) {
            BedIcon().frame(width: 20, height: 20)
            Text("Sleep").foregroundStyle(.secondary)
            Spacer()
            Text(sleepText)
            sourceGlyph(row?.sleepSource ?? .none)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Sleep: \(sleepText), \(sourceA11y(row?.sleepSource ?? .none))")
    }

    private func signalRow(_ title: String, value: String, source: SignalSource) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value)
            sourceGlyph(source)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value), \(sourceA11y(source))")
    }

    @ViewBuilder
    private func sourceGlyph(_ source: SignalSource) -> some View {
        Group {
            switch source {
            case .healthKit: Image(systemName: "heart.fill").foregroundStyle(Palette.sleepIndigo)
            case .manual: Image(systemName: "pencil").foregroundStyle(.secondary)
            case .none: Image(systemName: "minus").foregroundStyle(.tertiary)
            }
        }
        .font(.caption2)
        .accessibilityHidden(true)
    }

    private func sourceA11y(_ source: SignalSource) -> String {
        switch source {
        case .healthKit: "from Apple Health"
        case .manual: "added by you"
        case .none: "not set"
        }
    }

    private var sleepText: String {
        let level = row?.sleepLevel.map { $0.rawValue.capitalized }
        guard let hours = row?.sleepHours else { return level ?? "—" }
        return level.map { String(format: "%.1f h · %@", hours, $0) } ?? String(format: "%.1f h", hours)
    }

    private var activityText: String { row?.steps.map { "\($0) steps" } ?? "—" }
    private var heartText: String { row?.restingHeartRate.map { String(format: "%.0f bpm", $0) } ?? "—" }
    private var cycleText: String { row?.menstrualFlow.map { $0.rawValue.capitalized } ?? "—" }
}

#Preview {
    let store = SignalsStore(context: AppModelContainer.previewContainer.mainContext)
    let health = HealthKitServiceImpl()
    let coordinator = SignalSyncCoordinator(reader: health, store: store)
    return DaySignalsSummaryView(
        dayStart: SignalDayKey.dayStart(for: .now),
        store: store,
        coordinator: coordinator,
        health: health
    )
}
