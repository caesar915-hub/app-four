# Implementation Plan: Daily Card — Folded Summary, Opens to the Day

**Branch**: `feat/daycard-update` | **Date**: 2026-06-23 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/014-daily-card/spec.md`

## Summary

Redesign the calendar's day card into a **folded summary that opens to the day**: each `DayCard` renders as a single folded line (mood-glyph circle · weekday · "mood · energy · focus · medication-name", logged signals only); a header tap expands it in place to time-ordered check-ins (time-in-medication-phase-ring + % beneath, mood word, energy/focus glyphs, chips). Selecting a calendar date moves that day to the top, filters out more-recent days from the list (greying them in the week-row with a non-color second cue), and auto-expands it (a user setting, default ON). Today loses its calendar ring (pill-only). The technical approach reuses the existing `MoodLibraryViewModel.timelineDays` pipeline (adding a pure `timelineDaysFilteredToSelectedDate(_:)` compute), holds ephemeral fold/selection state as `@State` in `CalendarLibraryView` (a `Set<Date>` for open cards) and passes a derived `isExpanded` down to `DayCard`, persists the auto-expand preference as an `@AppStorage` flag (matching the existing `MedicationBar*` toggles — no schema change), and reuses existing design tokens (`Motion.smooth`, `Radius.card`, `Spacing`, `Palette`, `Typography`) with a small set of additive tokens for chip radius, ring stroke, ring/circle diameters, and opacity. Reduce Motion is honored by wrapping every fold/scroll toggle in `withAnimation(reduceMotion ? nil : Motion.smooth)`, mirroring the existing `scrollList` at [CalendarLibraryView.swift#L143](app-four/Views/Library/CalendarLibraryView.swift#L143).

## Technical Context

- **Language/Version**: Swift 6+ (strict concurrency enabled).
- **Primary Dependencies**: SwiftUI (iOS 26+), SwiftData, Swift Concurrency; reuses the signal-glyph language (spec 006) and Paper & Pollen tokens (`DESIGN.md` / spec 008).
- **Storage**: SwiftData (unchanged). **No schema change** — the one new preference (`autoExpandOnSelection`, default `true`) is an `@AppStorage` UI flag, matching the existing `MedicationBar*` toggles. No `@Model` attribute, no migration.
- **Testing**: Swift Testing (`@Test`, `#expect`/`#require`), **test-first** per Principle X for the view-model/logic units (filter-above, summary-line content, fold/selection state transitions). SwiftUI views (`DayCard`, `CalendarLibraryView`, `FoldedDayCardHeader`) are verified by build + on-simulator run (Principle II) and the HTML mockups (Principle I).
- **Target Platform**: iOS (primary), iPadOS (secondary).
- **Project Type**: mobile-app (single Xcode target/module `app-four`).
- **Performance Goals**: 60fps list scroll in the `LazyVStack` (preserve stable outer identity keyed to `day.date`, conditional inner rows only); instant, jank-free fold/unfold; the auto-expand read is an `@AppStorage`/`UserDefaults` lookup (no main-thread fetch).
- **Constraints**: on-device only (Principle VI — no new data leaves device, no schema attribute carries transcript/medication content); tokens-only visual values (FR-018); Dynamic Type scaling on all card text (FR-015); greyscale/color-blind legibility via redundant shape+fill+hue and numeric readouts (FR-014, FR-020); Reduce Motion honored on fold/unfold and scroll-to-top (FR resolved in Clarifications, `DESIGN.md` L82); 44pt minimum header hit-target.
- **Scale/Scope**: A behavioral redesign of one screen. ~8 files touched; new `FoldedDayCardHeader`, `ExpandedDayCards`, and a `DayCardSettingsSection`; one pure ViewModel method; one `@AppStorage` preference; additive design tokens. No schema, NLP, audio, transcription, or service changes. **No `NEEDS CLARIFICATION` remain** — all open questions resolved in the spec's 2026-06-23 Clarifications session or by source analysis of the interactive prototype.

## Constitution Check

