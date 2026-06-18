# Tasks: Paper & Pollen signal glyphs

**Input**: Design documents from `/specs/006-signal-glyphs/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/signal-glyph.md

**Tests**: Per Constitution **Principle X**, logic is test-first (RED→GREEN). The only *logic* in this feature is three pure helpers (clamp · a11y label · synonym) — they carry the **RED checkpoint in Phase 2**. The glyph `Shape`/`View` drawing and the call-site swaps are **SwiftUI views → exempt**, verified by build + on-simulator run (each story has a build+run verification task as its independent test).

**Organization**: by user story (US1–US4) for independent delivery.

## Format: `[ID] [P?] [Story] Description`
- **[P]**: parallelizable (different files, no incomplete deps)
- Paths are repo-relative; app target = `app-four/`, tests = `app-fourTests/`

---

## Phase 1: Setup

- [X] T001 Create `app-four/DesignSystem/Glyphs/` folder for the five glyph views.
- [X] T002 [P] Add `Palette.sleepIndigo` token (`#5566A6` light / `#8090C8` dark) in app-four/DesignSystem/Palette+Signals.swift.
- [X] T003 [P] Add `SignalKind` enum (`mood`/`energy`/`focus`/`sleep`/`medication`) + the static per-signal names/synonyms table (from data-model.md) in app-four/DesignSystem/SignalKind.swift.

---

## Phase 2: Foundational (BLOCKING — the glyph engine + test-first helpers)

**Purpose**: the rendering engine every user story consumes. No story can start until this is green.

### Tests first (RED) — Principle X

- [X] T004 [P] Write FAILING Swift Testing tests for `clampedSignalLevel(_:)` in app-fourTests/SignalGlyphTests.swift (nil→nil · 0→1 · 6→5 · 3→3). Confirm RED.
- [X] T005 [P] Write FAILING tests for `signalAccessibilityLabel(_:level:)` in app-fourTests/SignalGlyphTests.swift (`.energy` lvl 4 → "Energy: Alert, 4 of 5" · `.sleep` → "Sleep" · nil level → no "of 5"). Confirm RED.
- [X] T006 [P] Write FAILING tests for `signalSynonym(_:level:)` in app-fourTests/SignalGlyphTests.swift (`.mood` 5 → "bright, thriving" · `.focus` 1 → "hazy"). Confirm RED.

**🔴 RED checkpoint**: T004–T006 must fail before proceeding.

### Implement helpers (GREEN)

- [X] T007 Implement `clampedSignalLevel`, `signalAccessibilityLabel`, `signalSynonym` to pass T004–T006 in app-four/DesignSystem/SignalKind.swift. Confirm GREEN.

### Glyph views (SwiftUI — exempt, build+sim) — geometry ported verbatim from the approved register

- [X] T008 [P] Implement `SproutGlyph(level:color:)` (Mood, port of `gMood`) in app-four/DesignSystem/Glyphs/SproutGlyph.swift.
- [X] T009 [P] Implement `BoltGlyph(level:color:)` (Energy, port of `gEnergy`) in app-four/DesignSystem/Glyphs/BoltGlyph.swift.
- [X] T010 [P] Implement `ApertureGlyph(level:color:)` (Focus, port of `gFocus` — dashed ring low → rings + core high) in app-four/DesignSystem/Glyphs/ApertureGlyph.swift.
- [X] T011 [P] Implement `BedIcon(color:)` (Sleep, single) in app-four/DesignSystem/Glyphs/BedIcon.swift.
- [X] T012 [P] Implement `CapsuleGlyph(color:)` (Medication, horizontal two-tone) in app-four/DesignSystem/Glyphs/CapsuleGlyph.swift.
- [X] T013 Implement `SignalGlyph(_:level:size:decorative:)` dispatcher (per contracts/signal-glyph.md) — routes kind→glyph, resolves color from `SignalLevel`/`Palette`, applies a11y label via T007 helpers, empty state for nil, clamp for out-of-range — in app-four/DesignSystem/SignalGlyph.swift.
- [X] T014 Build + run: add a `#Preview` gallery (5 signals × levels, light+dark) and confirm visual parity with [design-decisions-ALL.html](../../docs/superpowers/plans/2026-06-16-design-decisions-ALL.html).

---

## Phase 3: User Story 1 — Timeline glyphs (Priority: P1) 🎯 MVP

**Goal**: signals read as the Paper & Pollen glyphs in the Calendar timeline + detail-summary surfaces.
**Independent test**: open Calendar on a day with check-ins → every signal is a custom glyph (no SF Symbol); a high-level entry differs in shape from a low one; a dose shows the horizontal capsule chip.

