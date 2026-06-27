# Tasks: Recording Detail UX Pass (spec-027)

**Branch**: `feat/027-recording-detail-ux-pass`
**Plan**: [plan.md](plan.md)

All tasks are SwiftUI view changes — exempt from test-first per Principle X.
Verified by: build green + on-device visual QA per acceptance scenarios in spec.md.

Tasks 001–002 and 004 are independent.
Task 003 depends on Task 002 (consumes the updated `ADHDSummarySection` API).

---

## Task 001 — FoldedDayCardHeader: centre-align title against glyph

**File**: `app-four/Views/Components/FoldedDayCardHeader.swift`
**Scope**: 1 line

**Change**:
```swift
// Line 18 — before
HStack(alignment: .top, spacing: Spacing.m) {

// Line 18 — after
HStack(alignment: .center, spacing: Spacing.m) {
```

**Verify** (spec §US1 AC 1–3):
- Expand any day card → title centres against glyph.
- Fold/unfold at max Dynamic Type → no regression.
- Collapsed card (two lines) → layout unchanged.

**Checkpoint**: build green, visual check on device.

---

## Task 002 — ADHDSummarySection: replace summary with 4 individual cards

**File**: `app-four/Views/Components/ADHDSummarySection.swift`

**Remove**:
- `var onRegenerate: (() -> Void)?` parameter
- `summaryCard` computed property (bullets + regenerate button + all tags)
- `hasSummaryContent`, `hasTags`, `extraTags` computed properties

**Keep unchanged**:
- `transcriptMeds` private var
- `medsCard` computed property — **eyebrow updated "Meds" → "Medications"** to match spec §US2 AC1
- `medsLine` computed property (unchanged)

**Add** — `sleepCard`:
```swift
@ViewBuilder private var sleepCard: some View {
    let tag: DisplayTag? = {
        if let level = recording.decodedSleepLevel {
            return DisplayTag(id: "sleep", label: level.rawValue.capitalized,
                              icon: "moon.fill", color: Palette.sleepIndigo,
                              glyph: GlyphBadge(kind: .sleep))
        } else if let hours = recording.sleepHours {
            let label = hours == hours.rounded() ? "\(Int(hours))h sleep" : "\(hours)h sleep"
            return DisplayTag(id: "sleep", label: label,
                              icon: "moon.fill", color: Palette.sleepIndigo)
        }
        return nil
    }()
    if let tag {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("Sleep").cardEyebrow()
            TagFlowView(tags: [tag])
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}
```

**Add** — `emotionsCard`:
```swift
@ViewBuilder private var emotionsCard: some View {
    let tags = recording.decodedEmotions.enumerated().map { i, e in
        DisplayTag(id: "e-\(i)", label: e.capitalized, icon: "heart.fill", color: Theme.accent)
    }
    if !tags.isEmpty {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("Emotions").cardEyebrow()
            TagFlowView(tags: tags)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}
```

**Add** — `sideEffectsCard`:
```swift
@ViewBuilder private var sideEffectsCard: some View {
    let tags = recording.decodedSideEffects.enumerated().map { i, e in
        DisplayTag(id: "se-\(i)", label: e.capitalized, icon: "bandage.fill", color: Palette.warning)
    }
    if !tags.isEmpty {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("Side Effects").cardEyebrow()
            TagFlowView(tags: tags)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}
```

**Rewrite `body`**:
```swift
var body: some View {
    VStack(alignment: .leading, spacing: Spacing.l) {
        if !transcriptMeds.isEmpty { medsCard }
        sleepCard
        emotionsCard
        sideEffectsCard
    }
}
```

**Verify** (spec §US2 AC 1–6):
- Check-in with meds, sleep, emotions, side effects → all 4 cards present in order.
- Check-in with no sleep → Sleep card absent.
- Check-in with no emotions → Emotions card absent.
- Check-in with no side effects → Side Effects card absent.
- No summary bullets or regenerate button visible anywhere.
- Preview variants in `#Preview` still compile (update `onRegenerate:` arg → remove it).

**Checkpoint**: build green. Update `#Preview` blocks to remove `onRegenerate:` arg.

---

## Task 003 — RecordingDetailView: pencil icon, delete button, glyph 26→30

**File**: `app-four/Views/RecordingDetailView.swift`
**Depends on**: Task 002 complete (so `ADHDSummarySection` no longer takes `onRegenerate:`)

**Changes** (in order of diff appearance):

### 3a — glyph size
```swift
// glyphSummaryItem — before
SignalGlyph(kind, level: level, size: 26, decorative: true)

// after
SignalGlyph(kind, level: level, size: 30, decorative: true)
```

### 3b — (skipped: `showDeleteConfirm` already exists in source at line 10)

