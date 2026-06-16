import SwiftUI

struct MedicationLogSheet: View {
    /// Reports the logged dose: name, dose (nil if blank), taken time, effect duration (hours).
    let onLog: (String, String?, Date, Double) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = MedicationPickerViewModel()

    @State private var name = ""
    @State private var dose = ""
    @State private var takenAt = Date()
    @State private var durationHours: Double = 10

    private var catalogEntry: MedicationCatalogEntry? { viewModel.catalogEntry(for: name) }
    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Medication") {
                    medicationChips
                    TextField("Name", text: $name)
                        .autocorrectionDisabled()
                }

                Section("Dose") {
                    if let catalogEntry {
                        Picker("Dose", selection: $dose) {
                            Text("—").tag("")
                            ForEach(catalogEntry.doseOptions, id: \.self) { Text($0).tag($0) }
                        }
                        LabeledContent("Onset", value: "≈ \(catalogEntry.onsetMinutes) min")
                    } else {
                        TextField("Dose (optional)", text: $dose)
                            .autocorrectionDisabled()
                    }
                }

                Section("Effect duration") {
                    HStack {
                        TextField("Hours", value: $durationHours, format: .number)
                            .keyboardType(.decimalPad)
                        Text("hours").foregroundStyle(.secondary)
                    }
                }

                Section("Taken at") {
                    DatePicker("Time", selection: $takenAt, in: ...Date(), displayedComponents: .hourAndMinute)
                }
            }
            .navigationTitle("Log Dose")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onLog(trimmedName, dose.isEmpty ? nil : dose, takenAt, durationHours)
                        dismiss()
                    }
                    .disabled(trimmedName.isEmpty)
                }
            }
            .onChange(of: name) { _, newName in applyCatalogDefaults(for: newName) }
        }
    }

    private var medicationChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.s) {
                ForEach(viewModel.pickableNames, id: \.self) { medName in
                    let selected = MedicationPickerViewModel.baseName(medName)
                        == MedicationPickerViewModel.baseName(name)
                    Button { name = medName } label: {
                        Text(medName)
                            .font(.callout.weight(selected ? .semibold : .regular))
                            .padding(.horizontal, Spacing.m)
                            .padding(.vertical, Spacing.s)
                            .background(
                                selected ? Palette.medication.opacity(0.25) : Color.secondary.opacity(0.15),
                                in: .capsule
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
        .listRowInsets(EdgeInsets())
    }

    /// When the name resolves to a catalog medication, prefill its effect duration and snap
    /// the dose to a valid option. A free-text medication keeps whatever the user entered.
    private func applyCatalogDefaults(for newName: String) {
        guard let entry = viewModel.catalogEntry(for: newName) else { return }
        durationHours = entry.durationHours
        if !entry.doseOptions.contains(dose) {
            dose = entry.doseOptions.first ?? ""
        }
    }
}

#Preview {
    MedicationLogSheet(onLog: { _, _, _, _ in })
}
