# Implementation Plan: Recording Detail UX Pass

**Branch**: `feat/027-recording-detail-ux-pass` | **Date**: 2026-06-27 | **Spec**: [spec.md](spec.md)

## Summary

Four self-contained presentation changes across four files. No new model, no service
change, no migration. All changes are SwiftUI view rewrites — exempt from test-first per
Principle X, verified by build + on-device run.

## Constitution Check

- [x] **I. SwiftUI-First** — PASS. Pure SwiftUI on iOS 26 APIs. Approved HTML mockup
      (`html-mockups/checkin-detail-and-log-dose.html`) precedes every view change.
      `MedicationLogSheet` migrates from `Form` to custom SwiftUI layout.
- [x] **II. Test-Build-Ship** — PASS. Build + full suite green before PR. Owner device QA.
- [x] **III. Correctness Over Speed** — PASS. `onRegenerate` parameter removed (no dead
      param); `Form` removed (no dead style). The spec-026 delete-confirmation dependency
      is explicitly surfaced in Out of Scope.
- [x] **IV. Minimal Surface** — PASS. No new abstraction. `ADHDSummarySection` shrinks
      (loses `summaryCard` + `onRegenerate`). `RecordingDetailView` loses the `editButton`
      computed property. No new type.
- [x] **V. Solo Git Discipline** — PASS. `feat/027-recording-detail-ux-pass` off `main`.
      PR + `/code-review` before merge. Does not stack on 024 or 026.
- [ ] **VI–IX** — N/A. No data flow, extraction, privacy, or schema change.
- [x] **X. Test-First Development** — PASS. All changes are SwiftUI view changes. Per
      Principle X, SwiftUI views are exempt from test-first and verified by build + device run.

**Result: PASS**

## Technical Context

| Item | Value |
|---|---|
| Language | Swift 6 (strict concurrency) |
| UI | SwiftUI iOS 26+ |
| Design tokens | `SquirlDesignSystem` — `Theme`, `Palette`, `Spacing`, `Radius`, `Metrics`, `Typography` |
| Data | SwiftData read-only (`Recording.medicationEvents`, `.decodedEmotions`, `.decodedSideEffects`, `.sleepHours`, `.decodedSleepLevel`) |
| Testing | Build + on-device run (SwiftUI view changes — exempt per Principle X) |
| New files | None |
| Deleted files | None |

## File Reference

