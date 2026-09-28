import SwiftUI

/// Log a dose by hand (the hub's "Log medications", the medication bar's "Log new dose"). Undrawn
/// in the pen; built from its atoms (UI-33a): back pill + title + a filled Save pill, catalog
/// medications as wrapping Bill-shape chips, cards for the dose, duration and time fields.
struct MedicationLogSheet: View {
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
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.cardGap) {
                    medicationSection
                    doseSection
                    durationSection
                    takenAtSection
                }
                .padding(.horizontal, Spacing.gutter)
                .padding(.bottom, Spacing.xxl)
            }
        }
        .background(Surface.screen.ignoresSafeArea())
        .presentationDragIndicator(.visible)
        .onChange(of: name) { _, newName in applyCatalogDefaults(for: newName) }
    }

    // MARK: - Header

    private var header: some View {
        NavHeader(title: "Log dose", onBack: { dismiss() }) {
            Button("Save") {
                onLog(trimmedName, dose.isEmpty ? nil : dose, takenAt, durationHours)
                dismiss()
            }
            .buttonStyle(.filled(.small))
            .disabled(trimmedName.isEmpty)
        }
        .padding(.horizontal, Spacing.gutter)
        .padding(.vertical, Spacing.m)
    }

    // MARK: - Sections

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(Typography.sectionTitle)
            .foregroundStyle(Ink.primary)
            .accessibilityAddTraits(.isHeader)
    }

    private var medicationSection: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            sectionLabel("Medication")
            VStack(alignment: .leading, spacing: Spacing.m) {
                medicationChips
                HairlineDivider()
                TextField("Name", text: $name)
                    .autocorrectionDisabled()
                    .font(Typography.narrative)
                    .foregroundStyle(Ink.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card(.large)
        }
    }

    private var doseSection: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            sectionLabel("Dose")
            VStack(alignment: .leading, spacing: Spacing.m) {
                if let entry = catalogEntry {
                    doseChips(entry)
                    HairlineDivider()
                    HStack {
                        Text("Onset").font(Typography.rowLabel).foregroundStyle(Ink.primary)
                        Spacer()
                        Text("≈ \(entry.onsetMinutes) min").font(Typography.captionMedium).foregroundStyle(Ink.secondary)
                    }
                } else {
                    TextField("Dose (optional)", text: $dose)
                        .autocorrectionDisabled()
                        .font(Typography.narrative)
                        .foregroundStyle(Ink.primary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card(.large)

            if catalogEntry != nil {
                Text("Typical values from product labeling — your response may differ.")
                    .font(Typography.captionQuiet)
                    .foregroundStyle(Ink.tertiary)
            }
        }
    }

    private var durationSection: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            sectionLabel("Effect duration")
            HStack {
                Text("Hours").font(Typography.rowLabel).foregroundStyle(Ink.primary)
                Spacer()
                TextField("", value: $durationHours, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(Typography.narrative)
                    .foregroundStyle(Ink.primary)
                    .frame(width: 60)
            }
            .card(.small)
        }
    }

    private var takenAtSection: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            sectionLabel("Taken at")
            DatePicker("Time", selection: $takenAt, in: ...Date(), displayedComponents: .hourAndMinute)
                .labelsHidden()
                .tint(Accent.primaryFill)
                .frame(maxWidth: .infinity, alignment: .leading)
                .card(.small)
        }
    }

    // MARK: - Chips

    private var medicationChips: some View {
        ChipRow(interactive: true) {
            ForEach(viewModel.pickableNames, id: \.self) { medName in
                let selected = MedicationPickerViewModel.baseName(medName)
                    == MedicationPickerViewModel.baseName(name)
                ChipButton(medName, selected: selected) { name = medName }
            }
        }
    }

    private func doseChips(_ entry: MedicationCatalogEntry) -> some View {
        ChipRow(interactive: true) {
            ForEach(entry.doseOptions, id: \.self) { option in
                ChipButton(option, selected: dose == option) { dose = option }
            }
        }
    }

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
