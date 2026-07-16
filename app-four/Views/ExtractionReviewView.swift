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
        VStack(spacing: 0) {
            NewLookNavBar("Edit check-in") {
                cancelPill
            } trailing: {
                savePill
            }
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.m) {
                    whenCard
                    signalsCard
                    sleepCard
                    medicationsCard
                    emotionsCard
                    sideEffectsCard
                }
                .padding(.horizontal, Spacing.l)
                .padding(.bottom, Spacing.l)
            }
        }
        .background(NewLook.screen.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear(perform: syncCustomHours)
    }

    // MARK: - Nav pills

    private var cancelPill: some View {
        Button {
            viewModel.cancel()
            dismiss()
        } label: {
            Image(systemName: "chevron.backward")
                .font(Typography.headline)
                .foregroundStyle(NewLook.selection)
                .frame(width: 44, height: 44)
                .background(NewLook.card, in: .circle)
        }
        .accessibilityLabel("Cancel")
    }

    private var savePill: some View {
        Button(action: save) {
            Text("Save")
                .font(Typography.headline)
                .foregroundStyle(NewLook.selection)
                .padding(.horizontal, Spacing.l)
                .frame(height: 44)
                .background(NewLook.card, in: .capsule)
        }
        .accessibilityLabel("Save corrections")
    }

    // MARK: - Card scaffold

    private func cardHeader(_ title: String, @ViewBuilder trailing: () -> some View = { EmptyView() }) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(Typography.headline)
                .foregroundStyle(NewLook.inkPrimary)
            Spacer()
            trailing()
        }
    }

    private func groupEyebrow(_ text: String) -> some View {
        Text(text)
            .font(Typography.label)
            .textCase(.uppercase)
            .tracking(0.6)
            .foregroundStyle(NewLook.inkSecondary)
    }

    /// The "Great · bright, thriving" current-value line: name in selection accent, synonym muted.
    @ViewBuilder
    private func synonym(_ name: String?, _ syn: String?) -> some View {
        if let name {
            let nameText = Text(name).font(Typography.caption.weight(.semibold)).foregroundStyle(NewLook.selection)
            let synText = Text(syn.map { " · \($0)" } ?? "").font(Typography.caption).foregroundStyle(NewLook.inkSecondary)
            Text("\(nameText)\(synText)")
        }
    }

    // MARK: - When

    private var whenCard: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            cardHeader("When")
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .newLookCard()
    }

    private func dateBox<P: View>(_ label: String, @ViewBuilder picker: () -> P) -> some View {
        HStack {
            Text(label).font(Typography.caption).foregroundStyle(NewLook.inkSecondary)
            Spacer()
            picker()
        }
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.s)
        .frame(maxWidth: .infinity)
        .background(NewLook.card, in: .rect(cornerRadius: Radius.control))
        .overlay(RoundedRectangle(cornerRadius: Radius.control).strokeBorder(NewLook.hairline, lineWidth: 1))
    }

    // MARK: - Signals (Mood · Energy · Focus grouped)

    private var signalsCard: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            cardHeader("Signals")
            signalRow("MOOD", ramp: {
                GlyphRampPicker(kind: .mood, selection: moodBinding, ringTint: NewLook.selection)
            }, value: {
                let level = MoodLevel(rawValue: viewModel.mood)
                synonym(level?.displayLabel, level?.subtitle)
            })
            signalRow("ENERGY", ramp: {
                GlyphRampPicker(kind: .energy, selection: energyBinding, ringTint: NewLook.selection)
            }, value: {
                synonym(viewModel.energy?.displayLabel, viewModel.energy?.subtitle)
            })
            signalRow("FOCUS", ramp: {
                GlyphRampPicker(kind: .focus, selection: focusBinding, ringTint: NewLook.selection)
            }, value: {
                synonym(viewModel.focus?.displayLabel, viewModel.focus?.subtitle)
            })
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .newLookCard()
    }

    private func signalRow<R: View, V: View>(_ label: String, @ViewBuilder ramp: () -> R, @ViewBuilder value: () -> V) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                groupEyebrow(label)
                Spacer()
                value()
            }
            ramp()
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

    // MARK: - Sleep

    private var sleepCard: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            cardHeader("Sleep") {
                HStack(spacing: Spacing.xs) {
                    SignalGlyph(.sleep, size: 16, decorative: true)
                    Text("no synonyms").font(Typography.caption).foregroundStyle(NewLook.inkSecondary)
                }
            }
            FlowLayout(spacing: Spacing.s) {
                ForEach(SleepLevel.allCases, id: \.self) { level in
                    chipButton(level.rawValue.capitalized, selected: viewModel.sleepLevel == level) {
                        viewModel.setSleepLevel(viewModel.sleepLevel == level ? nil : level)
                    }
                }
            }
            FlowLayout(spacing: Spacing.s) {
                ForEach(sleepDurations, id: \.self) { hours in
                    chipButton("\(Int(hours))h", selected: viewModel.sleepHours == hours) {
                        viewModel.setSleepHours(viewModel.sleepHours == hours ? nil : hours)
                        customHoursText = ""
                    }
                }
                customHoursBox
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .newLookCard()
    }

    /// A New Look selectable chip (standard selection green). Tapping toggles via `action`.
    private func chipButton(_ text: String, selected: Bool, role: NewLookChipRole = .standard, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text).newLookChip(selected: selected, role: role)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private var customHoursBox: some View {
        HStack(spacing: Spacing.xs) {
            TextField("7.5", text: $customHoursText)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .font(Typography.caption)
                .foregroundStyle(NewLook.inkPrimary)
                .fixedSize()
                .frame(minWidth: 24)
                .onChange(of: customHoursText) { _, text in
                    let norm = text.replacingOccurrences(of: ",", with: ".")
                    if let h = Double(norm) {
                        viewModel.setSleepHours(h)
                    } else if text.isEmpty, !sleepDurations.contains(viewModel.sleepHours ?? -1) {
                        // Field cleared (and not on a preset) → clear the stored custom value.
                        viewModel.setSleepHours(nil)
                    }
                }
            Text("h").font(Typography.caption).foregroundStyle(NewLook.inkSecondary)
        }
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.s)
        .background(NewLook.card, in: .capsule)
        .overlay(Capsule().strokeBorder(isCustomHours ? NewLook.selection : NewLook.hairline, lineWidth: 1))
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

    // MARK: - Medications (inline-expand)

    private var medicationsCard: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            cardHeader("Medications") {
                Text("Stimulants · no limit").font(Typography.caption).foregroundStyle(NewLook.inkSecondary)
            }
            ForEach(viewModel.medications, id: \.editRowID) { med in
                selectedMedCard(med)
            }
            medGrid
            Text("Tap to add · expands inline · × to remove · independent events")
                .font(Typography.caption)
                .foregroundStyle(NewLook.inkSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .newLookCard()
    }

    private func selectedMedCard(_ med: MedEvent) -> some View {
        let entry = MedicationCatalog.entry(matching: med.name)
        return VStack(alignment: .leading, spacing: Spacing.s) {
            HStack(spacing: Spacing.s) {
                SignalGlyph(.medication, size: 22, decorative: true)
                Text(med.name).font(Typography.subheadline.weight(.semibold)).foregroundStyle(NewLook.inkPrimary)
                Spacer()
                Button { viewModel.toggleMedTaken(med) } label: {
                    Text(med.taken ? "Taken" : "Missed")
                        .font(Typography.label)
                        .foregroundStyle(med.taken ? NewLook.onSelection : NewLook.inkPrimary)
                        .padding(.horizontal, Spacing.s)
                        .padding(.vertical, Spacing.xs)
                        .background(med.taken ? Palette.medication : NewLook.tintNeutral, in: .capsule)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Mark \(med.name) as taken or missed")
                .accessibilityValue(med.taken ? "Taken" : "Missed")
                Button { viewModel.removeMedication(id: med.editRowID) } label: {
                    Image(systemName: "xmark").font(Typography.caption).foregroundStyle(NewLook.inkSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove \(med.name)")
            }

            if let entry {
                Grid(alignment: .leading, horizontalSpacing: Spacing.s, verticalSpacing: Spacing.s) {
                    GridRow(alignment: .top) {
                        groupEyebrow("Dose")
                        FlowLayout(spacing: Spacing.xs) {
                            ForEach(entry.doseOptions, id: \.self) { dose in
                                chipButton(dose, selected: med.dose == dose, role: .medication) {
                                    viewModel.setMedDose(med, dose: dose)
                                }
                            }
                        }
                    }
                    GridRow {
                        groupEyebrow("Time")
                        Text("\(med.time ?? "08:00") · info").font(Typography.caption).foregroundStyle(NewLook.inkSecondary)
                    }
                    GridRow(alignment: .center) {
                        groupEyebrow("Dur")
                        HStack(spacing: Spacing.xs) {
                            DurationField(current: med.durationHours, fallback: entry.durationHours) {
                                viewModel.setMedDuration(med, hours: $0)
                            }
                            Text("shortest").font(Typography.caption).foregroundStyle(NewLook.inkSecondary)
                        }
                    }
                }
            } else if let dose = med.dose {
                Text(dose).font(Typography.caption).foregroundStyle(NewLook.inkSecondary)
            }
        }
        .padding(Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NewLook.card, in: .rect(cornerRadius: Radius.newLookCard))
        .overlay(RoundedRectangle(cornerRadius: Radius.newLookCard).strokeBorder(Palette.medication.opacity(0.35), lineWidth: 1))
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
                    .font(Typography.caption)
                    .foregroundStyle(NewLook.inkPrimary)
                    .fixedSize()
                    .onChange(of: text) { _, value in
                        let norm = value.replacingOccurrences(of: ",", with: ".")
                        onCommit(norm.isEmpty ? nil : Double(norm))
                    }
                Text("h").font(Typography.caption).foregroundStyle(NewLook.inkSecondary)
            }
            .padding(.horizontal, Spacing.s)
            .padding(.vertical, Spacing.xs)
            .background(NewLook.card, in: .rect(cornerRadius: Radius.control))
            .overlay(RoundedRectangle(cornerRadius: Radius.control).strokeBorder(NewLook.hairline, lineWidth: 1))
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
                chipButton(entry.name, selected: on, role: .medication) {
                    if on { viewModel.removeMedication(entry.name) } else { viewModel.addMedication(entry.name) }
                }
                .accessibilityLabel("\(entry.name)\(on ? ", selected" : "")")
            }
        }
    }

    // MARK: - Emotions / Side effects

    private var emotionsCard: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            cardHeader("Emotions")
            ForEach(emotionGroups) { group in
                VStack(alignment: .leading, spacing: Spacing.s) {
                    groupEyebrow(group.label)
                    FlowLayout(spacing: Spacing.s) {
                        ForEach(group.items, id: \.self) { emotion in
                            chipButton(emotion.capitalized, selected: viewModel.emotions.contains(emotion)) {
                                viewModel.toggleEmotion(emotion)
                            }
                            .accessibilityLabel("\(emotion)\(viewModel.emotions.contains(emotion) ? ", selected" : "")")
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .newLookCard()
    }

    private var sideEffectsCard: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            cardHeader("Side effects")
            FlowLayout(spacing: Spacing.s) {
                ForEach(commonSideEffects, id: \.self) { effect in
                    chipButton(effect.capitalized, selected: viewModel.sideEffects.contains(effect)) {
                        viewModel.toggleSideEffect(effect)
                    }
                    .accessibilityLabel("\(effect)\(viewModel.sideEffects.contains(effect) ? ", selected" : "")")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .newLookCard()
    }

    // MARK: - Commit

    private func save() {
        viewModel.confirm()
        dismiss()
    }
}