| Principle | Status | Justification |
|---|---|---|
| I. SwiftUI-First | PASS | All new/changed UI is SwiftUI with iOS 26+ APIs; HTML mockups (`mockups/summary/`, `mockups/folded-card-final/`, `mockups/prototype/`) precede implementation. No UIKit, no shims. |
| II. Test-Build-Ship | PASS | Build + full Swift Testing suite must be green on `feat/daycard-update` before the PR; verified via `ios-debugger-agent` (XcodeBuildMCP). |
| III. Correctness Over Speed | PASS | Complete fold/open/filter interaction with no placeholders; empty-state copy corrected verbatim ("No check-ins this day. That's alright.") rather than left as terse "No check-ins" at [DayCard.swift#L24](app-four/Views/Components/DayCard.swift#L24). |
| IV. Minimal Surface | PASS | Reuses `Motion.smooth` for fold/unfold/chevron (no `Motion.chevron`/`Motion.fold` token despite the mockup's 0.26s/0.3s — the ~100ms delta is imperceptible). Filter logic is one pure VM method layered on the existing month filter, not a new observable property. Additive tokens (chip radius, ring stroke, diameters, opacity) replace existing hardcoded literals (e.g. `cornerRadius:20` at [DayCard.swift#L12](app-four/Views/Components/DayCard.swift#L12), stroke `4` in `TimelineBead`) — net reduction in ad-hoc values, justified by FR-018. |
| V. Solo Git Discipline | PASS | Feature branch `feat/daycard-update` off `main`; `/code-review` on the diff before merge; one revertable feature. |
| VI. On-Device Privacy | N-A | No transcription/NLP/storage-egress change. The one new attribute (`autoExpandOnSelection`) is a UI preference flag — no health/mood/medication content, nothing leaves the device. |
| VII. Deterministic Extraction | N-A | `NLNoteExtractor` and the lexicon are untouched; no extraction, eval-harness, or precision/recall surface is affected. |
| VIII. Service-Oriented Architecture | PASS | `MoodLibraryViewModel` stays `@MainActor @Observable` with no persistence logic; the filter compute is pure. `selectedDay` stays ephemeral `@State` in the view ([CalendarLibraryView.swift#L10](app-four/Views/Library/CalendarLibraryView.swift#L10)); the auto-expand preference is an `@AppStorage` flag read in the view (matching the `MedicationBar*` toggles), not a model dependency. No persistence logic enters the view-model. |
| IX. Pre-Release Data Posture | PASS | **No SwiftData schema change** — the auto-expand preference is `@AppStorage`, not a `@Model` attribute (matches the existing `MedicationBar*` toggles). The pre-release schema is untouched; no new `@Attribute(.unique)` or required (non-defaulted) attribute is introduced. (The pre-existing `AppSettings.id` `@Attribute(.unique)` is unrelated and unchanged by this feature.) |
| X. Test-First Development | PASS | Test-first applies to the logic units: `timelineDaysFilteredToSelectedDate(_:)` (days ≤ selected, selected at top, idempotent), folded-summary content (omit unlogged signals, most-recent medication only, empty-state copy), and fold/selection state transitions (header tap toggles independently; selecting collapses-all-then-opens-selected when auto-expand is on). RED before GREEN, using `@Test`/`#expect`. SwiftUI views (`DayCard`, `CalendarLibraryView`, `FoldedDayCardHeader`) are EXEMPT — verified by build + simulator run. |


**Post-Design Re-evaluation (after Phase 1)**: **PASS — unchanged.** The Phase 1 artifacts ([research.md](research.md), [data-model.md](data-model.md), [contracts/](contracts/)) introduce no new abstraction, no service, and no schema change (auto-expand is an `@AppStorage` flag). All visual values resolve to existing or additive design-system tokens (no raw literals). The Constitution Check above stands.

## Project Structure

### Documentation (this feature)

```text
specs/014-daily-card/
├── plan.md              # This file
├── research.md          # Phase 0 — grounded decisions (57)
├── data-model.md        # Phase 1 — entities & state
├── quickstart.md        # Phase 1 — simulator validation guide
├── contracts/           # Phase 1 — view/view-model interface contracts
│   ├── daycard-view.md
│   └── timeline-interaction.md
├── checklists/
│   └── requirements.md  # spec quality (16/16)
└── tasks.md             # Phase 2 — /speckit-tasks (NOT yet created)
```

## Structure Decision

**MODIFY**
- [app-four/Views/Components/DayCard.swift](app-four/Views/Components/DayCard.swift) — restructure to a constant header (circle + weekday) over a folded summary line that collapses on expand; add `@State isExpanded` + `@Environment(\.accessibilityReduceMotion)`; render conditional check-in rows only when expanded; fix `cornerRadius:20`→`Radius.card`, fixed `size:14` weekday→a Dynamic-Type Typography token; correct empty-state copy; combine the folded header for VoiceOver, enforce 44pt header hit-target.
- [app-four/Views/Library/CalendarLibraryView.swift](app-four/Views/Library/CalendarLibraryView.swift) — add `@State expandedCards = ExpandedDayCards()` (a small value type over `Set<Date>`) and `@AppStorage("autoExpandOnSelection")`; in `selectDay`/`scrollList` collapse-all then open the selected day when auto-expand is ON; iterate `viewModel.timelineDaysFilteredToSelectedDate(selectedDay)`; compute `isAboveSelection` per calendar cell; keep the existing `withAnimation(reduceMotion ? nil : Motion.smooth)` pattern.
- [app-four/ViewModels/MoodLibraryViewModel.swift](app-four/ViewModels/MoodLibraryViewModel.swift) — add pure `func timelineDaysFilteredToSelectedDate(_ selectedDate: Date) -> [TimelineDay]` layering a `dayStart <= selectedDate` predicate on the existing month filter; remains newest-first. No new observable property.
- [app-four/Views/Components/CalendarDayCell.swift](app-four/Views/Components/CalendarDayCell.swift) — remove the today ring (FR-013); de-emphasise days more recent than the selected date with reduced opacity **plus** a non-color cue (lighter weight / dropped marker dot) for greyscale survival (FR-011).
- [app-four/Views/Components/TimelineRow.swift](app-four/Views/Components/TimelineRow.swift) — host the expanded check-in layout (time-in-ring, mood word, energy/focus glyphs, chips); ensure the medication-phase ring's numeric % beneath is the redundant non-color readout (FR-020); apply Dynamic-Type Typography tokens.
- [app-four/Views/SettingsView.swift](app-four/Views/SettingsView.swift) — add the new `DayCardSettingsSection` (the user-facing auto-expand toggle). No `AppSettings`/`SettingsViewModel` change.
- [app-four/Views/Components/TimelineBead.swift](app-four/Views/Components/TimelineBead.swift) — replace hardcoded ring stroke (`4`) and bead/circle diameters with the new tokens (tokens-only, FR-018).

**CREATE**
- [app-four/Views/Components/FoldedDayCardHeader.swift](app-four/Views/Components/FoldedDayCardHeader.swift) — the always-visible header + one-line summary; computes the most-recent medication from `day.nodes` (newest-first), omits unlogged signals, renders the empty-state copy, and exposes the folded card as a single combined VoiceOver element reusing `signalAccessibilityLabel`.
- [app-four/Views/Library/ExpandedDayCards.swift](app-four/Views/Library/ExpandedDayCards.swift) — pure value type over `Set<Date>` (`toggling`, `selecting(_:autoExpand:)`, `contains`) — the test-first expand/selection state machine.
- [app-four/Views/Settings/DayCardSettingsSection.swift](app-four/Views/Settings/DayCardSettingsSection.swift) — the `@AppStorage("autoExpandOnSelection")` toggle row (mirrors `MedicationBarSettingsSection`).
- Design tokens (additive, tokens-only per FR-018): `Radius.chip = 15` ([Radius.swift](app-four/DesignSystem/Radius.swift)); `Spacing.ringStroke = 3.3` ([Spacing.swift](app-four/DesignSystem/Spacing.swift)); `Metrics.timeBead = 54`, `Metrics.headerMoodCircle = 58` ([Metrics.swift](app-four/DesignSystem/Metrics.swift)); `Opacity.swift` enum with `deEmphasis = 0.34`, `moodWash = 0.16`.

**TESTS (test-first, Swift Testing)**
- [app-fourTests/ViewModels/MoodLibraryViewModelTests.swift](app-fourTests/ViewModels/MoodLibraryViewModelTests.swift) — add filter-above cases.
- [app-fourTests/Views/FoldedDayCardHeaderTests.swift](app-fourTests/Views/FoldedDayCardHeaderTests.swift) (NEW) — summary-line content / most-recent-med / empty-copy.
- [app-fourTests/Views/DayCardExpandStateTests.swift](app-fourTests/Views/DayCardExpandStateTests.swift) (NEW) — independent toggle + collapse-all-then-open-selected.

**No new DesignSystem motion tokens, no new model types, no new services.**

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|---|---|---|
| None — no Constitution deviations | — | The pre-existing `@Attribute(.unique)` on `AppSettings.id` ([AppSettings.swift#L7](app-four/Models/AppSettings.swift#L7)) is a standing Principle-IX item this feature neither introduces nor modifies; the one new attribute is defaulted and CloudKit-compatible, so no new entry is warranted. |

