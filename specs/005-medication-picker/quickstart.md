# Quickstart: Medication Picker

How to validate the feature by hand, and the automated tests that lock it in. Maps each
step to the spec's acceptance scenarios / success criteria.

## Manual validation

1. **Open Log Dose** from the medication bar ("Log new dose") → the sheet lists catalog
   medications plus any previously-logged ones. *(US1)*
2. **Select "Concerta XL"** → dose options `18 / 27 / 36 / 54` appear; onset `60 min`
   shows as read-only info; effect duration prefilled `12 h` and editable; taken-time is
   already "now". *(US1, US2)*
3. **Change duration to 8 h, Save** → the dose appears in the medication bar with
   `ends = takenAt + 8 h` (not +10 h). *(US2 / SC-002)*
4. **Type "Foobar 5mg"** (absent from the list), Save → recorded; reopen the sheet →
   "Foobar" is now selectable; it shows no onset and a default editable duration.
   *(US3 / FR-013 / SC-004)*
5. **Attempt a future taken-time** → the picker won't go past now; earlier times work.
   *(FR-006)*
6. **Repeat from the check-in composer** → the same picker control and behavior. *(FR-012)*

## Automated tests

- **`MedicationCatalogTests`** — every entry has ≥1 dose option, `onsetMinutes > 0`,
  `durationHours > 0`; names are unique. *(catalog integrity)*
- **`MedicationPickerViewModelTests`** — catalog ∪ history merge; dedup folds
  "Concerta" / "Concerta XL" / "concerta 36mg" into one entry (FR-014); a typed med
  persists and reappears (FR-008); metadata resolves for catalog entries and omits onset
  for free-text (FR-013).
- **`MedicationBarViewModelTests`** (extend) — `logManualDose(durationHours:)` produces an
  event whose `endsAt` reflects the chosen duration. *(SC-002)*

## Build gate

Build + full test suite green via `ios-debugger-agent` (XcodeBuildMCP) before the feature
is reported done — Constitution Principle II (Test-Build-Ship).

## Sequencing note

Per Principle I, the HTML mockup of the revised sheet is the first task in
`/speckit-tasks` and blocks SwiftUI implementation.
