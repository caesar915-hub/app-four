import SwiftUI

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
            sheetNav
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    medicationSection
                    doseSection
                    durationSection
                    takenAtSection
                }
                .padding(Spacing.l)
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .presentationDragIndicator(.visible)
        .onChange(of: name) { _, newName in applyCatalogDefaults(for: newName) }
    }

    // MARK: - Nav

    private var sheetNav: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(Typography.subheadline)
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 30, height: 30)
                    .background(Theme.cardBackground, in: Circle())
                    .overlay(Circle().strokeBorder(Theme.separator, lineWidth: 1))
            }
            .accessibilityLabel("Cancel")

            Spacer()
            Text("Log Dose")
                .font(Typography.title)
                .foregroundStyle(Theme.textPrimary)
            Spacer()

            Button("Save") {
                onLog(trimmedName, dose.isEmpty ? nil : dose, takenAt, durationHours)
                dismiss()
            }
            .font(Typography.subheadline.weight(.semibold))
            .foregroundStyle(trimmedName.isEmpty ? Theme.textSecondary : Theme.meadowGreen)
            .disabled(trimmedName.isEmpty)
        }
        .padding(.horizontal, Spacing.l)
        .padding(.vertical, Spacing.m)
    }

    // MARK: - Sections

    private var medicationSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Medication")
                .font(Typography.label.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
            VStack(spacing: 0) {
                medicationChips
                Divider().overlay(Theme.separator)
                TextField("Name", text: $name)
                    .autocorrectionDisabled()
                    .font(Typography.body)
                    .foregroundStyle(Theme.textPrimary)
                    .padding(Spacing.m)
            }
            .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Radius.card))
            .overlay(RoundedRectangle(cornerRadius: Radius.card).strokeBorder(Theme.separator, lineWidth: 1))
        }
    }

    private var doseSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Dose")
                .font(Typography.label.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
            VStack(spacing: 0) {
                if let entry = catalogEntry {
                    Picker("Dose", selection: $dose) {
                        Text("—").tag("")
                        ForEach(entry.doseOptions, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, Spacing.m)
                    .padding(.vertical, Spacing.s)
                    Divider().overlay(Theme.separator)
                    HStack {
                        Text("Onset").font(Typography.body).foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Text("≈ \(entry.onsetMinutes) min").font(Typography.body).foregroundStyle(Theme.textSecondary)
                    }
                    .padding(.horizontal, Spacing.m)
                    .padding(.vertical, Spacing.s)
                } else {
                    TextField("Dose (optional)", text: $dose)
                        .autocorrectionDisabled()
                        .font(Typography.body)
                        .foregroundStyle(Theme.textPrimary)
                        .padding(Spacing.m)
                }
            }
            .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Radius.card))
            .overlay(RoundedRectangle(cornerRadius: Radius.card).strokeBorder(Theme.separator, lineWidth: 1))
        }
    }

    private var durationSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Effect Duration")
                .font(Typography.label.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
            HStack {
                Text("Hours").font(Typography.body).foregroundStyle(Theme.textPrimary)
                Spacer()
                TextField("", value: $durationHours, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(Typography.body)
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 60)
            }
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, Spacing.s)
            .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Radius.card))
            .overlay(RoundedRectangle(cornerRadius: Radius.card).strokeBorder(Theme.separator, lineWidth: 1))
        }
    }

    private var takenAtSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Taken At")
                .font(Typography.label.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
            DatePicker("Time", selection: $takenAt, in: ...Date(), displayedComponents: .hourAndMinute)
                .labelsHidden()
                .padding(.horizontal, Spacing.m)
                .padding(.vertical, Spacing.s)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Radius.card))
                .overlay(RoundedRectangle(cornerRadius: Radius.card).strokeBorder(Theme.separator, lineWidth: 1))
        }
    }

    // MARK: - Chip picker

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
                            .overlay(Capsule().strokeBorder(
                                selected ? Palette.medication : .clear, lineWidth: 1
                            ))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected ? [.isSelected] : [])
                }
            }
            .padding(.vertical, 2)
        }
        .padding(Spacing.m)
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