| File | Change |
|---|---|
| [`app-four/Views/Components/FoldedDayCardHeader.swift:18`](../../app-four/Views/Components/FoldedDayCardHeader.swift#L18) | `HStack(alignment: .top, …)` → `HStack(alignment: .center, …)` |
| [`app-four/Views/Components/ADHDSummarySection.swift`](../../app-four/Views/Components/ADHDSummarySection.swift) | Remove `summaryCard`, `onRegenerate`, `hasSummaryContent`, `hasTags`. Add `medsCard`, `sleepCard`, `emotionsCard`, `sideEffectsCard`. Rewrite `body`. |
| [`app-four/Views/RecordingDetailView.swift`](../../app-four/Views/RecordingDetailView.swift) | Remove `editButton` prop + `onRegenerate:` arg. Add pencil toolbar item, `deleteButton`, `showDeleteConfirmation` state, glyph size 26→30. |
| [`app-four/Views/Components/MedicationLogSheet.swift`](../../app-four/Views/Components/MedicationLogSheet.swift) | Replace `NavigationStack { Form { … } }` with custom dark-card sheet. |

## Complexity Tracking

No Principle IV violations. Every change removes code or replaces one presentation
pattern with another. Net line count is negative across all four files.

---

## Phase 0 — Design Decisions (recorded)

All design decisions were made and approved in the mockup session. Recorded here for
the implementer.

### ADHDSummarySection card order and gating

Cards appear in order: Medications → Sleep → Emotions → Side Effects. Each is individually
gated on non-empty data:

| Card | Condition to show | Data source |
|---|---|---|
| Medications | `!transcriptMeds.isEmpty` | `recording.medicationEvents.filter { $0.source == .transcript }` |
| Sleep | `decodedSleepLevel != nil \|\| sleepHours != nil` | `recording.decodedSleepLevel`, `recording.sleepHours` |
| Emotions | `!recording.decodedEmotions.isEmpty` | `recording.decodedEmotions` |
| Side Effects | `!recording.decodedSideEffects.isEmpty` | `recording.decodedSideEffects` |

Why transcript-only for Medications: the card is scoped to "what was mentioned in this
check-in", not "all meds ever logged". Manual doses from the medication bar are
day-level, not recording-level.

### Sleep card content

Single tag using the existing `DisplayTag` pattern:
- If `decodedSleepLevel` exists: label = `level.rawValue.capitalized`, glyph `GlyphBadge(kind: .sleep)`, color `Palette.sleepIndigo`
- Else if `sleepHours` exists: label = `"\(Int(hours))h sleep"` (integer when whole), icon `moon.fill`, color `Palette.sleepIndigo`
- `TagFlowView` renders it — reuse existing component, no new tag renderer.

### Emotions and Side Effects cards

Both render via `TagFlowView` with `DisplayTag` entries matching the existing construction
in `extraTags` (currently in the removed `summaryCard`). Identical tag colors and icons:
- Emotions: `heart.fill`, `Theme.accent`
- Side Effects: `bandage.fill`, `Palette.warning`

### RecordingDetailView nav bar and bottom

| Before | After |
|---|---|
| Top-right: `Menu { Button("Delete…") }` labeled `"…"` | Top-right: `Button { editViewModel = … } label: { Image(systemName: "pencil") }` in a circle |
| Bottom: gradient "Edit check-in" primary pill | Removed |
| Delete: hidden in menu | Bottom: `deleteButton` — full-width destructive text, `.confirmationDialog` trigger |

The pencil button uses the same circle background style as the existing close/back
buttons (`Theme.cardBackground` fill + `Theme.separator` stroke, 32×32 frame). Use
`accessibilityLabel("Edit check-in")`.

Delete button spec:
```swift
Button("Delete check-in", role: .destructive) {
    showDeleteConfirmation = true
}
.buttonStyle(.plain)
.foregroundStyle(Theme.danger)
.frame(maxWidth: .infinity)
.padding(.top, Spacing.s)
```

Confirmation dialog:
```swift
.confirmationDialog("Delete this check-in?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
    Button("Delete", role: .destructive) {
        pendingDelete = true
        dismiss()
    }
    Button("Cancel", role: .cancel) {}
}
```

### MedicationLogSheet layout

Structure replacing `NavigationStack { Form { … } }`:

```
VStack(spacing: 0) {
    dragHandle                       // RoundedRectangle 36×5, sep fill, top margin
    sheetNav                         // HStack: X circle | "Log Dose" | Save
    ScrollView {
        VStack(alignment: .leading, spacing: Spacing.l) {
            medicationSection        // label + card(chipRow + divider + nameField)
            doseSection              // label + card(pickerOrField + optional divider + onsetRow)
            durationSection          // label + card(hoursField)
            takenAtSection           // label + card(DatePickerRow)
        }
        .padding(Spacing.l)
    }
}
.background(Theme.background.ignoresSafeArea())
.presentationDragIndicator(.visible)
```

Card pattern (identical to `TextCheckInComposer.noteBox`):
```swift
.background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Radius.card))
.overlay(RoundedRectangle(cornerRadius: Radius.card).strokeBorder(Theme.separator, lineWidth: 1))
```

Section labels: `Typography.label` weight `.semibold`, `Theme.textSecondary` foreground,
`Spacing.xs` bottom gap, `Spacing.s` horizontal padding (same as the eyebrow in card headers).

Save button: right-side nav item, `Theme.accent` color, disabled when `trimmedName.isEmpty`.
Cancel: X circle button matching `TextCheckInComposer` close button (30×30, card background,
separator stroke, `xmark` SF Symbol).

Internal `onChange(of: name)` call to `applyCatalogDefaults` is preserved — no logic change.

---

## Phase 1 — Implementation (tasks.md)

Four independent tasks; Tasks 2 and 3 share the `ADHDSummarySection` API surface
so Task 2 must complete before Task 3.

See [tasks.md](tasks.md).
