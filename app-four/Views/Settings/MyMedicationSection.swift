import SwiftUI

/// 030 App Intents — "My Medication" default (FR-001/002) + confirmation naming (FR-023).
/// Native grouped-`List` chrome (DESIGN.md §114 — Settings is SF/List-exempt). Binds to
/// `SettingsViewModel`, which mirrors `AppSettings` and persists on each change.
struct MyMedicationSection: View {
    @Bindable var viewModel: SettingsViewModel

    /// The named-confirmation preview uses the current selection, or a neutral example
    /// when nothing is set yet, so the footer always shows what "on" would look like.
    private var confirmationSample: String {
        let name = viewModel.defaultMedicationName ?? "Elvanse"
        let dose = viewModel.defaultMedicationDose ?? "30 mg"
        return "\(name) \(dose)"
    }

    var body: some View {
        Section {
            Picker(selection: $viewModel.defaultMedicationName) {
                Text("None").tag(nil as String?)
                ForEach(MedicationCatalog.all) { entry in
                    Text(entry.name).tag(entry.name as String?)
                }
            } label: {
                Label("Medication", systemImage: "pills")
            }
            .onChange(of: viewModel.defaultMedicationName) { viewModel.medicationDidChange() }
            .accessibilityHint("The medication logged by the hands-free Log My Meds action.")

            if let name = viewModel.defaultMedicationName,
               let entry = MedicationCatalog.entry(matching: name) {
                Picker(selection: $viewModel.defaultMedicationDose) {
                    ForEach(entry.doseOptions, id: \.self) { dose in
                        Text(dose).tag(dose as String?)
                    }
                } label: {
                    Label("Dose", systemImage: "pills.fill")
                }
                .onChange(of: viewModel.defaultMedicationDose) { viewModel.syncMyMedication() }
            }
        } header: {
            Text("My Medication")
        } footer: {
            Text("Logged by the Log My Meds action — sticker, Siri, or Shortcuts. Only this medication and dose are recorded; changing it never alters past logs.")
        }

        Section {
            Toggle(isOn: $viewModel.nameMedicationInConfirmations) {
                Label("Name medication in confirmations", systemImage: "quote.bubble")
            }
            .onChange(of: viewModel.nameMedicationInConfirmations) { viewModel.syncNameInConfirmations() }
            .accessibilityHint("When on, confirmations name the medication and dose everywhere, including the lock screen.")
        } header: {
            Text("Confirmations")
        } footer: {
            Text(viewModel.nameMedicationInConfirmations
                 ? "On — confirmations name the dose, e.g. “\(confirmationSample) logged · 17:42”."
                 : "Off — discreet everywhere: “Dose logged · 17:42”. The medication name stays inside the app.")
        }
    }
}
