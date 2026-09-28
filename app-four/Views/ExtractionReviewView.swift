import SwiftUI

/// Edit Check-In as the pen draws it (spec 057, `iPhone 17 - 18`): a pushed page — back pill +
/// title, tab bar hidden — with "Date & time" fields, the collapsible "How did you feel?" card
/// (three level-tile pickers + the sleep row), the Medication card (catalog chips, one row per
/// medication with dose chips, Taken / Missed and effect hours), Emotions and Side effects chip
/// groups, and a full-width "Save changes" enabled only once something changed (D-E5).
struct ExtractionReviewView: View {
    @Bindable var viewModel: ExtractionReviewViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var feelingsExpanded = true
    @State private var activePicker: PickerKind?
    @State private var showDiscardPrompt = false
    @State private var customHoursText = ""

    private enum PickerKind: String, Identifiable {
        case date, time
        var id: String { rawValue }
    }

    // The 20 curated Mood-Meter emotions (5 per valence×energy quadrant), grouped by valence and
    // ordered high→low energy within each group. Mirrors Lexicon.defaultEmotions and
    // lexicon.json's "emotions" key — see specs/020-emotions-lexicon/contracts.
    private static let pleasantEmotions = ["excited", "joyful", "proud", "thrilled", "inspired",
                                           "content", "grateful", "peaceful", "secure", "serene"]
    private static let unpleasantEmotions = ["angry", "anxious", "frustrated", "irritated", "jealous",
                                             "sad", "lonely", "disappointed", "hopeless", "discouraged"]
    private static let commonSideEffects = [
        "dry mouth", "headache", "nausea", "appetite gone", "insomnia",
        "jittery", "heart racing", "stomach ache", "dizzy", "irritable",
        "rebound", "crash", "sweating", "grinding teeth", "flat affect"
    ]
    private static let sleepDurations: [Double] = [2, 4, 6, 8, 10]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.cardGap) {
                NavHeader(title: "Edit check-in", onBack: goBack)
                dateTimeSection
                feelingsCard
                medicationCard
                emotionsCard
                sideEffectsCard
                saveButton
            }
            .padding(.horizontal, Spacing.gutter)
            .padding(.top, Spacing.m)
            .padding(.bottom, Spacing.section)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Surface.screen.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .hidesFloatingChrome()
        .trackScreen("ExtractionReviewView")
        .onAppear(perform: syncCustomHours)
        .onDisappear { viewModel.cancelIfUnsaved() }
        .sheet(item: $activePicker) { kind in pickerSheet(kind) }
        .confirmationDialog("Discard changes?", isPresented: $showDiscardPrompt, titleVisibility: .visible) {
            Button("Discard changes", role: .destructive) { dismiss() }
            Button("Keep editing", role: .cancel) {}
        }
    }

    private func goBack() {
        if viewModel.isDirty { showDiscardPrompt = true } else { dismiss() }
    }

    // MARK: - Date & time

    private var dateTimeSection: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            SectionHeading("Date & time")
            HStack(spacing: Spacing.m) {
                DateTimeField("Date", kind: .date,
                              value: viewModel.date.formatted(.dateTime.month(.abbreviated).day())) {
                    activePicker = .date
                }
                DateTimeField("Time", kind: .time,
                              value: viewModel.date.formatted(date: .omitted, time: .shortened)) {
                    activePicker = .time
                }
            }
        }
    }

    /// D-E3: the compact picker cannot take the pen's field styling, so the field presents one.
    private func pickerSheet(_ kind: PickerKind) -> some View {
        NavigationStack {
            Group {
                switch kind {
                case .date:
                    DatePicker("Check-in date", selection: $viewModel.date, in: ...Date(), displayedComponents: .date)
                        .datePickerStyle(.graphical)
                case .time:
                    DatePicker("Check-in time", selection: $viewModel.date, in: ...Date(), displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                }
            }
            .labelsHidden()
            .tint(Accent.primaryFill)
            .padding(.horizontal, Spacing.gutter)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Surface.screen.ignoresSafeArea())
            .navigationTitle(kind == .date ? "Date" : "Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { activePicker = nil }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    // MARK: - How did you feel?

    private var feelingsCard: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            HStack {
                Text("How did you feel?")
                    .font(Typography.cardTitle)
                    .foregroundStyle(Ink.primary)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                NavPill(feelingsExpanded ? .chevronUp : .chevronDown, size: Metrics.navPillSmall) {
                    withAnimation(reduceMotion ? nil : Motion.expand) { feelingsExpanded.toggle() }
                }
                .accessibilityValue(feelingsExpanded ? "Expanded" : "Collapsed")
            }
            if feelingsExpanded {
                HairlineDivider()
                LevelTilePicker(.mood, label: "Mood", selection: moodBinding)
                LevelTilePicker(.energy, label: "Energy level", selection: energyBinding)
                LevelTilePicker(.focus, label: "Focus level", selection: focusBinding)
                HairlineDivider()
                sleepRow
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(.large)
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

    /// D-V1: the sleep vocabulary is the canonical `SleepLevel` ramp; hours stay editable (a
    /// function the pen dropped — D7).
    private var sleepRow: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            ChipGroupView("Your sleep") {
                ForEach(SleepLevel.allCases, id: \.self) { level in
                    ChipButton(level.displayLabel, selected: viewModel.sleepLevel == level) {
                        viewModel.setSleepLevel(viewModel.sleepLevel == level ? nil : level)
                    }
                }
            }
            ChipRow(interactive: true) {
                ForEach(Self.sleepDurations, id: \.self) { hours in
                    ChipButton("\(Int(hours))h", selected: viewModel.sleepHours == hours) {
                        viewModel.setSleepHours(viewModel.sleepHours == hours ? nil : hours)
                        customHoursText = ""
                    }
                }
                customHoursField
            }
        }
    }

    private var customHoursField: some View {
        HStack(spacing: Spacing.xs) {
            TextField("7.5", text: $customHoursText)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .font(Typography.chipLabel)
                .foregroundStyle(Ink.chip)
                .frame(width: 36)
                .onChange(of: customHoursText) { _, text in
                    viewModel.setSleepHours(fromString: text)
                    if text.isEmpty, !Self.sleepDurations.contains(viewModel.sleepHours ?? -1) {
                        viewModel.setSleepHours(nil)
                    }
                }
            Text("h")
                .font(Typography.chipLabel)
                .foregroundStyle(Ink.tertiary)
        }
        .padding(.horizontal, Spacing.m)
        .frame(height: Metrics.chipHeight)
        .background(Surface.card, in: .capsule)
        .overlay {
            Capsule().strokeBorder(isCustomHours ? Accent.primaryFill : Stroke.chip, lineWidth: Stroke.hairlineWidth)
        }
        .frame(minHeight: Metrics.minTapTarget)
        .accessibilityLabel("Custom sleep hours")
    }

    private var isCustomHours: Bool {
        guard let hours = viewModel.sleepHours else { return false }
        return !Self.sleepDurations.contains(hours)
    }

    private func syncCustomHours() {
        if let hours = viewModel.sleepHours, !Self.sleepDurations.contains(hours) {
            customHoursText = hours == hours.rounded() ? String(Int(hours)) : String(hours)
        }
    }

    // MARK: - Medication

    private var medicationCard: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            Text("Medication")
                .font(Typography.cardTitle)
                .foregroundStyle(Ink.primary)
                .accessibilityAddTraits(.isHeader)
            ChipRow(interactive: true) {
                ForEach(MedicationCatalog.all) { entry in
                    let on = viewModel.medications.contains { $0.name == entry.name }
                    ChipButton(entry.name, selected: on) {
                        if on { viewModel.removeMedication(entry.name) } else { viewModel.addMedication(entry.name) }
                    }
                }
            }
            ForEach(viewModel.medicationRows) { row in
                HairlineDivider()
                medicationRow(row)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(.large)
    }

    private func medicationRow(_ row: ExtractionReviewViewModel.MedicationRow) -> some View {
        let entry = MedicationCatalog.entry(matching: row.name)
        return VStack(alignment: .leading, spacing: Spacing.l) {
            ForEach(row.events, id: \.editRowID) { event in
                VStack(alignment: .leading, spacing: Spacing.s) {
                    HStack(spacing: Spacing.s) {
                        MedicationBadge(size: 22)
                        Text(doseRowLabel(row, event))
                            .font(Typography.rowLabel)
                            .foregroundStyle(Ink.primary)
                        Spacer(minLength: Spacing.s)
                        Button {
                            viewModel.removeMedication(id: event.editRowID)
                        } label: {
                            Image(systemName: Icons.close)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Ink.tertiary)
                                .frame(width: Metrics.minTapTarget, height: Metrics.minTapTarget)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove \(row.name)")
                    }
                    if let entry {
                        ChipRow(interactive: true) {
                            ForEach(entry.doseOptions, id: \.self) { dose in
                                ChipButton(dose, selected: event.dose == dose) {
                                    viewModel.setMedDose(event, dose: dose)
                                }
                            }
                        }
                    } else if let dose = event.dose {
                        Text(dose)
                            .font(Typography.captionMedium)
                            .foregroundStyle(Ink.secondary)
                    }
                    HStack(spacing: Spacing.m) {
                        SegmentedPicker([true, false], selection: takenBinding(event)) { $0 ? "Taken" : "Missed" }
                            .frame(maxWidth: 180)
                            .accessibilityLabel("\(row.name) taken or missed")
                        Spacer(minLength: Spacing.s)
                        DurationField(current: event.durationHours, fallback: entry?.durationHours ?? 10) {
                            viewModel.setMedDuration(event, hours: $0)
                        }
                    }
                }
            }
        }
    }

    private func doseRowLabel(_ row: ExtractionReviewViewModel.MedicationRow, _ event: MedEvent) -> String {
        guard row.events.count > 1, let time = event.time else { return "\(row.name) dose" }
        return "\(row.name) dose · \(time)"
    }

    private func takenBinding(_ event: MedEvent) -> Binding<Bool> {
        Binding(
            get: { viewModel.medications.first { $0.editRowID == event.editRowID }?.taken ?? event.taken },
            set: { taken in
                let current = viewModel.medications.first { $0.editRowID == event.editRowID }?.taken ?? event.taken
                if taken != current { viewModel.toggleMedTaken(event) }
            }
        )
    }

    /// Effect-window hours per dose (the medication bar reads it). Local text state so partial
    /// input ("7.") is never reformatted mid-keystroke; commits parseable values, comma → dot.
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
                    .font(Typography.status)
                    .foregroundStyle(Ink.chip)
                    .frame(width: 36)
                    .onChange(of: text) { _, value in
                        let normalised = value.replacingOccurrences(of: ",", with: ".")
                        onCommit(normalised.isEmpty ? nil : Double(normalised))
                    }
                Text("h effect")
                    .font(Typography.captionQuiet)
                    .foregroundStyle(Ink.tertiary)
            }
            .padding(.horizontal, Spacing.m)
            .frame(minHeight: 39)
            .background(Surface.card, in: .rect(cornerRadius: Radius.field))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.field)
                    .strokeBorder(Stroke.field, lineWidth: Stroke.hairlineWidth)
            }
            .onAppear { if let current { text = Self.format(current) } }
            .accessibilityLabel("Effect duration in hours")
        }

        private static func format(_ hours: Double) -> String {
            hours == hours.rounded() ? String(Int(hours)) : String(hours)
        }
    }

    // MARK: - Emotions / Side effects

    private var emotionsCard: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            Text("Emotions")
                .font(Typography.cardTitle)
                .foregroundStyle(Ink.primary)
                .accessibilityAddTraits(.isHeader)
            emotionGroup("Pleasant", Self.pleasantEmotions)
            emotionGroup("Unpleasant", Self.unpleasantEmotions)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(.large)
    }

    private func emotionGroup(_ title: String, _ emotions: [String]) -> some View {
        ChipGroupView(title) {
            ForEach(emotions, id: \.self) { emotion in
                ChipButton(emotion.capitalized, selected: viewModel.emotions.contains(emotion)) {
                    viewModel.toggleEmotion(emotion)
                }
            }
        }
    }

    private var sideEffectsCard: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            Text("Side effects")
                .font(Typography.cardTitle)
                .foregroundStyle(Ink.primary)
                .accessibilityAddTraits(.isHeader)
            ChipRow(interactive: true) {
                ForEach(Self.commonSideEffects, id: \.self) { effect in
                    ChipButton(effect.capitalized, selected: viewModel.sideEffects.contains(effect)) {
                        viewModel.toggleSideEffect(effect)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(.large)
    }

    // MARK: - Save

    /// `confirm()` calls `onComplete`, whose owner pops this page; no `dismiss()` here or the
    /// stack pops twice.
    private var saveButton: some View {
        Button("Save changes") { viewModel.confirm() }
            .buttonStyle(.filled(fullWidth: true))
            .disabled(!viewModel.isDirty)
    }
}