- [X] T015 [US1] Swap signal `Image(systemName:)` → `SignalGlyph` in app-four/Models/Recording+MoodDisplay.swift (DisplayTag; `decorative: true` where the tag already carries the word).
- [X] T016 [P] [US1] Swap in app-four/Views/Components/TimelineChip.swift.
- [X] T017 [P] [US1] Swap sparkles/bolt/target in app-four/Views/Components/MoodBanner.swift.
- [X] T018 [P] [US1] Swap in app-four/Views/Components/SummaryCard.swift.
- [X] T019 [P] [US1] Swap StateBadge icons in app-four/Views/Components/ADHDSummarySection.swift.
- [X] T020 [US1] Build + run on iPhone 17 sim; verify the US1 independent test above (timeline + detail summary).

**Checkpoint**: US1 deliverable on its own — the identity win in the primary read surface.

---

## Phase 4: User Story 2 — Signal picker (Priority: P1)

**Goal**: tap a 1→5 glyph row to set/correct Mood/Energy/Focus; current ringed in accent + name/synonym label.
**Independent test**: open the Edit sheet, tap level 2 then 5 on Mood → ring moves, glyph form changes, label reads "5 · Great — bright, thriving".

- [X] T021 [US2] Build the reusable picker row: 5× `SignalGlyph` + accent ring on the current level + label using `signalSynonym` (T007) — app-four/Views/Components/SignalPicker.swift.
- [X] T022 [US2] Wire `SignalPicker` into app-four/Views/CheckIn/TextCheckInComposer.swift (Type-note, Layout A — signals first).
- [X] T023 [US2] Wire `SignalPicker` into app-four/Views/ExtractionReviewView.swift (Edit sheet Mood/Energy/Focus rows, named level + synonym).
- [X] T024 [P] [US2] Swap any remaining signal SF Symbols in app-four/Views/CheckIn/CheckInView.swift.
- [X] T025 [US2] Build + run; verify the US2 independent test (ring + form + label update on tap).

---

## Phase 5: User Story 3 — Insights ramps (Priority: P2)

**Goal**: Insights signals section shows each dimension's glyph 1→5; Sleep "not tracked yet".
**Independent test**: open Insights → signals; Mood/Energy/Focus render ascending glyph ramps, Sleep shows the bed icon + deferred label.

- [X] T026 [P] [US3] Swap in app-four/Views/Insights/SignalStripsView.swift (the glyph ramps).
- [X] T027 [P] [US3] Swap in app-four/Views/Insights/SignalAverageGauges.swift.
- [X] T028 [P] [US3] Swap in app-four/Views/Insights/DailyRhythmMatrix.swift.
- [X] T029 [P] [US3] Repoint icon refs in app-four/ViewModels/InsightsViewModel+Signals.swift.
- [X] T030 [US3] Build + run; verify the US3 independent test (ramps + Sleep deferred).

---

## Phase 6: User Story 4 — Accessibility & legibility (Priority: P2)

**Goal**: every glyph distinct by shape in grayscale, legible across sizes, VoiceOver-labeled, correct in dark.
**Independent test**: grayscale + AX-XXL + VoiceOver → levels distinct, nothing clips, "Energy, Alert, 4 of 5" announced.

- [X] T031 [US4] Audit `decorative:` vs labeled `SignalGlyph` usages across all migrated sites; standalone glyphs carry the a11y label, in-row glyphs are `decorative: true` (no double-read).
- [X] T032 [US4] **Grayscale gate (SC-001):** on Insights ramps + timeline at ~22px, confirm every adjacent level pair is distinguishable by shape+fill. **If any pair fails, STOP and raise to owner** (research D8); record the result in quickstart.md.
- [X] T033 [US4] Verify Dynamic Type AX-XXL (no clipping), VoiceOver announcements, and dark-mode rendering across all surfaces.

---

## Phase 7: Polish & cross-cutting

- [X] T034 Remove/repoint the dead signal SF Symbol constants (`energy`, `medication`) in app-four/DesignSystem/Icons.swift — no dead code (Principle III).
- [X] T035 `grep` the migration surface to confirm **zero SF Symbols remain** for the five signals (SC-003).
- [X] T036 [P] Update docs/DEVLOG.md (Shipped) + docs/BACKLOG.md (glyph item → 🔨 In code / ✅).
- [X] T037 Run the full Swift Testing suite serially (green) + `/code-review` the diff before opening the PR.

---

## Dependencies & order

- **Phase 1 → Phase 2** (foundational engine + RED→GREEN helpers) **blocks all stories.**
- **US1 / US2 / US3** are independent call-site migrations after Phase 2 (any order). US2's picker (T021) depends on T007 (synonym) + T013 (SignalGlyph).
- **US4** depends on US1–US3 being migrated (it audits/verifies them).
- **Phase 7** last.

## Parallel opportunities

- Glyph views **T008–T012** all `[P]` (separate files).
- Within each story, the per-file swaps marked `[P]` run together (T016–T019; T026–T029).

## Implementation strategy

- **MVP = Phase 1 + Phase 2 + US1** — the engine plus the timeline migration delivers the identity win standalone.
- Then layer US2 (pickers) → US3 (Insights) → US4 (a11y verification) → Polish. Each story builds + runs green before the next.
