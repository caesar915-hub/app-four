import SwiftUI

/// Settings › Dose guard (030 App Intents, FR-008..FR-012): three `RadioRow`s — one selected
/// value, never independent toggles — the "Blocked for" chips shown only for Time window, and
/// the per-mode footnote. Guards expedited logs only; the in-app Log Dose sheet is never blocked.
struct DoseGuardSection: View {
    @Bindable var viewModel: SettingsViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            ForEach(Array(DoseGuardMode.allCases.enumerated()), id: \.element) { index, mode in
                if index > 0 { HairlineDivider() }
                RadioRow(title(for: mode), subtitle: subtitle(for: mode), isSelected: viewModel.doseGuardMode == mode) {
                    withAnimation(reduceMotion ? nil : Motion.snappy) { viewModel.doseGuardMode = mode }
                    viewModel.syncDoseGuard()
                }
                .accessibilityHint(hint(for: mode))
            }

            if viewModel.doseGuardMode == .window {
                HairlineDivider()
                ChipGroupView("Blocked for") {
                    ForEach([1, 2, 3, 4], id: \.self) { hours in
                        let selected = viewModel.doseGuardWindowHours == hours
                        Button {
                            withAnimation(reduceMotion ? nil : Motion.snappy) { viewModel.doseGuardWindowHours = hours }
                            viewModel.syncDoseGuard()
                        } label: {
                            BillChip("\(hours) h", style: selected ? .solidWithCheck : .outline)
                                .frame(minHeight: Metrics.minTapTarget)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(hours) hours")
                        .accessibilityAddTraits(selected ? [.isSelected] : [])
                    }
                }
                .accessibilityHint("How long a second hands-free dose log stays blocked.")
            }

            HairlineDivider()
            InfoRow(symbol: Icons.info, text: guardFooter)
        }
        .animation(reduceMotion ? nil : Motion.expand, value: viewModel.doseGuardMode)
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

    private func hint(for mode: DoseGuardMode) -> String {
        switch mode {
        case .off: "Turns off double-log protection — every hands-free trigger logs a dose."
        case .total: "Blocks a second hands-free dose log while your last dose is still active."
        case .window: "Blocks a second hands-free dose log for a time you set."
        }
    }

    private var guardFooter: String {
        let scope = " The in-app Log Dose sheet is never blocked."
        switch viewModel.doseGuardMode {
        case .off:
            return "Every trigger logs. Guards expedited logs only — Siri or Shortcuts." + scope
        case .total:
            return "A second log is blocked while your last dose is still active." + scope
        case .window:
            return "A second log is blocked for \(viewModel.doseGuardWindowHours) h after your last dose." + scope
        }
    }
}
