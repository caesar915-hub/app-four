import SwiftUI

/// 030 App Intents — Dose Guard (FR-008..FR-012). Native grouped-`List` chrome.
/// off (default) / total / time-window(1–4h). One selected value — never independent
/// toggles. Guards expedited logs only; the in-app Log Dose sheet is never blocked.
struct DoseGuardSection: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Section {
            Picker(selection: $viewModel.doseGuardMode) {
                Text("Off").tag(DoseGuardMode.off)
                Text("Total").tag(DoseGuardMode.total)
                Text("Time window").tag(DoseGuardMode.window)
            } label: {
                Label("Dose Guard", systemImage: "shield")
            }
            .onChange(of: viewModel.doseGuardMode) { viewModel.syncDoseGuard() }
            .accessibilityHint("Blocks a second hands-free dose log so you don’t double-log.")

            if viewModel.doseGuardMode == .window {
                Picker(selection: $viewModel.doseGuardWindowHours) {
                    ForEach([1, 2, 3, 4], id: \.self) { hours in
                        Text("\(hours) h").tag(hours)
                    }
                } label: {
                    Label("Blocked for", systemImage: "clock")
                }
                .onChange(of: viewModel.doseGuardWindowHours) { viewModel.syncDoseGuard() }
            }
        } header: {
            Text("Dose Guard")
        } footer: {
            Text(guardFooter)
        }
    }

    private var guardFooter: String {
        let scope = " The in-app Log Dose sheet is never blocked."
        switch viewModel.doseGuardMode {
        case .off:
            return "Every trigger logs. Guards expedited logs only — sticker, Siri, or Shortcuts." + scope
        case .total:
            return "A second log is blocked while your last dose is still active." + scope
        case .window:
            return "A second log is blocked for \(viewModel.doseGuardWindowHours) h after your last dose." + scope
        }
    }
}
