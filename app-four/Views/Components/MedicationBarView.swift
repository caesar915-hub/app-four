import SwiftUI

struct MedicationBarView: View {
    @Environment(MedicationBarViewModel.self) private var viewModel
    @State private var showLogSheet = false
    @State private var selectedDose: MedicationBarViewModel.DoseDisplay? = nil

    @AppStorage("medicationBarVisible") private var showBar = true
    @AppStorage("medicationBarShowName") private var showName = true
    @AppStorage("medicationBarShowTime") private var showTime = true
    @AppStorage("medicationBarShowEndTime") private var showEndTime = true

    /// Rounded shape that echoes the Liquid Glass tab bar pill.
    private var barShape: RoundedRectangle { RoundedRectangle(cornerRadius: 22, style: .continuous) }

    var body: some View {
        if showBar, !viewModel.activeDoses.isEmpty {
            VStack(spacing: 0) {
                ForEach(Array(viewModel.activeDoses.enumerated()), id: \.element.eventID) { index, dose in
                    doseRow(dose, isLast: index == viewModel.activeDoses.count - 1)
                }
            }
            .clipShape(barShape)
            .glassEffect(.regular, in: barShape)
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
                MedicationLogSheet(onLog: { name, dose, time in
                    viewModel.logManualDose(name: name, dose: dose, takenAt: time)
                })
            }
            .onAppear { viewModel.refresh() }
        }
    }

    // MARK: - Single row

    private func doseRow(_ dose: MedicationBarViewModel.DoseDisplay, isLast: Bool) -> some View {
        let progress = dose.progress

        return Button { selectedDose = dose } label: {
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Palette.medication.opacity(0.3))   // match the timeline medication purple
                    .scaleEffect(x: progress, y: 1, anchor: .leading)
                    .animation(.easeInOut(duration: 0.5), value: progress)

                HStack {
                    Text(leftLabel(dose: dose))
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer()

                    Text(rightLabel(dose: dose))
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(.horizontal, Spacing.l)
            }
            .frame(maxWidth: .infinity)
            .frame(height: viewModel.activeDoses.count == 1 ? 44 : 40)
            .overlay(alignment: .bottom) {
                if !isLast {
                    Theme.separator
                        .frame(height: 0.5)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(dose: dose))
    }

    // MARK: - Labels

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    private func leftLabel(dose: MedicationBarViewModel.DoseDisplay) -> String {
        var parts: [String] = []
        if dose.totalDosesToday > 1 {
            parts.append(ordinal(dose.doseNumber) + " dose")
        }
        if showName {
            parts.append(dose.effectiveDose.map { "\(dose.name) \($0)" } ?? dose.name)
        }
        if showTime {
            parts.append(Self.timeFormatter.string(from: dose.takenAt))
        }
        return parts.joined(separator: " · ")
    }

    private func rightLabel(dose: MedicationBarViewModel.DoseDisplay) -> String {
        guard showEndTime else { return "" }
        return "ends \(Self.timeFormatter.string(from: dose.endsAt))"
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
