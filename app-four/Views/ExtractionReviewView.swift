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

    // The 20 curated Mood-Meter emotions (5 per valence×energy quadrant), grouped by
    // valence and ordered high→low energy within each group. Mirrors Lexicon.defaultEmotions
    // and lexicon.json's "emotions" key — see specs/020-emotions-lexicon/contracts.
    private let emotionGroups: [ChipGroup] = [
        ChipGroup(label: "Pleasant",   items: ["excited", "joyful", "proud", "thrilled", "inspired",
                                               "content", "grateful", "peaceful", "secure", "serene"]),
        ChipGroup(label: "Unpleasant", items: ["angry", "anxious", "frustrated", "irritated", "jealous",
                                               "sad", "lonely", "disappointed", "hopeless", "discouraged"])
    ]

    private let commonSideEffects = [
        "dry mouth", "headache", "nausea", "appetite gone", "insomnia",
        "jittery", "heart racing", "stomach ache", "dizzy", "irritable",
        "rebound", "crash", "sweating", "grinding teeth", "flat affect"
    ]

    private let sleepDurations = [2.0, 4.0, 6.0, 8.0, 10.0]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    whenField
                    moodField
                    energyField
                    focusField
                    sleepField
                    medicationsField
                    emotionsField
                    sideEffectsField
                    Button("Save corrections") { save() }
                        .buttonStyle(.primary)
                        .padding(.top, Spacing.l)
                }
                .padding(.horizontal, Spacing.l)
                .padding(.bottom, Spacing.l)
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
                    Button("Save") { save() }.fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear(perform: syncCustomHours)
    }

    // MARK: - Field scaffold (hairline-separated, not cards)

    private func field<H: View, C: View>(@ViewBuilder header: () -> H, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: Spacing.m) {
                header()
                content()
            }
            .padding(.vertical, Spacing.l)
            Divider().overlay(Theme.separator)
        }
    }

    private func numberedHeader<T: View>(_ number: String, _ name: String, @ViewBuilder trailing: () -> T) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
            Text(number).font(Typography.mono12).foregroundStyle(Theme.accent)
            Text(name).cardEyebrow()
            Spacer()
            trailing()
        }
    }

    /// The "Great · bright, thriving" current-value line: name accent, synonym muted.
    @ViewBuilder
    private func synonym(_ name: String?, _ syn: String?) -> some View {
        if let name {
            let nameText = Text(name).font(Typography.caption.weight(.semibold)).foregroundStyle(Theme.accent)
            let synText = Text(syn.map { " · \($0)" } ?? "").font(Typography.caption).foregroundStyle(Theme.textSecondary)
            Text("\(nameText)\(synText)")
        }
    }

    // MARK: - 01 When

    private var whenField: some View {
        field {
            numberedHeader("01", "When") { EmptyView() }
        } content: {
            HStack(spacing: Spacing.s) {
                dateBox("Date") {
                    DatePicker("", selection: $viewModel.date, in: ...Date(), displayedComponents: .date)
                        .labelsHidden().accessibilityLabel("Check-in date")
                }
                dateBox("Time") {
                    DatePicker("", selection: $viewModel.date, in: ...Date(), displayedComponents: .hourAndMinute)
                        .labelsHidden().accessibilityLabel("Check-in time")
                }
            }
        }
    }

    private func dateBox<P: View>(_ label: String, @ViewBuilder picker: () -> P) -> some View {
        HStack {
            Text(label).font(Typography.caption).foregroundStyle(Theme.textSecondary)
            Spacer()
            picker()
        }
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.s)
        .frame(maxWidth: .infinity)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Radius.control))
        .overlay(RoundedRectangle(cornerRadius: Radius.control).strokeBorder(Theme.separator, lineWidth: 1))
    }

    // MARK: - 02/03/04 Mood / Energy / Focus

    private var moodField: some View {
        field {
            numberedHeader("02", "Mood") {
                let level = MoodLevel(rawValue: viewModel.mood)
                synonym(level?.displayLabel, level?.subtitle)
            }
        } content: {
            GlyphRampPicker(kind: .mood, selection: moodBinding)
        }
    }

    private var energyField: some View {
        field {
            numberedHeader("03", "Energy") {
                synonym(viewModel.energy?.displayLabel, viewModel.energy?.subtitle)
            }
        } content: {
            GlyphRampPicker(kind: .energy, selection: energyBinding)
        }
    }

    private var focusField: some View {
        field {
            numberedHeader("04", "Focus") {
                synonym(viewModel.focus?.displayLabel, viewModel.focus?.subtitle)
            }
        } content: {
            GlyphRampPicker(kind: .focus, selection: focusBinding)
        }
    }

    private var moodBinding: Binding<MoodLevel?> {
        Binding(get: { MoodLevel(rawValue: viewModel.mood) }, set: { viewModel.setMood($0?.rawValue ?? "") })
    }
    private var energyBinding: Binding<EnergyLevel?> {
        Binding(get: { viewModel.energy }, set: { viewModel.setEnergy($0) })
    }
    private var focusBinding: Binding<FocusLevel?> {
        Binding(get: { viewModel.focus }, set: { viewModel.setFocus($0) })
    }

    // MARK: - 05 Sleep (named scale, no synonyms, + hours)

    private var sleepField: some View {
        field {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
                SignalGlyph(.sleep, size: 16, decorative: true)
                Text("05").font(Typography.mono12).foregroundStyle(Theme.accent)
                Text("Sleep").cardEyebrow()
                Spacer()
                Text("no synonyms").font(Typography.caption).foregroundStyle(Theme.textSecondary)
            }
        } content: {
            VStack(alignment: .leading, spacing: Spacing.s) {
                HStack(spacing: Spacing.xs) {
                    ForEach(SleepLevel.allCases, id: \.self) { level in
                        segPill(level.rawValue.capitalized,
                                on: viewModel.sleepLevel == level,
                                tint: Palette.sleepIndigo,
                                selectedText: Theme.textPrimary) {
                            viewModel.setSleepLevel(viewModel.sleepLevel == level ? nil : level)
                        }
                    }
                }
                HStack(spacing: Spacing.xs) {
                    ForEach(sleepDurations, id: \.self) { hours in
                        segPill("\(Int(hours))h",
                                on: viewModel.sleepHours == hours,
                                tint: Theme.accent,
                                selectedText: Theme.accent) {
                            viewModel.setSleepHours(viewModel.sleepHours == hours ? nil : hours)
                            customHoursText = ""
                        }
                    }
                    customHoursBox
                }
            }
        }
    }

    private func segPill(_ text: String, on: Bool, tint: Color, selectedText: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(Typography.caption.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.s)
                .background(on ? tint.opacity(0.16) : Theme.cardBackground, in: RoundedRectangle(cornerRadius: Radius.control))
                .overlay(RoundedRectangle(cornerRadius: Radius.control).strokeBorder(on ? tint : Theme.separator, lineWidth: 1))
                .foregroundStyle(on ? selectedText : Theme.textSecondary)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? [.isSelected] : [])
    }

    private var customHoursBox: some View {
        HStack(spacing: Spacing.xs) {
            TextField("7.5", text: $customHoursText)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(Typography.mono12)
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: .infinity)
                .onChange(of: customHoursText) { _, text in
                    let norm = text.replacingOccurrences(of: ",", with: ".")
                    if let h = Double(norm) {
                        viewModel.setSleepHours(h)
                    } else if text.isEmpty, !sleepDurations.contains(viewModel.sleepHours ?? -1) {
                        // Field cleared (and not on a preset) → clear the stored custom value.
                        viewModel.setSleepHours(nil)
                    }
                }
            Text("h").font(Typography.mono12).foregroundStyle(Theme.textSecondary)
        }
        .padding(.horizontal, Spacing.s)
        .padding(.vertical, Spacing.s)
        .frame(maxWidth: .infinity)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Radius.control))
        .overlay(RoundedRectangle(cornerRadius: Radius.control).strokeBorder(isCustomHours ? Theme.accent : Theme.separator, lineWidth: 1))
        .accessibilityLabel("Custom sleep hours")
    }

    private var isCustomHours: Bool {
        guard let h = viewModel.sleepHours else { return false }
        return !sleepDurations.contains(h)
    }

    private func syncCustomHours() {
        if let h = viewModel.sleepHours, !sleepDurations.contains(h) {
            customHoursText = h == h.rounded() ? String(Int(h)) : String(h)
        }
    }

    // MARK: - 06 Medications (inline-expand)

    private var medicationsField: some View {
        field {
            numberedHeader("06", "Medications") {
                Text("Stimulants · no limit").font(Typography.caption).foregroundStyle(Theme.textSecondary)
            }
        } content: {
            VStack(alignment: .leading, spacing: Spacing.s) {
                ForEach(viewModel.medications, id: \.editRowID) { med in
                    selectedMedCard(med)
                }
                medGrid
                Text("Tap to add · expands inline · × to remove · independent events")
                    .font(Typography.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private func selectedMedCard(_ med: MedEvent) -> some View {
        let entry = MedicationCatalog.entry(matching: med.name)
        return VStack(alignment: .leading, spacing: Spacing.s) {
            HStack(spacing: Spacing.s) {
                SignalGlyph(.medication, size: 22, decorative: true)
                Text(med.name).font(Typography.subheadline.weight(.semibold)).foregroundStyle(Theme.textPrimary)
                Spacer()
                Button { viewModel.toggleMedTaken(med) } label: {
                    Text(med.taken ? "Taken" : "Missed")
                        .font(Typography.label)
                        .foregroundStyle(.white)
                        .padding(.horizontal, Spacing.s)
                        .padding(.vertical, Spacing.xs)
                        .background(med.taken ? Palette.medication : Theme.textSecondary, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Mark \(med.name) as taken or missed")
                .accessibilityValue(med.taken ? "Taken" : "Missed")
                Button { viewModel.removeMedication(id: med.editRowID) } label: {
                    Image(systemName: "xmark").font(Typography.caption).foregroundStyle(Theme.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove \(med.name)")
            }

            if let entry {
                Grid(alignment: .leading, horizontalSpacing: Spacing.s, verticalSpacing: Spacing.s) {
                    GridRow(alignment: .top) {
                        Text("Dose").cardEyebrow()
                        FlowLayout(spacing: Spacing.xs) {
                            ForEach(entry.doseOptions, id: \.self) { dose in
                                dosePill(dose, on: med.dose == dose) { viewModel.setMedDose(med, dose: dose) }
                            }
                        }
                    }
                    GridRow {
                        Text("Time").cardEyebrow()
                        Text("\(med.time ?? "08:00") · info").font(Typography.mono12).foregroundStyle(Theme.textSecondary)
                    }
                    GridRow(alignment: .center) {
                        Text("Dur").cardEyebrow()
                        HStack(spacing: Spacing.xs) {
                            DurationField(current: med.durationHours, fallback: entry.durationHours) {
                                viewModel.setMedDuration(med, hours: $0)
                            }
                            Text("shortest").font(Typography.caption).foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
            } else if let dose = med.dose {
                Text(dose).font(Typography.caption).foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Radius.card))
        .overlay(RoundedRectangle(cornerRadius: Radius.card).strokeBorder(Palette.medication.opacity(0.35), lineWidth: 1))
    }

    private func dosePill(_ text: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(Typography.caption.weight(.semibold))
                .padding(.horizontal, Spacing.s)
                .padding(.vertical, Spacing.xs)
                .background(on ? Palette.medication.opacity(0.18) : Theme.surface2, in: Capsule())
                .overlay(Capsule().strokeBorder(on ? Palette.medication : Theme.separator, lineWidth: 1))
                .foregroundStyle(on ? Palette.medication : Theme.textSecondary)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? [.isSelected] : [])
    }

    /// Per-med duration input — backed by local `@State` so partial/fractional typing
    /// (e.g. "7.") is never reformatted away mid-keystroke; commits only parseable values
    /// and normalizes a locale comma to a dot. Seeds from the stored value on appear.
    private struct DurationField: View {
        let current: Double?
        let fallback: Double
        let onCommit: (Double?) -> Void
        @State private var text = ""

        var body: some View {
            HStack(spacing: Spacing.xs) {
                TextField(Self.format(fallback), text: $text)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(Typography.mono12)
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize()
                    .onChange(of: text) { _, value in
                        let norm = value.replacingOccurrences(of: ",", with: ".")
                        onCommit(norm.isEmpty ? nil : Double(norm))
                    }
                Text("h").font(Typography.mono12).foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, Spacing.s)
            .padding(.vertical, Spacing.xs)
            .background(Theme.surface2, in: RoundedRectangle(cornerRadius: Radius.control))
            .overlay(RoundedRectangle(cornerRadius: Radius.control).strokeBorder(Theme.separator, lineWidth: 1))
            .onAppear { if let h = current { text = Self.format(h) } }
            .accessibilityLabel("Duration hours")
        }

        private static func format(_ h: Double) -> String {
            h == h.rounded() ? String(Int(h)) : String(h)
        }
    }

    private var medGrid: some View {
        FlowLayout(spacing: Spacing.s) {
            ForEach(MedicationCatalog.all) { entry in
                let on = viewModel.medications.contains { $0.name == entry.name }
                Button {
                    if on { viewModel.removeMedication(entry.name) } else { viewModel.addMedication(entry.name) }
                } label: {
                    Text(entry.name)
                        .font(Typography.caption.weight(.semibold))
                        .padding(.horizontal, Spacing.m)
                        .padding(.vertical, Spacing.s)
                        .background(on ? Palette.medication.opacity(0.16) : Theme.cardBackground, in: Capsule())
                        .overlay(Capsule().strokeBorder(on ? Palette.medication : Theme.separator, lineWidth: 1))
                        .foregroundStyle(on ? Palette.medication : Theme.textPrimary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(entry.name)\(on ? ", selected" : "")")
                .accessibilityAddTraits(on ? [.isSelected] : [])
            }
        }
    }

    // MARK: - 07/08 Emotions / Side effects

    private var emotionsField: some View {
        field {
            numberedHeader("07", "Emotions") { EmptyView() }
        } content: {
            VStack(alignment: .leading, spacing: Spacing.m) {
                ForEach(emotionGroups) { group in
                    VStack(alignment: .leading, spacing: Spacing.s) {
                        Text(group.label).font(Typography.caption).foregroundStyle(Theme.textSecondary)
                        FlowLayout(spacing: Spacing.s) {
                            ForEach(group.items, id: \.self) { emotion in
                                Chip.filter(emotion.capitalized, isSelected: viewModel.emotions.contains(emotion)) {
                                    viewModel.toggleEmotion(emotion)
                                }
                                .accessibilityLabel("\(emotion)\(viewModel.emotions.contains(emotion) ? ", selected" : "")")
                            }
                        }
                    }
                }
            }
        }
    }

    private var sideEffectsField: some View {
        field {
            numberedHeader("08", "Side effects") { EmptyView() }
        } content: {
            FlowLayout(spacing: Spacing.s) {
                ForEach(commonSideEffects, id: \.self) { effect in
                    Chip.filter(effect.capitalized, isSelected: viewModel.sideEffects.contains(effect)) {
                        viewModel.toggleSideEffect(effect)
                    }
                    .accessibilityLabel("\(effect)\(viewModel.sideEffects.contains(effect) ? ", selected" : "")")
                }
            }
        }
    }

    // MARK: - Commit

    private func save() {
        viewModel.confirm()
        dismiss()
    }
}
