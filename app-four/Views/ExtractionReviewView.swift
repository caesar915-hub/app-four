import SwiftUI

struct ExtractionReviewView: View {
    @Bindable var viewModel: ExtractionReviewViewModel
    @Environment(\.dismiss) private var dismiss

    private struct ChipGroup: Identifiable {
        var id: String { label }
        let label: String
        let items: [String]
    }

    private let feelingGroups: [ChipGroup] = [
        ChipGroup(label: "Positive",  items: ["grateful", "hopeful", "excited", "content", "inspired",
                                              "proud", "playful", "loved", "peaceful", "motivated"]),
        ChipGroup(label: "Neutral",   items: ["curious", "reflective", "nostalgic", "restless",
                                              "indifferent", "bored", "uncertain", "tense"]),
        ChipGroup(label: "Difficult", items: ["anxious", "sad", "frustrated", "overwhelmed", "lonely",
                                              "angry", "scared", "guilty", "ashamed", "exhausted"])
    ]

    private let commonSideEffects = [
        "dry mouth", "headache", "nausea", "appetite gone", "insomnia",
        "jittery", "heart racing", "stomach ache", "dizzy", "irritable",
        "rebound", "crash", "sweating", "grinding teeth", "flat affect"
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    dateSection
                    moodSection
                    energySection
                    focusSection
                    sleepSection
                    medicationSection
                    feelingsSection
                    sideEffectsSection
                }
                .padding(Spacing.xl)
            }
            .navigationTitle("Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { viewModel.cancel(); dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { viewModel.confirm(); dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Date & Time

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            sectionLabel("Date & Time")
            DatePicker("", selection: $viewModel.date, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.compact)
                .labelsHidden()
        }
        .sectionCard()
    }

    // MARK: - Mood 0–5

    private var moodSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s) { // was 10
            sectionLabel("Mood")
            scaleRow(
                cases: MoodLevel.allCases,
                selected: MoodLevel(rawValue: viewModel.mood),
                accentColor: moodLevelColor(MoodLevel(rawValue: viewModel.mood)),
                label: { $0.rawValue.capitalized },
                onSelect: { viewModel.setMood($0 == MoodLevel(rawValue: viewModel.mood) ? "" : $0.rawValue) }
            )
            if let level = MoodLevel(rawValue: viewModel.mood) {
                subtitleText(level.subtitle)
            }
        }
        .sectionCard()
    }

    // MARK: - Medications

    // Quick-pick chips come from the shared MedicationCatalog (single source of truth, FR-012)
    // — so the Log-Dose sheet and this Edit sheet never drift on which meds exist. NLP can
    // still extract others from speech; these are just the manual quick-pick chips.
    private let medicationGroups: [ChipGroup] = [
        ChipGroup(label: "Medications", items: MedicationCatalog.all.map(\.name))
    ]

    private var medicationSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s) { // was 10
            sectionLabel("Medications")

            if !viewModel.medications.isEmpty {
                VStack(spacing: Spacing.s) { // was 6
                    // Iterate by element (not indices): a med can be removed mid-edit,
                    // and ForEach(indices) re-renders a stale row → Index out of range.
                    ForEach(viewModel.medications, id: \.self) { med in
                        HStack(spacing: Spacing.s) { // was 10
                            Image(systemName: "pills.fill")
                                .foregroundStyle(.purple)
                                .font(.caption)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: Spacing.xs) { // was 2
                                HStack(spacing: Spacing.xs) {
                                    Text(med.name)
                                        .font(Typography.body)
                                    TextField("Dose", text: Binding(
                                        get: { med.dose ?? "" },
                                        set: { viewModel.setMedDose(med, dose: $0.isEmpty ? nil : $0) }
                                    ))
                                    .font(Typography.body)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 60)
                                }
                                if let label = med.timeLabel ?? med.time {
                                    Text(label).font(Typography.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Button {
                                viewModel.toggleMedTaken(med)
                            } label: {
                                Text(med.taken ? "Taken" : "Missed")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, Spacing.s) // was 10
                                    .padding(.vertical, Spacing.xs)
                                    .background(med.taken ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                                    .foregroundStyle(med.taken ? .green : .orange)
                                    .clipShape(.rect(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(.bottom, Spacing.s)
            }

            ForEach(medicationGroups) { group in
                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text(group.label)
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                    FlowLayout(spacing: Spacing.s) {
                        ForEach(group.items, id: \.self) { medName in
                            let on = viewModel.medications.contains(where: { $0.name == medName })
                            Chip.filter(medName, isSelected: on) {
                                if on {
                                    viewModel.removeMedication(medName)
                                } else {
                                    viewModel.addMedication(medName)
                                }
                            }
                            .accessibilityLabel("\(medName)\(on ? ", selected" : "")")
                        }
                    }
                }
            }
        }
        .sectionCard()
    }

    // MARK: - Energy 0–5

    private var energySection: some View {
        VStack(alignment: .leading, spacing: Spacing.s) { // was 10
            sectionLabel("Energy")
            scaleRow(
                cases: EnergyLevel.allCases,
                selected: viewModel.energy,
                accentColor: .orange,
                label: { $0.rawValue.capitalized },
                onSelect: { viewModel.setEnergy(viewModel.energy == $0 ? nil : $0) }
            )
            if let level = viewModel.energy { subtitleText(level.subtitle) }
        }
        .sectionCard()
    }

    // MARK: - Focus 0–5

    private var focusSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s) { // was 10
            sectionLabel("Focus")
            scaleRow(
                cases: FocusLevel.allCases,
                selected: viewModel.focus,
                accentColor: .indigo,
                label: { $0.displayLabel },
                onSelect: { viewModel.setFocus(viewModel.focus == $0 ? nil : $0) }
            )
            if let level = viewModel.focus { subtitleText(level.subtitle) }
        }
        .sectionCard()
    }

    // MARK: - Feelings

    private var feelingsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.m) { // was 14 (equidistant 12/16; chose tighter)
            sectionLabel("Feelings")
            ForEach(feelingGroups) { group in
                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text(group.label)
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                    FlowLayout(spacing: Spacing.s) {
                        ForEach(group.items, id: \.self) { feeling in
                            let on = viewModel.feelings.contains(feeling)
                            Chip.filter(feeling.capitalized, isSelected: on) {
                                viewModel.toggleFeeling(feeling)
                            }
                            .accessibilityLabel("\(feeling)\(on ? ", selected" : "")")
                        }
                    }
                }
            }
        }
        .sectionCard()
    }

    // MARK: - Sleep 0–5

    private let sleepDurations = [2.0, 4.0, 6.0, 8.0, 10.0]

    private var sleepSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s) { // was 10
            sectionLabel("Sleep")
            scaleRow(
                cases: SleepLevel.allCases,
                selected: viewModel.sleepLevel,
                accentColor: .indigo,
                label: { $0.rawValue.capitalized },
                onSelect: { viewModel.setSleepLevel(viewModel.sleepLevel == $0 ? nil : $0) }
            )
            if let level = viewModel.sleepLevel { subtitleText(level.subtitle) }

            HStack(spacing: Spacing.s) {
                ForEach(sleepDurations, id: \.self) { hours in
                    let isSelected = viewModel.sleepHours == hours
                    Button {
                        viewModel.setSleepHours(isSelected ? nil : hours)
                    } label: {
                        Text("\(Int(hours))h")
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, Spacing.m)
                            .padding(.vertical, Spacing.s) // was 6
                            .background(isSelected ? Color.indigo.opacity(0.2) : Color.secondary.opacity(0.1))
                            .foregroundStyle(isSelected ? .indigo : .secondary)
                            .clipShape(.rect(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .sectionCard()
    }

    // MARK: - Side Effects

    private var sideEffectsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s) { // was 10
            sectionLabel("Side Effects")
            FlowLayout(spacing: Spacing.s) {
                ForEach(commonSideEffects, id: \.self) { effect in
                    let on = viewModel.sideEffects.contains(effect)
                    Chip.filter(effect.capitalized, isSelected: on) {
                        viewModel.toggleSideEffect(effect)
                    }
                    .accessibilityLabel("\(effect)\(on ? ", selected" : "")")
                }
            }
        }
        .sectionCard()
    }

    // MARK: - Reusable scale row

    private func scaleRow<T: CaseIterable & Equatable>(
        cases: T.AllCases,
        selected: T?,
        accentColor: Color,
        label: @escaping (T) -> String,
        onSelect: @escaping (T) -> Void
    ) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(cases.enumerated()), id: \.offset) { _, level in
                let isSelected = selected == level
                Button { onSelect(level) } label: {
                    Text(label(level))
                        .font(Typography.caption.weight(isSelected ? .semibold : .regular))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.m)
                        .background(isSelected ? accentColor.opacity(0.2) : Color.secondary.opacity(0.07))
                        .foregroundStyle(isSelected ? accentColor : .secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(label(level))
            }
        }
        .clipShape(.rect(cornerRadius: 12))
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(Typography.headline)
    }

    private func subtitleText(_ text: String) -> some View {
        Text(text)
            .font(Typography.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, Spacing.xs) // was 2
    }

    private func moodLevelColor(_ level: MoodLevel?) -> Color {
        switch level {
        case .low:  return .orange
        case .flat: return Color(.systemGray)
        case .okay: return .blue
        case .good: return .green
        case .great: return .teal
        case nil:   return .blue
        }
    }
}

// MARK: - Section card modifier

private extension View {
    func sectionCard() -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .card(padding: Spacing.l)
    }
}