### 3c — toolbar: replace `···` menu with pencil button
```swift
// Remove the existing ToolbarItem(.topBarTrailing) Menu block entirely.
// Replace with:
ToolbarItem(placement: .topBarTrailing) {
    Button {
        editViewModel = ExtractionReviewViewModel(
            recording: viewModel.recording,
            store: store,
            onComplete: { [self] _ in editViewModel = nil }
        )
    } label: {
        Image(systemName: "pencil")
            .font(Typography.subheadline)
            .foregroundStyle(Theme.textPrimary)
            .frame(width: 30, height: 30)
            .background(Theme.cardBackground, in: Circle())
            .overlay(Circle().strokeBorder(Theme.separator, lineWidth: 1))
    }
    .accessibilityLabel("Edit check-in")
}
```

### 3d — remove `editButton` and its call site
Remove the `editButton` computed property entirely.
Remove `editButton` from `body`'s `VStack`.

### 3e — add `deleteButton` and call site
```swift
private var deleteButton: some View {
    Button("Delete check-in", role: .destructive) {
        showDeleteConfirm = true   // uses existing state var (not showDeleteConfirmation)
    }
    .buttonStyle(.plain)
    .foregroundStyle(Theme.danger)
    .frame(maxWidth: .infinity)
    .padding(.top, Spacing.s)
}
```

Add to `body` VStack after `audioCard`:
```swift
deleteButton
```

### 3f — (skipped: `.confirmationDialog` already exists in source at lines 74–79, bound to `$showDeleteConfirm`)

### 3g — remove `onRegenerate:` argument
```swift
// before (actual source used viewModel.startRegenerate(), not regenerateSummary())
ADHDSummarySection(
    recording: viewModel.recording,
    onRegenerate: { viewModel.startRegenerate() }
)

// after
ADHDSummarySection(recording: viewModel.recording)
```

**Verify** (spec §US2 AC 1–6, §US3 AC 1–7):
- Pencil icon visible top-right; tapping opens edit sheet.
- `···` menu is gone.
- Old "Edit check-in" gradient pill is gone.
- Scrolling to bottom: "Delete check-in" in red.
- Tapping delete → confirmation dialog. Cancel → no deletion. Confirm → view dismisses + deletes.
- Glyphs at 30pt: clearly larger than before but not dominant.

**Checkpoint**: build green, on-device QA both light and dark mode.

---

## Task 004 — MedicationLogSheet: restyle to app design system

**File**: `app-four/Views/Components/MedicationLogSheet.swift`

No logic changes. All `@State` vars, `onLog` callback, `viewModel`, `catalogEntry`,
`trimmedName`, `applyCatalogDefaults`, and `medicationChips` retain their current
implementations. Only the top-level layout and rendering change.

**Replace `body`**:

```swift
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
```

**Add `sheetNav`**:
```swift
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
```

**Add `medicationSection`**:
```swift
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
```

**Add `doseSection`**:
```swift
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
```

**Add `durationSection`**:
```swift
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
```

**Add `takenAtSection`**:
```swift
private var takenAtSection: some View {
    VStack(alignment: .leading, spacing: Spacing.xs) {
        Text("Taken At")
            .font(Typography.label.weight(.semibold))
            .foregroundStyle(Theme.textSecondary)
        DatePicker("Time", selection: $takenAt, in: ...Date(), displayedComponents: .hourAndMinute)
            .labelsHidden()  // label shown as card row label below
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, Spacing.s)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Radius.card))
            .overlay(RoundedRectangle(cornerRadius: Radius.card).strokeBorder(Theme.separator, lineWidth: 1))
    }
}
```

> Note on `takenAtSection`: `DatePicker` with `.labelsHidden()` and card background
> matches the mockup. If the DatePicker chrome conflicts with the dark background,
> add `.colorScheme(.dark)` to the DatePicker. Owner to verify on device.

**Remove**: the existing `body` containing `NavigationStack { Form { … } }` entirely.
The `medicationChips` private var is kept with two changes:
- Remove `.listRowInsets(EdgeInsets())` (no longer inside `List`/`Form`)
- Add `.overlay(Capsule().strokeBorder(selected ? Palette.medication : .clear, lineWidth: 1))` to selected chip (spec §US4 AC3).

**Verify** (spec §US4 AC 1–9):
- Sheet background is dark loam, not system grey.
- Nav: X circle (left), "Log Dose" title (centre), "Save" (right).
- Save is disabled when no name selected/typed.
- Selecting a chip fills the name field, highlights the chip in purple.
- For a catalog med: dose shows a picker + onset hint row.
- For a free-text med: dose shows a plain text field.
- Duration section: card with "Hours" label and numeric field.
- Taken At: DatePicker in a card row.
- Saving calls `onLog` with same arguments — verify by logging a dose end-to-end.

**Checkpoint**: build green, on-device QA light + dark mode.
