import SwiftUI

struct CalendarContextSection: View {
    @Environment(AppServices.self) private var services
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage(CalendarPreferences.Keys.calendarTitlesIncluded) private var titlesIncluded = true

    @State private var accessState: CalendarAccessState = .notDetermined
    @State private var calendars: [CalendarDescriptor] = []
    @State private var excludedIDs: Set<String> = []
    @State private var includedOverrideIDs: Set<String> = []

    @State private var showExplainer = false
    @State private var showRecaptureDialog = false
    @State private var showRemoveDialog = false

    var body: some View {
        Section("Calendar") {
            switch accessState {
            case .notDetermined:
                notDeterminedRow
            case .denied, .restricted, .writeOnly:
                // writeOnly grants calendar WRITING only; day context needs to READ
                // events, so capture never runs — treat it as insufficient, not "Granted".
                deniedRow
            case .fullAccess:
                fullAccessRows
            }
        }
        .task { await loadState() }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await loadState() }
        }
        .sheet(isPresented: $showExplainer) {
            CalendarExplainerSheet(onFinished: { Task { await loadState() } })
        }
        .confirmationDialog(
            "Re-capture History?",
            isPresented: $showRecaptureDialog,
            titleVisibility: .visible
        ) {
            Button("Re-capture History") {
                Task { await services.calendarCoordinator.recaptureAll() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Squirl will re-read your calendar for every past check-in day using your current calendar and title settings. Existing context is replaced. This may take a minute.")
        }
        .confirmationDialog(
            "Remove Calendar Context?",
            isPresented: $showRemoveDialog,
            titleVisibility: .visible
        ) {
            Button("Remove Calendar Context", role: .destructive) {
                services.dayContextStore.purgeAll()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the calendar summary from every day in your journal. Your check-ins and their signals are unaffected. This can't be undone.")
        }
    }

    // MARK: - State branches

    private var notDeterminedRow: some View {
        Button {
            showExplainer = true
        } label: {
            HStack {
                Label("Connect calendar", systemImage: "calendar")
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("See what each day held")
                        .font(Typography.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .accessibilityHint("Opens the Calendar setup guide.")
    }

    private var deniedRow: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundStyle(Theme.danger)
                Text("Access not allowed")
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
            }
            Text("Squirl doesn't have full calendar access, so it can't read your calendar to provide day context. Open Settings and allow full access.")
                .font(Typography.caption)
                .foregroundStyle(Theme.textSecondary)
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            } label: {
                Label("Open Settings", systemImage: "arrow.up.right")
                    .font(Typography.caption)
                    .foregroundStyle(Theme.accent)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens the system Settings app to change calendar permissions.")
        }
        .padding(.vertical, Spacing.s)
    }

    @ViewBuilder
    private var fullAccessRows: some View {
        // Access status
        HStack {
            Label("Calendar access", systemImage: "calendar.badge.checkmark")
            Spacer()
            Text("Granted")
                .font(Typography.caption)
                .foregroundStyle(Theme.statusDone)
        }

        // Per-calendar picker
        if !calendars.isEmpty {
            ForEach(calendars) { descriptor in
                let included = CalendarInclusion.isIncluded(
                    descriptor,
                    excludedIDs: excludedIDs,
                    includedOverrideIDs: includedOverrideIDs
                )
                let isDefaultOff = CalendarInclusion.defaultExcludedClass(descriptor)

                Toggle(isOn: Binding(
                    get: { included },
                    set: { newValue in toggleCalendar(descriptor, on: newValue) }
                )) {
                    HStack(spacing: Spacing.s) {
                        Text(descriptor.title)
                        if isDefaultOff && !included {
                            Text("Off by default")
                                .font(Typography.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
                .accessibilityHint(isDefaultOff
                    ? "Off by default — birthday and subscribed calendars are excluded unless you turn them on."
                    : "Toggle to include or exclude this calendar from day context capture.")
            }
        }

        // Privacy — titles toggle
        Section(header: Text("Privacy")) {
            Toggle(isOn: $titlesIncluded) {
                Label("Capture event titles", systemImage: "eye")
            }
            .accessibilityHint("When off, event titles are not saved. Only timing and attendance are captured.")

            if !titlesIncluded {
                Text("Applies to new captures only. Previously captured titles remain. Use 'Re-capture history' to remove them from past days too.")
                    .font(Typography.caption)
                    .foregroundStyle(Theme.meadowAmber)
            }
        }

        // Data actions
        Section(header: Text("Data")) {
            Button("Re-capture history with current settings") {
                showRecaptureDialog = true
            }
            .foregroundStyle(Theme.accent)

            Button("Remove captured calendar context") {
                showRemoveDialog = true
            }
            .foregroundStyle(Theme.danger)
        }
    }

    // MARK: - Helpers

    private func loadState() async {
        async let state = services.calendarContextService.accessState()
        async let cals = services.calendarContextService.availableCalendars()
        let (newState, newCals) = await (state, cals)
        accessState = newState
        calendars = newCals
        excludedIDs = CalendarPreferences.excludedIDs()
        includedOverrideIDs = CalendarPreferences.includedOverrideIDs()
    }

    private func toggleCalendar(_ descriptor: CalendarDescriptor, on: Bool) {
        if on {
            excludedIDs.remove(descriptor.id)
            if CalendarInclusion.defaultExcludedClass(descriptor) {
                includedOverrideIDs.insert(descriptor.id)
            }
        } else {
            excludedIDs.insert(descriptor.id)
            includedOverrideIDs.remove(descriptor.id)
        }
        CalendarPreferences.setExcludedIDs(excludedIDs)
        CalendarPreferences.setIncludedOverrideIDs(includedOverrideIDs)
    }
}

#Preview {
    List {
        CalendarContextSection()
    }
    .listStyle(.insetGrouped)
    .environment(AppServices.preview)
}
