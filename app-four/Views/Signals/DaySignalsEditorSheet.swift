import SwiftUI
import SwiftData

/// Manual view/edit of one day's four signal groups. Sleep uses the named 5-step
/// `SleepLevel` scale with the bed icon (no colour bead ramp — deferred per DESIGN.md);
/// activity/heart/cycle are plain fields. Each section shows its provenance.
struct DaySignalsEditorSheet: View {
    @State private var viewModel: DaySignalsEditorViewModel
    @Environment(\.dismiss) private var dismiss

    init(viewModel: DaySignalsEditorViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            Form {
                sleepSection
                activitySection
                heartSection
                cycleSection
            }
            .navigationTitle("Day Signals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        try? viewModel.save()
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: Sections

    private var sleepSection: some View {
        Section {
            HStack {
                BedIcon().frame(width: 22, height: 22)
                Text("Hours")
                Spacer()
                TextField("—", text: optionalNumber($viewModel.sleepHours))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
            }
            Picker("Quality", selection: $viewModel.sleepLevel) {
                Text("—").tag(SleepLevel?.none)
                ForEach(SleepLevel.allCases, id: \.self) { level in
                    Text(level.rawValue.capitalized).tag(SleepLevel?.some(level))
                }
            }
        } header: {
            sectionHeader("Sleep", source: viewModel.sleepSource)
        }
    }

    private var activitySection: some View {
        Section {
            numberRow("Steps", value: optionalNumber($viewModel.steps))
            numberRow("Active energy (kcal)", value: optionalNumber($viewModel.activeEnergyKcal))
            numberRow("Exercise (min)", value: optionalNumber($viewModel.exerciseMinutes))
        } header: {
            sectionHeader("Activity", source: viewModel.activitySource)
        }
    }

    private var heartSection: some View {
        Section {
            numberRow("Resting HR (bpm)", value: optionalNumber($viewModel.restingHeartRate))
            numberRow("HRV SDNN (ms)", value: optionalNumber($viewModel.hrvSDNN))
        } header: {
            sectionHeader("Heart", source: viewModel.heartSource)
        }
    }

    private var cycleSection: some View {
        Section {
            Picker("Flow", selection: $viewModel.menstrualFlow) {
                Text("—").tag(MenstrualFlow?.none)
                ForEach(MenstrualFlow.allCases, id: \.self) { flow in
                    Text(flow.rawValue.capitalized).tag(MenstrualFlow?.some(flow))
                }
            }
        } header: {
            sectionHeader("Cycle", source: viewModel.cycleSource)
        }
    }

    // MARK: Pieces

    private func sectionHeader(_ title: String, source: SignalSource) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(sourceLabel(source))
                .font(.caption2)
                .foregroundStyle(source == .none ? .tertiary : .secondary)
                .textCase(nil)
        }
    }

    private func sourceLabel(_ source: SignalSource) -> String {
        switch source {
        case .healthKit: "From Apple Health"
        case .manual: "Added by you"
        case .none: "Not set"
        }
    }

    private func numberRow(_ title: String, value: Binding<String>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("—", text: value)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 90)
        }
    }

    /// Bridges an optional numeric binding to a text binding so an empty field maps to
    /// nil (clearing a value), not to zero — preserving the clear-to-`.none` behavior.
    private func optionalNumber<T: LosslessStringConvertible>(_ source: Binding<T?>) -> Binding<String> {
        Binding(
            get: { source.wrappedValue.map { String($0) } ?? "" },
            set: { source.wrappedValue = $0.isEmpty ? nil : T($0) }
        )
    }
}

#Preview {
    let store = SignalsStore(context: AppModelContainer.previewContainer.mainContext)
    let day = SignalDayKey.dayStart(for: .now)
    return DaySignalsEditorSheet(viewModel: DaySignalsEditorViewModel(dayStart: day, store: store))
}
