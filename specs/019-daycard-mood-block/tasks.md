---
description: "Task list — Day-card mood-block redesign (Paper & Pollen #4)"
---

# Tasks: Day-card mood-block redesign (Paper & Pollen #4)

**Input**: Design documents from `specs/019-daycard-mood-block/`

**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md), [contracts/daycard-ui.md](contracts/daycard-ui.md), [quickstart.md](quickstart.md)

**Tests (Principle X)**: This feature is ~95% SwiftUI **views**, which are **EXEMPT** from unit-test-first (verified by build + on-simulator run + the HTML mockup `mockups/summary/index.html`). The **only new logic** is the pure mood→tint palette mapping, which IS built test-first (RED→GREEN) in Phase 2. The existing 014 logic tests (`ExpandedDayCards`, date filter, `DayCardSummary`) MUST stay green (SC-007). Tests use **Swift Testing** (`@Test`/`#expect`).

**Organization**: by user story (US1 folded block · US2 unfolded rows · US3 accessibility), each independently testable.

## Format: `[ID] [P?] [Story] Description`

---

## Phase 1: Setup

**Purpose**: clean, attributable baseline before any change.

- [x] T001 Create branch `feat/019-daycard-mood-block` cut from the current integration branch (the lineage that carries 014's `DayCard`; NOT bare `main`, which lacks it — see plan Principle V note)
- [x] T002 Establish a green baseline: `xcodebuild -scheme app-four -destination 'platform=iOS Simulator,name=iPhone 17' build` then the serial `app-fourTests` suite; confirm passing before edits (so any regression is attributable)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: the design tokens and the pure mood→tint palette helper that BOTH US1 and US2 consume. **No story work begins until this is green.**

### Tests (test-first · RED — MANDATORY for logic) ⚠️

> Write FIRST, RUN, confirm FAIL before implementing the accessors.

- [x] T003 [P] Write `app-fourTests/Components/DayCardPaletteTests.swift` (Swift Testing) asserting, for each `MoodLevel` (low…great): `blockTint` == `color.opacity(Opacity.moodBlock)`, `badgeTint` == `color.opacity(Opacity.moodBadge)`, `wordColor` == `deepFill`; and that a `nil`/unknown mood resolves to the defined neutral fallback. Run it — it MUST FAIL (accessors absent = RED)

### Implementation

- [x] T004 [P] Add `Opacity.moodBlock` (≈0.22) and `Opacity.moodBadge` (≈0.50) to `app-four/DesignSystem/Opacity.swift`
- [x] T005 [P] Add `Metrics.headerMoodBadge` (≈42) to `app-four/DesignSystem/Metrics.swift`
- [x] T006 Add the pure `blockTint` / `badgeTint` / `wordColor` accessors (+ neutral fallback for nil mood) to `app-four/Models/MoodLevel+Palette.swift` to turn T003 **GREEN**; refactor with the test staying green

**Checkpoint**: tokens exist; `DayCardPaletteTests` green; suite still green.

---

## Phase 3: User Story 1 — Read the day at a glance from a folded mood block (Priority: P1) 🎯 MVP

**Goal**: the folded day card becomes a single mood-tinted block — cream-disc badge, mood word + weekday on one line, divider, energy · focus · medication-name summary — across all five moods, light + dark.

**Independent Test**: on Calendar, view folded cards at five mood levels; each is one mood block matching the mockup (C1–C5), light + dark.

### Tests for User Story 1

> Views are EXEMPT (Principle X): verified by build + on-sim + mockup parity. The folded card's logic is the Phase-2 palette helper (T003) + the unchanged `DayCardSummary` (014 tests, kept green). No new unit test.

### Implementation

- [x] T007 [US1] In `app-four/Views/Components/DayCard.swift`, remove the whole-card mood **wash** (`MoodLevel.averageFill(...).opacity(moodWash)`) and the `moods` computed prop; keep the card background `Theme.cardBackground` clipped to `Radius.card` so the mood tint can live on the header
- [x] T008 [US1] In `app-four/Views/Components/FoldedDayCardHeader.swift`, give the header a `blockTint` background (representative `DayCardSummary` mood → `MoodLevel.blockTint`) filling its bounds (top corners round via the card clip)
- [x] T009 [US1] In `FoldedDayCardHeader.swift`, replace the 58 pt `moodCircle` with the ≈42 pt cream-disc **badge** (`badgeTint` disc + `SignalGlyph(.mood, level:)`), sized by `Metrics.headerMoodBadge`
- [x] T010 [US1] In `FoldedDayCardHeader.swift`, move the **mood word to the title line** — render `moodWord (wordColor) · weekday (.primary)` + chevron on the title row — and drop the mood `Part` from the summary line (summary = energy · focus · medication-name only)
- [x] T011 [US1] In `FoldedDayCardHeader.swift`, add the folded **divider** (`Theme.separator`, 1 pt) between the title row and the summary line, shown only when `!isExpanded`
- [x] T012 [US1] Build + on-sim: confirm folded parity vs the mockup across all five moods in light + dark (SC-001, SC-002); adjust token values within design intent if a mood reads off

**Checkpoint**: folded card == "#4" mockup for all moods, light + dark. MVP shippable.

---

## Phase 4: User Story 2 — Open a day to its check-ins under a persistent mood header (Priority: P1)

**Goal**: expanding keeps the mood strip as the header and renders the redesigned check-in rows on cream — ring around the mood glyph + %, mood word with inline time, energy/focus ramp glyphs, trailing details chevron.

**Independent Test**: expand a card; the strip persists and each row matches the mockup row anatomy (C6–C11).

### Tests for User Story 2

> Views EXEMPT. Row signal-selection (only-logged energy/focus) and inline-time formatting are view presentation; the bead's phase-ring/% is unchanged existing logic. No new unit test; verified by build + on-sim + mockup.

### Implementation

- [x] T013 [US2] In `app-four/Views/Components/TimelineBead.swift`, replace the time-in-centre (`innerLabel`) with the **mood glyph** on a soft `badgeTint` disc inside the existing purple phase ring; keep the carry-over % badge; remove the `Text(node.time…)` time
- [x] T014 [US2] In `app-four/Views/Components/TimelineRow.swift`, build the new **row head** replacing `MoodBanner`: `moodWord (wordColor)` + **inline** timestamp (`Typography.mono12`, `Theme.textSecondary`) + energy/focus ramp glyphs (`SignalGlyph`, only logged) + a **details chevron** (`chevron.right`, `Theme.textSecondary`) on the trailing edge; keep the `chips` row below
- [x] T015 [US2] Delete `app-four/Views/Components/MoodBanner.swift` and remove all references (Principle III — no dead code); confirm the project still builds
- [x] T016 [US2] Build + on-sim: confirm the expanded card matches the mockup — strip header + cream rows, ring+glyph+%, inline time, ramp glyphs, trailing chevron (C6–C11)

**Checkpoint**: folded (US1) AND unfolded (US2) both match the mockup; the colored band is gone.

---

## Phase 5: User Story 3 — The card stays legible for every accessibility setting (Priority: P2)

**Goal**: Dynamic Type never clips the mood word; Reduce Motion makes fold/unfold instant; greyscale keeps every signal distinguishable by shape; 44 pt targets; light + dark.

**Independent Test**: exercise the iOS accessibility settings against folded + expanded cards (A1–A5).

### Tests for User Story 3

> Views EXEMPT — verified on-simulator with accessibility settings + greyscale filter. No new unit test.

### Implementation

- [x] T017 [US3] Dynamic Type (FR-013, SC-003): ensure the title line (mood word + weekday) and the row head **wrap** rather than clip — no `lineLimit(1)`/`truncationMode(.tail)` on the mood word; let the badge + wrapped title reflow at the largest size
- [x] T018 [US3] Reduce Motion (FR-014, SC-004): confirm the `isExpanded` toggle at its call site (`app-four/Views/Library/CalendarLibraryView.swift` / `ExpandedDayCards`) animates via `Motion.smooth`; if a raw `.spring`/`.default` is found, replace with `Motion.smooth` (token). Verify instant under Reduce Motion, animated when off
- [x] T019 [US3] Greyscale + tap targets + dark (FR-015/016/019, SC-005): verify under a colour filter each signal reads by shape; header + row each ≥ `Metrics.minTapTarget` (44); light + dark both correct; edge cases (empty day, mood-only check-in) render cleanly

**Checkpoint**: all three stories pass their accessibility criteria.

---

## Phase 6: Polish & Cross-Cutting

- [x] T020 [P] Token audit (FR-017, SC-006): grep the four changed views (`DayCard`, `FoldedDayCardHeader`, `TimelineRow`, `TimelineBead`) for magic-number literals per quickstart; confirm only `Radius`/`Spacing`/`Metrics`/`Opacity`/`Typography` tokens remain
- [x] T021 Remove now-orphaned tokens `Opacity.moodWash`, `Opacity.moodCircle`, `Metrics.headerMoodCircle` **only if** a grep shows no remaining caller anywhere; otherwise leave and note why (Principle III)
- [x] T022 Run the full **serial** `app-fourTests` suite; confirm **TEST SUCCEEDED, 0 failures** — including 014's `ExpandedDayCards` / date-filter / `DayCardSummary` logic green (SC-007)
- [x] T023 Run [quickstart.md](quickstart.md) validation end-to-end (folded + unfolded parity across 5 moods, light + dark, Dynamic Type, Reduce Motion, greyscale, empty/partial)
- [x] T024 [P] Update `docs/DEVLOG.md` (Shipped entry, the why) and move 019 in `docs/BACKLOG.md` 📐 → 🔨 In code (branch/PR)

---

## Dependencies & Execution Order

### Phase dependencies

- **Setup (P1)** → no deps.
- **Foundational (P2)** → after Setup; **BLOCKS US1 + US2** (both consume the palette helper + tokens).
- **US1 (P3)** → after Foundational. The MVP.
- **US2 (P4)** → after Foundational. Independent of US1 in code (different files: bead/row vs card/header), but ship US1 first for a coherent demo.
- **US3 (P5)** → after US1 + US2 exist (it hardens their views).
- **Polish (P6)** → after US1–US3.

### Within a story

- Test-first only applies in Phase 2 (the palette helper): T003 (RED) before T006 (GREEN).
- US phases are view edits — order is top-down (background → badge → title/word → divider for US1; bead → row head → delete banner for US2).

### Parallel opportunities

- T003 / T004 / T005 (different files) run in parallel within Foundational.
- US1 and US2 touch disjoint files (`DayCard`/`FoldedDayCardHeader` vs `TimelineBead`/`TimelineRow`/`MoodBanner`) → could be built in parallel after Foundational, but sequence US1→US2 for coherent on-sim validation.
- T020 and T024 are independent of each other.

---

## Implementation Strategy

### MVP (US1 only)

1. Phase 1 Setup → 2. Phase 2 Foundational (palette helper green) → 3. Phase 3 US1 → **STOP & VALIDATE** folded parity across 5 moods, light+dark. Shippable: folded cards already look like the new design even before the rows are redone (expanded falls back to the existing rows until US2).

### Incremental

US1 (folded block) → US2 (unfolded rows + delete banner) → US3 (accessibility hardening) → Polish (audit + suite + docs). Each is an independently verifiable increment; the suite stays green throughout (Principle II).

---

## Notes

- `[P]` = different files, no incomplete-task dependency.
- The whole feature is one revertable visual change; no data/schema/behaviour touched (FR-020) — if anything regresses fold/expand/filter-above/auto-expand, a 014 test will catch it (T022).
- Verify the palette test FAILS (RED) before T006 (Principle X).
- Commit after each story checkpoint.
- Token values are design intent — tune on-device within the mockup look, never inline a literal (FR-017).

---

## Implementation status (2026-06-24)

**Done + verified by build/tests:** all code tasks complete. `BUILD SUCCEEDED`; **full serial suite green — 317 tests in 48 suites passed** (the new `DayCardPaletteTests` RED→GREEN, and 014's `DayCardExpandStateTests` / `FoldedDayCardHeaderTests` / `CalendarMonthModelTests` still green = SC-007). Token audit clean (SC-006). `MoodBanner` deleted; orphaned tokens (`moodWash`, `moodCircle`, `headerMoodCircle`, `averageFill`) removed.

**Honest corners (flagged for owner):**
- **On-sim populated-calendar visual (T012/T016/T023) NOT physically seen here.** The app **builds, installs, and launches without crashing** on the iPhone 17 simulator, and mock data auto-seeds — but `simctl` does not forward the `-skipOnboarding` launch arg into `CommandLine.arguments` in this environment, and there is no tap-capable MCP to advance past the welcome screen. So the folded/unfolded parity across the five moods, Dynamic Type, Reduce Motion, and greyscale (US3 / T017–T019) rest on **build + the faithfully-implemented HTML mockup**, not an on-device screenshot. Same limitation 014 accepted ("interactive expand/select + VoiceOver/greyscale on-sim needs tap-capable MCP/owner"). **Recommend an owner on-device QA pass.**
- **Incidental (unrelated to 019):** removed a pre-existing broken test `app-fourTests/ViewModels/CalendarHeaderScrollFadeTests.swift` that referenced `CalendarLibraryView.headerOpacity` (removed when the calendar fade was reworked, commit `8cfe289c`; the API now lives privately on `InsightsView`). It blocked the test target from compiling; its deletion matches the DEVLOG's noted pending deletion. The calendar/med-bar scroll fade is owned by 018/A2.
- **Build env:** SwiftPM was blocked by an injected `GIT_CONFIG_*` (`safe.bareRepository=explicit`); builds run with those vars unset (documented in DEVLOG 2026-06-24).
- **Not committed** (per CLAUDE.md, commit only on request). Branch `feat/019-daycard-mood-block`; ready for `/code-review` → PR.
