import SwiftUI

/// 030 App Intents — "My Medication" default (FR-001/002) + confirmation naming (FR-023).
/// Native grouped-`List` chrome (DESIGN.md §114 — Settings is SF/List-exempt). Binds to
/// `SettingsViewModel`, which mirrors `AppSettings` and persists on each change.
/// Inline chip accordion per the approved T011 mockup (030-settings-medication.html) —
/// no push-navigation anywhere; chips act directly on the view model, so there is a
/// single persist per user action (no `onChange` cascade).
struct MyMedicationSection: View {
    @Bindable var viewModel: SettingsViewModel
    @State private var isPickerExpanded = false

    private var selectedEntry: MedicationCatalogEntry? {
        viewModel.defaultMedicationName.flatMap(MedicationCatalog.entry(matching:))
    }

    private var medicationValue: String {
        guard let name = viewModel.defaultMedicationName else { return "Set" }
        guard let dose = viewModel.defaultMedicationDose else { return name }
        return "\(name) · \(dose)"
    }

    /// The named-confirmation preview uses the current selection, or a neutral example
    /// when nothing is set yet, so the banner always shows what "on" would look like.
    private var confirmationSample: String {
        let name = viewModel.defaultMedicationName ?? "Elvanse"
        let dose = viewModel.defaultMedicationDose ?? "30 mg"
        return "\(name) \(dose)"
    }

    var body: some View {
        Section {
            Button {
                withAnimation(.snappy) { isPickerExpanded.toggle() }
            } label: {
                HStack {
                    Label("Medication", systemImage: "pills")
                    Spacer()
                    Text(medicationValue)
                        .foregroundStyle(viewModel.defaultMedicationName == nil ? Color.accentColor : .secondary)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isPickerExpanded ? 90 : 0))
                }
            }
            .foregroundStyle(.primary)
            .accessibilityHint(isPickerExpanded
                               ? "Collapses the medication picker."
                               : "Expands the picker for the medication logged by the hands-free Log My Meds action.")

            if isPickerExpanded {
                medicationChips

                if let entry = selectedEntry {
                    doseChips(entry)
                }
            }

            if viewModel.defaultMedicationName != nil {
                Button("Clear Medication", role: .destructive) {
                    viewModel.defaultMedicationName = nil
                    viewModel.medicationDidChange()
                    withAnimation(.snappy) { isPickerExpanded = false }
                }
                .accessibilityHint("Removes the default. Hands-free logging asks you to set a medication again; past logs keep what they recorded.")
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

            confirmationBanner
        } header: {
            Text("Confirmations")
        } footer: {
            Text(viewModel.nameMedicationInConfirmations
                 ? "On — confirmations name the dose, spoken and on the lock screen."
                 : "Off — discreet everywhere. The medication name stays inside the app.")
        }
    }

    private var medicationChips: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 8)], spacing: 8) {
            ForEach(MedicationCatalog.all) { entry in
                SettingsChip(title: entry.name, isSelected: viewModel.defaultMedicationName == entry.name) {
                    viewModel.defaultMedicationName = entry.name
                    viewModel.medicationDidChange()
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func doseChips(_ entry: MedicationCatalogEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Dose")
                .font(.footnote)
                .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: 8)], spacing: 8) {
                ForEach(entry.doseOptions, id: \.self) { dose in
                    SettingsChip(title: dose, isSelected: viewModel.defaultMedicationDose == dose) {
                        viewModel.defaultMedicationDose = dose
                        viewModel.syncMyMedication()
                    }
                }
            }
            .accessibilityHint("Sets the dose logged by the hands-free action.")
        }
        .padding(.vertical, 4)
    }

    /// Live preview of the confirmation line (mockup's banner row): what Siri says,
    /// what the banner shows — under the current naming setting.
    private var confirmationBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "pills.fill")
                .font(.caption)
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(.purple, in: .rect(cornerRadius: 7))
            Text(viewModel.nameMedicationInConfirmations ? "\(confirmationSample) logged" : "Dose logged")
                .font(.subheadline.weight(.semibold))
            Text("· 17:42")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Preview: \(viewModel.nameMedicationInConfirmations ? "\(confirmationSample) logged" : "Dose logged") at 17:42")
    }
}

/// Capsule chip in the medication-purple selection language (mockup `.chip`).
/// Private to Settings — the Paper & Pollen `Chip` component is accent-green and
/// belongs to content surfaces, not the native-List Settings chrome.
private struct SettingsChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(isSelected ? AnyShapeStyle(.purple) : AnyShapeStyle(.quaternary), in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
