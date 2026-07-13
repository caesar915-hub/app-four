import SwiftUI

/// 030 App Intents — "My Medication" default (FR-001/002) + confirmation naming (FR-023).
/// Native grouped-`List` chrome (DESIGN.md §114 — Settings is SF/List-exempt). Binds to
/// `SettingsViewModel`, which mirrors `AppSettings` and persists on each change.
/// Inline chip accordion per the approved T011 mockup (030-settings-medication.html) —
/// no push-navigation; chips act directly on the view model (single persist per tap),
/// and picking a medication never auto-commits a dose: the dose takes its own tap.
struct MyMedicationSection: View {
    @Bindable var viewModel: SettingsViewModel
    /// Owned by `SettingsView`, which also opens the picker when the intent's
    /// not-configured continuation focuses this section (FR-007/D13).
    @Binding var isPickerExpanded: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var selectedEntry: MedicationCatalogEntry? {
        viewModel.defaultMedicationName.flatMap(MedicationCatalog.entry(matching:))
    }

    var body: some View {
        Section {
            Button {
                withAnimation(reduceMotion ? nil : Motion.snappy) { isPickerExpanded.toggle() }
            } label: {
                HStack {
                    Label("Medication", systemImage: "pills")
                    Spacer()
                    medicationValue
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
                    withAnimation(reduceMotion ? nil : Motion.snappy) {
                        viewModel.defaultMedicationName = nil
                        viewModel.medicationDidChange()
                        isPickerExpanded = false
                    }
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
            Text("Off — discreet everywhere; the medication name stays inside the app. On — confirmations name the medication and dose (banner, spoken, and on the lock screen).")
        }
    }

    /// Mockup's three-state row value: bronze "Set" call-to-action, plain name while
    /// the dose still needs its tap, med-purple once both are locked in.
    private var medicationValue: some View {
        Group {
            if let name = viewModel.defaultMedicationName {
                if let dose = viewModel.defaultMedicationDose {
                    Text("\(name) · \(dose)")
                        .fontWeight(.semibold)
                        .foregroundStyle(.purple)
                } else {
                    Text(name)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Set")
                    .foregroundStyle(Color.accentColor)
            }
        }
    }

    private var medicationChips: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Medication")
                .font(.footnote)
                .foregroundStyle(.secondary)
            FlowLayout(spacing: 8) {
                ForEach(MedicationCatalog.all) { entry in
                    SettingsChip(
                        title: entry.name,
                        isSelected: viewModel.defaultMedicationName == entry.name,
                        hint: "Sets the medication logged by the hands-free action. The dose is picked separately."
                    ) {
                        withAnimation(reduceMotion ? nil : Motion.snappy) {
                            viewModel.defaultMedicationName = entry.name
                            viewModel.medicationDidChange()
                        }
                    }
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
            FlowLayout(spacing: 8) {
                ForEach(entry.doseOptions, id: \.self) { dose in
                    SettingsChip(
                        title: dose,
                        isSelected: viewModel.defaultMedicationDose == dose,
                        hint: "Sets the dose logged by the hands-free action."
                    ) {
                        withAnimation(reduceMotion ? nil : Motion.snappy) {
                            viewModel.defaultMedicationDose = dose
                            viewModel.syncMyMedication()
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    /// Live preview of the confirmation line (mockup's banner): a nested card set
    /// apart from the actionable rows, so it reads as a preview, not a control.
    private var confirmationBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "pills.fill")
                .font(.caption)
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(.purple, in: .rect(cornerRadius: 7))
            Text(previewLine)
                .font(.subheadline.weight(.semibold))
            Text("· 17:42")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            Spacer()
        }
        .padding(10)
        .background(Color(.tertiarySystemFill), in: .rect(cornerRadius: 12))
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Preview: \(previewLine) at 17:42")
    }

    /// The sample uses the current selection, or a neutral example when nothing is
    /// set yet, so the banner always shows what "on" would look like.
    private var previewLine: String {
        guard viewModel.nameMedicationInConfirmations else { return "Dose logged" }
        let name = viewModel.defaultMedicationName ?? "Elvanse"
        let dose = viewModel.defaultMedicationDose ?? "30 mg"
        return "\(name) \(dose) logged"
    }
}

/// Content-width capsule chip in the medication-purple selection language (mockup
/// `.chip`). Private to Settings — the Paper & Pollen `Chip` component is accent-green
/// content-surface language; Settings is native-List chrome with med-purple selection.
private struct SettingsChip: View {
    let title: String
    let isSelected: Bool
    let hint: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? AnyShapeStyle(.purple) : AnyShapeStyle(.quaternary), in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityHint(hint)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
