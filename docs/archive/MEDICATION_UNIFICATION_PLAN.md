# Medication Model Unification — Proposal & Implementation Plan

Goal: one medication concept used everywhere. Manual logs and transcript-extracted meds become the **same persisted type**. The bar, the recording detail, and the calendar all read from **one source**. No more two tracks, no more conflicting info.

---

## Problem today (recap)

Two separate types:
- `MedicationDose` — a SwiftData `@Model`. Made when the user taps the bar.
- `MedEvent` — a `Codable` struct stored as JSON inside each `Recording` (`medicationsJSON`). Made by the NLP extractor.

The bar shows one or the other by priority. The detail shows only a recording's own `MedEvent`s. They never sync, so the bar and the detail can show different medications.

---

## Proposal: one model, `MedicationEvent`

Make **one** persisted SwiftData `@Model` that is the single source of truth for every medication, whether typed by the user or pulled from a transcript.

```
MedicationEvent  (@Model, SwiftData)
├─ id: UUID
├─ name: String
├─ dose: String?
├─ takenAt: Date            // ONE absolute time, resolved once (no more "HH:mm" string + label drift)
├─ taken: Bool              // false when "didn't take it"
├─ quantity: Double?        // 1.0 full, 0.5 half
├─ durationHours: Double    // per-med effect window (default 10), no longer hard-coded at read time
├─ change: MedEventChange?  // started / stopped / regular
├─ timeLabel: String?       // raw phrase kept for provenance ("morning", "after lunch")
├─ source: Source           // .manual | .transcript
├─ createdAt: Date
└─ recording: Recording?    // relationship — set when it came from a recording; nil for a standalone manual log
```

`Recording` gets the inverse relationship:

```
Recording
└─ @Relationship(deleteRule: .cascade, inverse: \MedicationEvent.recording)
   var medicationEvents: [MedicationEvent]
```

### What this gives us
- **One type.** `MedicationDose` is deleted. `medicationsJSON` is deleted.
- **Manual = auto.** A manual log is just a `MedicationEvent` with `source = .manual` and `recording = nil`. A transcript med is a `MedicationEvent` with `source = .transcript` and a linked recording. Same fields, same table.
- **No drift.** The bar and the detail read the **same rows**. Editing in the detail updates the exact object the bar shows.
- **Time resolved once.** The "parse HH:mm against the recording date / fall back to creation time" logic runs **at save time** and is stored as `takenAt`. No re-parsing on every read.
- **Source is visible.** Because `source` is a field, the bar can show a small marker (typed by you vs from a note) — fixing today's "can't tell where it came from."

### Keep the extractor pure
The NLP extractor still returns the lightweight value struct `MedEvent` (Sendable, testable, no SwiftData). It is now treated as a **DTO**: a mapping step converts each `MedEvent` into a persisted `MedicationEvent` row when a recording is saved. So:
- `MedEvent` (struct) = transient output of extraction only.
- `MedicationEvent` (@Model) = the one stored, displayed, edited truth.

This is the single behavioral change the request asks for ("only MedEvent logic, allows manual input") while keeping the service layer clean.

---

## Field mapping (old → new)

| Old `MedEvent` (JSON) | Old `MedicationDose` | New `MedicationEvent` |
|---|---|---|
| name | name | name |
| dose | dose | dose |
| time (String) + timeLabel + fallback | takenAt (Date) | **takenAt (Date)** — resolved at save; timeLabel kept |
| taken | (always taken) | taken |
| quantity | — | quantity |
| change | — | change |
| (hard-coded 10h at read) | durationHours | durationHours |
| (implicit: from recording) | source = .manual | source (.manual/.transcript) |
| — | — | recording (relationship) |

---

## Implementation plan

### Phase 1 — Add the model
- New file `Models/MedicationEvent.swift`: the `@Model` above + `Source` enum.
- Reuse the existing `MedEventChange` enum.
- Add the `medicationEvents` relationship to `Recording`.
- Register `MedicationEvent` in `AppModelContainer` schema.

