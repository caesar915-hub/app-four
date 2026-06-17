import SwiftUI

struct ExtractionReviewView: View {
    @Bindable var viewModel: ExtractionReviewViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var customHoursText: String = ""

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
                    saveCorrectionsButton
                }
                .padding(Spacing.l)
            }
            .background(Theme.background.ignoresSafeArea())
            .scrollContentBackground(.hidden)
            .navigationTitle("Edit check-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .tint(Theme.accent)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { viewModel.cancel(); dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - 01 · When

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            numberedLabel("01", "When")
            DatePicker("", selection: $viewModel.date, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.compact)
                .labelsHidden()
        }
        .sectionCard()
    }

    // MARK: - 02 · Mood

    private var moodSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            numberedLabel("02", "Mood")
            scaleRow(
                cases: MoodLevel.allCases,
                kind: .mood,
                selected: MoodLevel(rawValue: viewModel.mood),
                accentColor: MoodLevel(rawValue: viewModel.mood)?.color ?? Theme.accent,
                label: { $0.rawValue.capitalized },
                onSelect: { viewModel.setMood($0 == MoodLevel(rawValue: viewModel.mood) ? "" : $0.rawValue) }
            )
            if let level = MoodLevel(rawValue: viewModel.mood) {
                currentLine(level.displayLabel, level.subtitle)
            }
        }
        .sectionCard()
    }

    // MARK: - 03 · Energy

    private var energySection: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            numberedLabel("03", "Energy")
            scaleRow(
                cases: EnergyLevel.allCases,
                kind: .energy,
                selected: viewModel.energy,
                accentColor: viewModel.energy?.color ?? Theme.accent,
                label: { $0.rawValue.capitalized },
                onSelect: { viewModel.setEnergy(viewModel.energy == $0 ? nil : $0) }
            )
            if let level = viewModel.energy { currentLine(level.displayLabel, level.subtitle) }
        }
        .sectionCard()
    }

    // MARK: - 04 · Focus

    private var focusSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            numberedLabel("04", "Focus")
            scaleRow(
                cases: FocusLevel.allCases,
                kind: .focus,
                selected: viewModel.focus,
                accentColor: viewModel.focus?.color ?? Theme.accent,
                label: { $0.displayLabel },
                onSelect: { viewModel.setFocus(viewModel.focus == $0 ? nil : $0) }
            )
            if let level = viewModel.focus { currentLine(level.displayLabel, level.subtitle) }
        }
        .sectionCard()
    }

    // MARK: - 05 · Sleep

    private let sleepDurations = [2.0, 4.0, 6.0, 8.0, 10.0]

    private var sleepSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            numberedLabel("05", "Sleep")
            scaleRow(
                cases: SleepLevel.allCases,
                selected: viewModel.sleepLevel,
                accentColor: Palette.sleepIndigo,
                label: { $0.rawValue.capitalized },
                onSelect: { viewModel.setSleepLevel(viewModel.sleepLevel == $0 ? nil : $0) }
            )
            // Sleep is the one signal that drops synonyms (DESIGN.md) — show the named level only.
            if let level = viewModel.sleepLevel {
                Text(level.rawValue.capitalized)
                    .font(Typography.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, Spacing.xs)
            }

            HStack(spacing: Spacing.s) {
                ForEach(sleepDurations, id: \.self) { hours in
                    let isSelected = viewModel.sleepHours == hours
                    Button {
                        viewModel.setSleepHours(isSelected ? nil : hours)
                        customHoursText = ""
                    } label: {
                        Text("\(Int(hours))h")
                            .font(Typography.caption)
                            .padding(.horizontal, Spacing.m)
                            .padding(.vertical, Spacing.s)
                            .background(isSelected ? Palette.sleepIndigo.opacity(0.2) : Theme.surface2)
                            .foregroundStyle(isSelected ? Palette.sleepIndigo : Theme.textSecondary)
                            .clipShape(.rect(cornerRadius: Radius.control))
                    }
                    .buttonStyle(.plain)
                }

                TextField("h", text: $customHoursText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .font(Typography.caption)
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 52)
                    .padding(.vertical, Spacing.s)
                    .background(Theme.surface2, in: RoundedRectangle(cornerRadius: Radius.control))
                    .onChange(of: customHoursText) { _, text in
                        if let h = Double(text) { viewModel.setSleepHours(h) }
                        else if text.isEmpty, !sleepDurations.contains(viewModel.sleepHours ?? -1) { viewModel.setSleepHours(nil) }
                    }
                    .accessibilityLabel("Custom sleep hours")
            }
        }
        .sectionCard()
        .onAppear {
            if let h = viewModel.sleepHours, !sleepDurations.contains(h) {
                customHoursText = h == h.rounded() ? String(Int(h)) : String(h)
            }
        }
    }

    // MARK: - 06 · Medications

    // Quick-pick chips come from the shared MedicationCatalog (single source of truth, FR-012)
    // — so the Log-Dose sheet and this Edit sheet never drift on which meds exist. NLP can
    // still extract others from speech; these are just the manual quick-pick chips.
    private let medicationGroups: [ChipGroup] = [
        ChipGroup(label: "Medications", items: MedicationCatalog.all.map(\.name))
    ]

    private var medicationSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            numberedLabel("06", "Medications")

            if !viewModel.medications.isEmpty {
                VStack(spacing: Spacing.s) {
                    // Iterate by element (not indices): a med can be removed mid-edit,
                    // and ForEach(indices) re-renders a stale row → Index out of range.
                    ForEach(viewModel.medications, id: \.self) { med in
                        HStack(spacing: Spacing.s) {
                            SignalGlyph(.medication, size: 18, decorative: true)
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                HStack(spacing: Spacing.xs) {
                                    Text(med.name)
                                        .font(Typography.body)
                                        .foregroundStyle(Theme.textPrimary)
                                    TextField("Dose", text: Binding(
                                        get: { med.dose ?? "" },
                                        set: { viewModel.setMedDose(med, dose: $0.isEmpty ? nil : $0) }
                                    ))
                                    .font(Typography.body)
                                    .foregroundStyle(Theme.textSecondary)
                                    .frame(width: 60)
                                }
                                if let label = med.timeLabel ?? med.time {
                                    Text(label).font(Typography.caption).foregroundStyle(Theme.textSecondary)
                                }
                            }
                            Spacer()
                            Button {
                                viewModel.toggleMedTaken(med)
                            } label: {
                                Text(med.taken ? "Taken" : "Missed")
                                    .font(Typography.label)
                                    .padding(.horizontal, Spacing.s)
                                    .padding(.vertical, Spacing.xs)
                                    .background(med.taken ? Theme.meadowGreen.opacity(0.15) : Palette.warning.opacity(0.15))
                                    .foregroundStyle(med.taken ? Theme.meadowGreen : Palette.warning)
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
        .sectionCard()
    }

    // MARK: - 07 · Feelings

    private var feelingsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            numberedLabel("07", "Feelings")
            ForEach(feelingGroups) { group in
                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text(group.label)
                        .font(Typography.caption)
                        .foregroundStyle(Theme.textSecondary)
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

    // MARK: - 08 · Side Effects

    private var sideEffectsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            numberedLabel("08", "Side effects")
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

    // MARK: - Save corrections

    private var saveCorrectionsButton: some View {
        Button("Save corrections") { save() }
            .buttonStyle(.primary)
            .padding(.top, Spacing.s)
    }

    /// Single commit path — both the toolbar Save and the bottom "Save corrections" call this.
    private func save() {
        viewModel.confirm()
        dismiss()
    }

    // MARK: - Reusable scale row

    private func scaleRow<T: CaseIterable & Equatable>(
        cases: T.AllCases,
        kind: GlyphSignal? = nil,
        selected: T?,
        accentColor: Color,
        label: @escaping (T) -> String,
        onSelect: @escaping (T) -> Void
    ) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(cases.enumerated()), id: \.offset) { item in
                let level = item.element
                let isSelected = selected == level
                Button { onSelect(level) } label: {
                    VStack(spacing: 3) {
                        if let kind {
                            SignalGlyph(kind, level: item.offset + 1, size: 24, decorative: true)
                        }
                        Text(label(level))
                            .font(Typography.caption.weight(isSelected ? .semibold : .regular))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.s)
                    .background(isSelected ? accentColor.opacity(0.2) : Theme.surface2)
                    .foregroundStyle(isSelected ? accentColor : Theme.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(label(level))
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
        .clipShape(.rect(cornerRadius: Radius.control))
    }

    // MARK: - Helpers

    private func numberedLabel(_ number: String, _ title: String) -> some View {
        HStack(spacing: Spacing.s) {
            Text(number)
                .font(Typography.mono12)
                .foregroundStyle(Theme.accent)
            Text(title)
                .font(Typography.label)
                .textCase(.uppercase)
                .tracking(0.6)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private func currentLine(_ name: String, _ synonym: String) -> some View {
        Text("\(name) · \(synonym)")
            .font(Typography.caption)
            .foregroundStyle(Theme.textSecondary)
            .padding(.horizontal, Spacing.xs)
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
