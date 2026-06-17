import SwiftUI

struct MedicationBarView: View {
    @Environment(MedicationBarViewModel.self) private var viewModel
    @State private var showLogSheet = false
    @State private var selectedDose: MedicationBarViewModel.DoseDisplay? = nil

    @AppStorage("medicationBarVisible") private var showBar = true
    @AppStorage("medicationBarShowName") private var showName = true
    @AppStorage("medicationBarShowTime") private var showTime = true
    @AppStorage("medicationBarShowEndTime") private var showEndTime = true

    var body: some View {
        if showBar, !viewModel.activeDoses.isEmpty {
            VStack(spacing: Spacing.s) {
                ForEach(Array(viewModel.activeDoses.enumerated()), id: \.element.eventID) { index, dose in
                    if index > 0 { Divider().overlay(Theme.separator) }
                    doseRow(dose)
                }
            }
            .card(padding: Spacing.m)
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

    // MARK: - Single row

    private func doseRow(_ dose: MedicationBarViewModel.DoseDisplay) -> some View {
        Button { selectedDose = dose } label: {
            HStack(spacing: Spacing.s) {
                SignalGlyph(.medication, size: 28, decorative: true)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack(spacing: Spacing.s) {
                        Text(nameLine(dose: dose))
                            .font(Typography.subheadline)
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        Text(stateWord(for: dose.progress))
                            .font(Typography.label)
                            .foregroundStyle(Palette.medication)
                            .lineLimit(1)
                    }
                    DoseTrack(progress: dose.progress)
                    if !subLine(dose: dose).isEmpty {
                        Text(subLine(dose: dose))
                            .font(Typography.mono12)
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(dose: dose))
    }

    /// Stage by fill amount only — 0–20% kicking in · 20–80% active · 80–100% wearing off.
    /// Never red/alarming (locked decision).
    private func stateWord(for progress: Double) -> String {
        switch progress {
        case ..<0.2: return "kicking in"
        case ..<0.8: return "active"
        case ..<1.0: return "wearing off"
        default:     return "worn off"
        }
    }

    // MARK: - Labels

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    /// Top line — bold med name (with ordinal when multiple doses today). Identity always shows.
    private func nameLine(dose: MedicationBarViewModel.DoseDisplay) -> String {
        var parts: [String] = []
        if dose.totalDosesToday > 1 {
            parts.append(ordinal(dose.doseNumber) + " dose")
        }
        if showName {
            parts.append(dose.effectiveDose.map { "\(dose.name) \($0)" } ?? dose.name)
        }
        return parts.isEmpty ? dose.name : parts.joined(separator: " · ")
    }

    /// Mono sub-line — "taken 9:15 · onset · ends 19:15" (toggles honored).
    private func subLine(dose: MedicationBarViewModel.DoseDisplay) -> String {
        var parts: [String] = []
        if showTime {
            parts.append("taken \(Self.timeFormatter.string(from: dose.takenAt))")
        }
        if dose.progress < 0.2 {
            parts.append("onset")
        }
        if showEndTime {
            parts.append("ends \(Self.timeFormatter.string(from: dose.endsAt))")
        }
        return parts.joined(separator: " · ")
    }

    private func accessibilityLabel(dose: MedicationBarViewModel.DoseDisplay) -> String {
        let nameText = dose.effectiveDose.map { "\(dose.name) \($0)" } ?? dose.name
        let taken = Self.timeFormatter.string(from: dose.takenAt)
        let ends = Self.timeFormatter.string(from: dose.endsAt)
        let percent = Int(dose.progress * 100)
        let ordinalPrefix = dose.totalDosesToday > 1 ? "\(ordinal(dose.doseNumber)) dose, " : ""
        return "\(ordinalPrefix)\(nameText), taken at \(taken), \(percent)% elapsed, ends \(ends). Tap to manage."
    }

    private func ordinal(_ n: Int) -> String {
        switch n {
        case 1: return "1st"
        case 2: return "2nd"
        case 3: return "3rd"
        default: return "\(n)th"
        }
    }
}

// MARK: - Track

/// Slim progress track: a surface-2 groove with a medication-purple fill that grows
/// empty→full across the dose window, pulsing softly during onset (<20%). One purple,
/// fill amount only — never red. Reduce Motion collapses to a static fill.
private struct DoseTrack: View {
    let progress: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulsing = false

    /// Pulse only during onset (<20%) and never under Reduce Motion.
    private var onsetPulsing: Bool { progress < 0.2 && !reduceMotion }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.surface2)
                Capsule()
                    .fill(Palette.medication)
                    .frame(width: max(6, geo.size.width * progress))
                    .opacity(onsetPulsing && pulsing ? 0.55 : 1)
            }
        }
        .frame(height: 8)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.5), value: progress)
        .onAppear { syncPulse() }
        // React to onset ending and to a live Reduce-Motion toggle, so the
        // repeatForever pulse is actually stopped rather than latched at appear.
        .onChange(of: onsetPulsing) { _, _ in syncPulse() }
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
    ZStack(alignment: .top) {
        // Scrollable content so the blur material has something to frost over
        ScrollView {
            VStack(spacing: 0) {
                ForEach(0..<20) { i in
                    Text("Row \(i)")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Spacing.l)
                    Divider()
                }
            }
            .padding(.top, 50)
        }
        MedicationBarView()
    }
    .environment(MedicationBarViewModel())
}
