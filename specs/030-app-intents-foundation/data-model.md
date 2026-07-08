<!-- Created: 2026-07-03 18:51 (WEST) · Updated: 2026-07-03 18:51 (WEST) -->
# Data Model: App Intents Foundation + NFC Sticker Actions

**Feature**: [spec.md](spec.md) · **Research**: [research.md](research.md)

No new `@Model` types. One existing model gains five defaulted fields; one existing model is consumed unchanged. One new non-persisted enum and one outcome type.

## AppSettings — five new fields (extends [AppSettings.swift](../../app-four/Models/AppSettings.swift))

| Field | Type | Default | Purpose | Constitution IX check |
|---|---|---|---|---|
| `defaultMedicationName` | `String?` | `nil` | "My medication" — catalog name (`Concerta`/`Ritalin`/`Elvanse`) | optional ✓ · no unique ✓ |
| `defaultMedicationDose` | `String?` | `nil` | Chosen dose option, e.g. `"30 mg"` (one of the catalog entry's `doseOptions`) | optional ✓ |
| `doseGuardModeRaw` | `String` | `"off"` | Dose guard state — raw value of `DoseGuardMode` | defaulted ✓ |
| `doseGuardWindowHours` | `Int` | `2` | Window for `.window` mode; valid values 1–4 | defaulted ✓ |
| `nameMedicationInConfirmations` | `Bool` | `false` | Confirmation Style — `false` = discreet everywhere (clarification 2026-07-03) | defaulted ✓ |

- Access pattern: fetch-first-or-create singleton, identical to `SettingsViewModel.appSettings` ([SettingsViewModel.swift:47-56](../../app-four/ViewModels/SettingsViewModel.swift#L47-L56)). The intent-side read goes through `DoseLogService`, never through SwiftUI.
- `defaultMedicationName`/`Dose` are treated as configured only when **both** are non-nil and the name resolves via `MedicationCatalog.entry(matching:)` ([MedicationCatalog.swift:41-45](../../app-four/Models/MedicationCatalog.swift#L41-L45)); a dangling value (catalog changed) degrades to the not-configured path — never a crash, never a half-configured log.
- Validation lives at the edges: the picker UI can only produce valid pairs; `DoseLogService` re-validates at run time.
- Pre-existing `@Attribute(.unique)` on `AppSettings.id` is untouched (tracked separately in BACKLOG).

## DoseGuardMode (new, non-persisted enum)

```
off      — every expedited trigger logs (default)
total    — blocked while the most recent dose event is still active (isActive(at: now))
window   — blocked while now < takenAt + doseGuardWindowHours · 3600
```

- Stored as `doseGuardModeRaw: String`; unknown raw values decode as `.off` (forward-safe).
- Boundary rule (FR-012): at exactly window end / effect end the guard is **closed** — matches shipped semantics `effectProgress < 1` ([MedicationEvent.swift:68-77](../../app-four/Models/MedicationEvent.swift#L68-L77)) and the med bar's strict `>` ([MedicationBarViewModel.swift:75](../../app-four/ViewModels/MedicationBarViewModel.swift#L75)).
- Guard applies to **expedited logs only** (clarification Option A); the in-app Log Dose sheet never consults it.

## MedicationEvent — consumed unchanged ([MedicationEvent.swift](../../app-four/Models/MedicationEvent.swift))

Intent-created events are ordinary manual events:

| Field | Value for expedited logs |
|---|---|
| `name` / `dose` | from the validated default (catalog name + dose option) |
| `takenAt` | trigger time (`now`), absolute — guard comparisons use absolute elapsed time (timezone-immune) |
| `durationHours` | catalog entry's `durationHours` (Concerta 12 · Ritalin 3 · Elvanse 10), user-editable afterward as today |
| `source` | `.manual` |
| `recording` | `nil` (standalone event — relationship already optional) |
| `isMockData` | `false` — always (intents are a real-data surface) |

After insert + save, post `.medicationEventsDidChange` so the med bar refreshes ([MedicationBarViewModel.swift:8-11](../../app-four/ViewModels/MedicationBarViewModel.swift#L8-L11)) — FR-006's indistinguishability comes free.

**Guard reference query**: most recent event where `taken == true && isMockData == false`, sorted `takenAt` descending, `fetchLimit 1` — any medication, any logging surface (clarification Q3 = A). No 24 h cutoff: the bar's cutoff is a display concern; a stale latest event simply passes the guard.

## DoseLogOutcome (new, non-persisted result type)

Returned by `DoseLogService.logDefaultDose(now:)`; the intent maps it 1:1 to dialogs (see [contracts/app-intents.md](contracts/app-intents.md)):

```
logged(name: String, dose: String, at: Date)   — event written and saved
guarded(activeSince: Date)                     — nothing written; earlier dose's takenAt for the calm message
notConfigured                                  — nothing written; drives the continue-to-Settings path
```

## Confirmation copy matrix (FR-005/FR-011/FR-023)

Time renders in the system short time style; `nameMedicationInConfirmations` governs every surface uniformly.

| Outcome | Toggle OFF (default, discreet) | Toggle ON (named) |
|---|---|---|
| logged | "Dose logged · 17:42" | "Elvanse 30 mg logged · 17:42" |
| guarded | "Your 14:00 dose is still active." | same (names time, never the drug — calm, no shame) |
| notConfigured | "Set your medication first." (+ continue offer) | same |

`IntentDialog` `full` variant carries the sentence Siri speaks; `supporting` carries the short visual form. Copy never includes journal content beyond the just-logged fact (FR-021).

## State transitions

None. No lifecycle changes to `Recording` or `MedicationEvent`; check-in recordings started by the intent enter the existing pipeline (`.pendingTranscription` queue when the model is absent — [CheckInViewModel.swift:203-207](../../app-four/ViewModels/CheckInViewModel.swift#L203-L207)).
