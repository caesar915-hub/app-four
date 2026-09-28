import SwiftUI

/// Settings › My medication (030 App Intents, FR-001/002): the default the hands-free
/// "Log My Meds" action records. An inline chip picker — no push — acting directly on the view
/// model (one persist per tap); picking a medication never auto-commits a dose.
struct MyMedicationSection: View {
    @Bindable var viewModel: SettingsViewModel
    /// Owned by `SettingsView`, which also opens the picker when the intent's not-configured
    /// continuation focuses this section (FR-007/D13).
    @Binding var isPickerExpanded: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var selectedEntry: MedicationCatalogEntry? {
        viewModel.defaultMedicationName.flatMap(MedicationCatalog.entry(matching:))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Button {
                withAnimation(reduceMotion ? nil : Motion.snappy) { isPickerExpanded.toggle() }
            } label: {
                HStack(spacing: Spacing.m) {
                    Image(systemName: Icons.medication)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Accent.violet)
                        .frame(width: 21, height: 21)
                        .accessibilityHidden(true)
                    Text("Medication")
                        .font(Typography.rowLabel)
                        .foregroundStyle(Ink.primary)
                    Spacer(minLength: Spacing.s)
                    medicationValue
                    Image(systemName: Icons.chevronRight)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Ink.tertiary)
                        .rotationEffect(.degrees(isPickerExpanded ? 90 : 0))
                        .accessibilityHidden(true)
                }
                .frame(minHeight: Metrics.minTapTarget)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityHint(isPickerExpanded
                               ? "Collapses the medication picker."
                               : "Expands the picker for the medication logged by the hands-free Log My Meds action.")

            if isPickerExpanded {
                HairlineDivider()
                ChipGroupView("Medication") {
                    ForEach(MedicationCatalog.all) { entry in
                        ChipButton(entry.name, selected: viewModel.defaultMedicationName == entry.name) {
                            withAnimation(reduceMotion ? nil : Motion.snappy) {
                                viewModel.defaultMedicationName = entry.name
                                viewModel.medicationDidChange()
                            }
                        }
                        .accessibilityHint("Sets the medication logged by the hands-free action. The dose is picked separately.")
                    }
                }
                if let entry = selectedEntry {
                    ChipGroupView("Dose") {
                        ForEach(entry.doseOptions, id: \.self) { dose in
                            ChipButton(dose, selected: viewModel.defaultMedicationDose == dose) {
                                withAnimation(reduceMotion ? nil : Motion.snappy) {
                                    viewModel.defaultMedicationDose = dose
                                    viewModel.syncMyMedication()
                                }
                            }
                            .accessibilityHint("Sets the dose logged by the hands-free action.")
                        }
                    }
                }
            }

            if viewModel.defaultMedicationName != nil {
                HairlineDivider()
                Button {
                    withAnimation(reduceMotion ? nil : Motion.snappy) {
                        viewModel.defaultMedicationName = nil
                        viewModel.medicationDidChange()
                        isPickerExpanded = false
                    }
                } label: {
                    Text("Clear medication")
                        .font(Typography.rowLabel)
                        .foregroundStyle(Ink.destructive)
                        .frame(minHeight: Metrics.minTapTarget)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Removes the default. Hands-free logging asks you to set a medication again; past logs keep what they recorded.")
            }

            Text("Logged by the Log My Meds action — Siri or Shortcuts. Only this medication and dose are recorded; changing it never alters past logs.")
                .font(Typography.captionMedium)
                .foregroundStyle(Ink.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Three states: "Set" call-to-action, plain name while the dose still needs its tap,
    /// violet once both are locked in.
    @ViewBuilder private var medicationValue: some View {
        if let name = viewModel.defaultMedicationName {
            if let dose = viewModel.defaultMedicationDose {
                Text("\(name) · \(dose)")
                    .font(Typography.status)
                    .foregroundStyle(Accent.violetText)
            } else {
                Text(name)
                    .font(Typography.captionMedium)
                    .foregroundStyle(Ink.secondary)
            }
        } else {
            Text("Set")
                .font(Typography.status)
                .foregroundStyle(Accent.primaryText)
        }
    }
}

/// Settings › Confirmations (FR-023): the naming toggle and a live preview of the confirmation
/// line, built by `DoseConfirmationCopy` so it can never drift from the real banner.
struct ConfirmationsSection: View {
    @Bindable var viewModel: SettingsViewModel

    private static let sampleTime: Date = {
        Calendar.current.date(bySettingHour: 9, minute: 54, second: 0, of: .now) ?? .now
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            ToggleRow("Name medication in confirmations",
                      description: "Off — discreet everywhere; the medication name stays inside the app. On — confirmations name the medication and dose (banner, spoken, and on the lock screen).",
                      isOn: $viewModel.nameMedicationInConfirmations)
                .onChange(of: viewModel.nameMedicationInConfirmations) { viewModel.syncNameInConfirmations() }
                .accessibilityHint("When on, confirmations name the medication and dose everywhere, including the lock screen.")

            HStack(spacing: Spacing.m) {
                MedicationBadge(size: 26)
                Text(previewLine)
                    .font(Typography.rowLabel)
                    .foregroundStyle(Ink.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Spacing.m)
            .frame(minHeight: 40)
            .background(Surface.medicationTint, in: .rect(cornerRadius: Radius.field))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Preview: \(previewLine)")
        }
    }

    /// The sample uses the current selection, or a neutral example when nothing is set yet, so
    /// the preview always shows what the current setting produces.
    private var previewLine: String {
        DoseConfirmationCopy.text(
            for: .logged(name: viewModel.defaultMedicationName ?? "Elvanse",
                         dose: viewModel.defaultMedicationDose ?? "30 mg",
                         at: Self.sampleTime),
            named: viewModel.nameMedicationInConfirmations
        )
    }
}
