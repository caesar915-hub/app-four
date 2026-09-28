import SwiftUI

/// The pen's medication bar (DESIGN.md §8.10): a small card of dose rows — badge · "HH:mm" ·
/// name + dose · status word — each over a 10-pt violet progress track. Tapping a row offers
/// "Log new dose" / "Delete this dose". A worn-off dose goes quiet (grey word, dimmed row).
struct MedicationBarView: View {
    @Environment(MedicationBarViewModel.self) private var viewModel
    @State private var showLogSheet = false
    @State private var selectedDose: MedicationBarViewModel.DoseDisplay? = nil

    @AppStorage("medicationBarVisible") private var showBar = true
    @AppStorage("medicationBarShowName") private var showName = true
    @AppStorage("medicationBarShowTakenTime") private var showTakenTime = true
    @AppStorage("medicationBarShowEndTime") private var showEndTime = false

    private var titleOptions: MedicationBarViewModel.DoseDisplay.TitleOptions {
        .init(showName: showName, showTakenTime: showTakenTime, showEndTime: showEndTime)
    }

    var body: some View {
        if showBar, !viewModel.activeDoses.isEmpty {
            VStack(spacing: Spacing.m) {
                ForEach(Array(viewModel.activeDoses.enumerated()), id: \.element.eventID) { index, dose in
                    if index > 0 { HairlineDivider() }
                    DoseRow(dose: dose, options: titleOptions) { selectedDose = dose }
                }
            }
            .card(.small)
            .confirmationDialog(
                selectedDose.map { "\($0.name)\($0.dose.map { " \($0)" } ?? "")" } ?? "",
                isPresented: Binding(
                    get: { selectedDose != nil },
                    set: { if !$0 { selectedDose = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Log new dose") {
                    selectedDose = nil
                    showLogSheet = true
                }
                if let dose = selectedDose {
                    Button("Delete this dose", role: .destructive) {
                        viewModel.deleteEvent(id: dose.eventID)
                        selectedDose = nil
                    }
                }
                Button("Cancel", role: .cancel) { selectedDose = nil }
            }
            .sheet(isPresented: $showLogSheet) {
                MedicationLogSheet(onLog: { name, dose, time, duration in
                    viewModel.logManualDose(name: name, dose: dose, takenAt: time, durationHours: duration)
                })
            }
            .onAppear { viewModel.refresh() }
        }
    }
}

// MARK: - Row

private struct DoseRow: View {
    let dose: MedicationBarViewModel.DoseDisplay
    let options: MedicationBarViewModel.DoseDisplay.TitleOptions
    let onTap: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulsing = false

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    private var isWornOff: Bool { dose.status == .wornOff }
    /// Today's only "kicking in" cue: a soft opacity pulse on the fill during onset, never under Reduce Motion.
    private var onsetPulsing: Bool { dose.status == .kickingIn && !reduceMotion }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: Spacing.s) {
                HStack(spacing: Spacing.s) {
                    MedicationBadge()
                    title
                        .lineLimit(1)
                    Spacer(minLength: Spacing.s)
                    Text(dose.status.displayLabel)
                        .font(Typography.status)
                        .foregroundStyle(isWornOff ? Ink.tertiary : Accent.primaryText)
                        .lineLimit(1)
                }
                ProgressTrack(fraction: dose.progress)
                    .opacity(onsetPulsing && pulsing ? 0.55 : 1)
            }
            .opacity(isWornOff ? 0.6 : 1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .onAppear { syncPulse() }
        .onChange(of: onsetPulsing) { _, _ in syncPulse() }
    }

    /// "09:54 • Concerta 36 mg • ends 21:54" — the first part 14/600, the rest 12/500 secondary
    /// (`DoseDisplay.titleParts`, Settings › Medication bar).
    private var title: Text {
        let parts = dose.titleParts(options) { Self.timeFormatter.string(from: $0) }
        let lead = Text(parts[0])
            .font(Typography.rowTitle)
            .foregroundStyle(Ink.primary)
        guard parts.count > 1 else { return lead }
        let rest = Text(" • " + parts.dropFirst().joined(separator: " • "))
            .font(Typography.captionMedium)
            .foregroundStyle(Ink.secondary)
        return Text("\(lead)\(rest)")
    }

    private var nameText: String { dose.nameText }

    private var accessibilityLabel: String {
        let taken = Self.timeFormatter.string(from: dose.takenAt)
        let ends = Self.timeFormatter.string(from: dose.endsAt)
        let percent = Int(dose.progress * 100)
        let ordinalPrefix = dose.totalDosesToday > 1 ? "\(ordinal(dose.doseNumber)) dose, " : ""
        return "\(ordinalPrefix)\(nameText), taken at \(taken), \(dose.status.displayLabel.lowercased()), \(percent)% elapsed, ends \(ends). Tap to manage."
    }

    private func ordinal(_ n: Int) -> String {
        switch n {
        case 1: "1st"
        case 2: "2nd"
        case 3: "3rd"
        default: "\(n)th"
        }
    }

    private func syncPulse() {
        if onsetPulsing {
            withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) { pulsing = true }
        } else {
            withAnimation(.easeInOut(duration: 0.2)) { pulsing = false }
        }
    }
}

#Preview {
    VStack {
        MedicationBarView()
            .padding(.horizontal, Spacing.gutter)
        Spacer()
    }
    .background(Surface.screen)
    .environment(MedicationBarViewModel())
}
