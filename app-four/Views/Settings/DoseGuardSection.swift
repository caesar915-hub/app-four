import SwiftUI

/// 030 App Intents — Dose Guard (FR-008..FR-012). Native grouped-`List` chrome.
/// off (default) / total / time-window(1–4h). Three always-visible selectable rows
/// with an inline segmented hours control per the approved T011 mockup — one selected
/// value, never independent toggles, no push-navigation. Guards expedited logs only;
/// the in-app Log Dose sheet is never blocked.
struct DoseGuardSection: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Section {
            ForEach(DoseGuardMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation(.snappy) { viewModel.doseGuardMode = mode }
                    viewModel.syncDoseGuard()
                } label: {
                    HStack {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(title(for: mode))
                                Text(subtitle(for: mode))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "shield")
                        }
                        Spacer()
                        if viewModel.doseGuardMode == mode {
                            Image(systemName: "checkmark")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
                .foregroundStyle(.primary)
                .accessibilityAddTraits(viewModel.doseGuardMode == mode ? .isSelected : [])
                .accessibilityHint("Blocks a second hands-free dose log so you don’t double-log.")
            }

            if viewModel.doseGuardMode == .window {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Blocked for")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Picker("Blocked for", selection: $viewModel.doseGuardWindowHours) {
                        ForEach([1, 2, 3, 4], id: \.self) { hours in
                            Text("\(hours) h").tag(hours)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: viewModel.doseGuardWindowHours) { viewModel.syncDoseGuard() }
                    .accessibilityHint("How long a second hands-free dose log stays blocked.")
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("Dose Guard")
        } footer: {
            Text(guardFooter)
        }
    }

    private func title(for mode: DoseGuardMode) -> String {
        switch mode {
        case .off: "Off"
        case .total: "Total"
        case .window: "Time window"
        }
    }

    private func subtitle(for mode: DoseGuardMode) -> String {
        switch mode {
        case .off: "Every trigger logs"
        case .total: "Blocked while a dose is still active"
        case .window: "Blocked for a set time after a dose"
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