### Phase 2 — Map extraction → rows
- In `Recording.applyExtraction(...)` (currently writes `medicationsJSON`): instead, build `MedicationEvent` rows from `result.medications`, resolve `takenAt` once (move the `displayFrom` time logic here), set `source = .transcript`, link `recording = self`, insert into the context.
- Set `hasMedication` from `!medicationEvents.isEmpty` (or drop the stored flag and compute it).
- Stop writing `medicationsJSON`. Remove `medications` from the extraction JSON so there is no second copy.

### Phase 3 — Rewrite the bar view model
- `MedicationBarViewModel.refresh()` becomes one query: latest `MedicationEvent` where `taken == true` and `takenAt` within the active window, sorted by `takenAt` desc. No more two-step priority.
- `logManualDose(...)` creates a `MedicationEvent(source: .manual, recording: nil)` and saves.
- `DoseDisplay` can stay as a thin view struct, or the view can read the model directly.

### Phase 4 — Update the log sheet
- `MedicationLogSheet` keeps name, dose, takenAt.
- Optional: add a duration field (so `durationHours` is not always 10). Default 10.

### Phase 5 — Update detail, calendar, insights
- `RecordingDetailView` / `ADHDSummarySection`: read `recording.medicationEvents` (relationship) instead of `decodedMedications` (JSON).
- Editing meds in `ExtractionReviewViewModel`: edit the `MedicationEvent` rows directly. Because the bar reads the same table, the bar updates with no extra wiring.
- Calendar/Insights medication dots/tags: read from `medicationEvents`.

### Phase 6 — Migrate, then delete the old types
- One-time migration on launch:
  - Each `MedicationDose` → `MedicationEvent(source: .manual, recording: nil)`.
  - Each recording's `medicationsJSON` → decode `[MedEvent]` → `MedicationEvent(source: .transcript, recording: r)`.
- After migration verified: delete `Models/MedicationDose.swift`, the `medicationsJSON` field, and `decodedMedications`.
- Note: app is at v1.0.0 (pre-release). If there is no real user data, skip migration and just reset the store — simpler. Decide based on whether TestFlight data must survive.

### Phase 7 — Tests & verification
- Update `MedicationBarViewModelTests` for the single-query logic.
- Add tests: manual log appears in bar; transcript med appears in bar; editing a recording's med updates the bar; deleting a recording cascades its meds.
- Manual check: bar and detail never disagree for the same medication.

---

## Risks / decisions to confirm

1. **Migration vs reset.** Keep existing TestFlight data (write the migration) or wipe and start clean (faster)? — needs your call.
2. **Duration source.** Use `NoteExtraction.durationHours` when present, else default 10. OK?
3. **Standalone manual logs in the timeline.** A manual log has no recording, so it won't show inside any recording's detail (correct). Do you also want manual logs to appear as their own entries in the Calendar list? (Possible later; not required for uniformity.)
4. **Source marker in the bar.** Add a small "typed by you / from a note" indicator? Recommended, cheap.

---

## Files touched

| File | Action |
|---|---|
| `Models/MedicationEvent.swift` | new `@Model` |
| `Models/Recording.swift` | add relationship; remove `medicationsJSON` + `decodedMedications` (Phase 6) |
| `App/AppModelContainer.swift` | register new model in schema |
| `Models/MedicationDose.swift` | delete (Phase 6) |
| `ViewModels/MedicationBarViewModel.swift` | single-query refresh + manual create |
| `Views/Components/MedicationLogSheet.swift` | optional duration field |
| `Views/RecordingDetailView.swift` / `ADHDSummarySection.swift` | read relationship |
| `ViewModels/ExtractionReviewViewModel.swift` | edit rows, not JSON |
| `Services/NoteExtraction/*` | unchanged (still emits `MedEvent` DTO) |
| `app-twoTests/...MedicationBarViewModelTests` | rewrite |

---

## Order
Phase 1 → 2 → 3 → 4 → 5 → 6 → 7.
Phases 1–5 can ship while the old `medicationsJSON` still exists (write rows, read rows). Delete the old types only in Phase 6 after migration is confirmed.
