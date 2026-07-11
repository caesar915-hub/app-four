---
description: "Task list — Spec 032 New Look Screens"
---

# Tasks: New Look Screens — Edit Check-in & Recording Detail Re-skin

**Input**: Design documents from `specs/032-newlook-screens/`
**Prerequisites**: plan.md, spec.md, research.md (D1–D5), data-model.md, contracts/newlook-tokens.md, quickstart.md
**Worktree / branch**: `~/Projects/app-four-spm` on `feat/032-newlook-screens`

**Tests**: This feature is a **pure visual re-skin — no logic changes** (D5). Per Constitution
Principle X, test-first applies to *logic* (models/services/view-models/NLP); **SwiftUI views are
EXEMPT** (verified by build + on-device run). No VM/service/model code changes → **no new RED
tests**. The two existing Swift Testing suites (`ExtractionReviewViewModelTests`,
`RecordingDetailViewModelTests`) are the **behavior regression gate**: they MUST remain unedited
and stay green (SC-002). Writing a RED test for a token swap would be theater and is explicitly
not done here.

**Organization**: by user story. US0 (Foundational) blocks US1 & US2; US1 & US2 are then
independent; US3 is GATED (spec-029).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: different file, no dependency on an incomplete task → parallelizable
- **[Story]**: US0 (Foundational) / US1 / US2 / US3
- Paths are repo-relative to the `app-four-spm` worktree root

---

## Phase 1: Setup

**Purpose**: Confirm a clean, green baseline before any change.

- [ ] T001 Confirm baseline: `swift build --package-path Packages/SquirlDesignSystem` and the full app suite are GREEN on `feat/032-newlook-screens` (via ios-debugger-agent / XcodeBuildMCP) — record the pass so any later red is attributable to this feature (Constitution II).

**Checkpoint**: baseline green.

---

## Phase 2: Foundational — US0 tokens (BLOCKS US1 & US2)

**Purpose**: The `NewLook` token set + card/chip/nav grammar every screen binds to (research D1/D3/D4).

**⚠️ CRITICAL**: US1 and US2 cannot start until this phase is complete.

- [ ] T002 [US0] Add `Radius.newLookCard = 20` to `Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/Radius.swift` (keep `card = 16` unchanged); doc-comment it as the New Look card radius.
- [ ] T003 [P] [US0] Create `Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/NewLook.swift` — `public enum NewLook` with the six adaptive color tokens per data-model.md (`screen`, `card`, `inkPrimary`, `inkSecondary`, `hairline`, `selection`), each `Color(lightHex:darkHex:)` using the D3 light+dark hexes. Do NOT redefine medication (reuse `Palette.medication`). No `ALL_SCOPES`-equivalent leakage — these are additive, `Theme`/`Palette` untouched.
- [ ] T004 [US0] In `NewLook.swift`, add the `.newLookCard(padding:)` `View` extension (fill `NewLook.card`, `Radius.newLookCard`, soft shadow, **no border**) — mirror `.card()` in `Card.swift` but borderless + radius 20. Leave the `.card()` **definition** unchanged. Note: US2 migrates 2 of the 4 `.card()`-consuming files (RecordingDetailView, ADHDSummarySection) to `.newLookCard()`; the **2 remaining P&P consumers — `RecordingRow` and `MedicationBarView` — are the ones kept unaffected** (FR-011).
- [ ] T005 [US0] In `NewLook.swift`, add the chip/pill grammar: a `newLookChip(selected:role:)` style (or small view) — unselected = `NewLook.card` fill + `NewLook.hairline` 1px border + `inkPrimary` label; selected = solid `NewLook.selection` (or `Palette.medication` when `role == .medication`) + white label. Add `enum NewLookChipRole { case standard, medication }`.
- [ ] T006 [US0] In `NewLook.swift`, add a nav-row helper (back pill · centered title · Save/trailing pill) that centers the title on the screen axis independent of pill widths (ZStack/overlay), per contract C2.
- [ ] T007 [US0] Build the design package (`swift build --package-path Packages/SquirlDesignSystem`) — must compile clean; confirm `Theme`, `Palette`, `Typography`, `.card()` are byte-unchanged (`git diff` on those files empty except `Radius.swift`).
- [ ] T008 [P] [US0] Amend `DESIGN.md` — add a "New Look" section (palette + `newLookCard` radius, card/chip/nav grammar, and which screens use New Look vs Paper & Pollen, noting the accepted mixed-look transition). FR-007.

**Checkpoint**: `NewLook.*`, `.newLookCard()`, chip/nav grammar exist and compile; no visual change anywhere yet; P&P tokens untouched.

---

## Phase 3: US1 — a03 Edit check-in (Priority: P1) 🎯 MVP

**Goal**: `ExtractionReviewView` renders as Figma a03 (`308:1654`) in the New Look — sage screen,
white radius-20 borderless cards, centered nav title between back/Save pills, bold sentence-case
headers, hairline chips with solid selection-green / medication-purple selected states — with
identical behavior.

**Independent Test**: Open Edit check-in on device, compare against a03, exercise every selector +
Save/Cancel; visual parity, zero behavior change; `ExtractionReviewViewModelTests` green.

**Files**: `app-four/Views/ExtractionReviewView.swift`, `app-four/Views/Components/Chip.swift`
(US1-only consumer), `app-four/Views/Components/GlyphRampPicker.swift` (SHARED — see T012).

> No RED tests (view re-skin, D5). Regression gate below.

- [ ] T009 [US1] Restructure `ExtractionReviewView` body from the spec-008 hairline-`field` scaffold to New Look **cards**: replace the `field`/`Divider` scaffold and `numberedHeader` (mono "01".."08" + `cardEyebrow`) with `.newLookCard()` sections and **bold sentence-case headers** (`Typography.headline`) per a03. Set screen background to `NewLook.screen`, 16px gutter (`Spacing.l`), inks to `NewLook.inkPrimary/inkSecondary`.
- [ ] T010 [US1] Group Mood + Energy + Focus into a single **"Signals"** card (a03 groups the three ramps under one header) — keep the three `GlyphRampPicker`s and their bindings unchanged; only the surrounding header/card structure changes. Re-express the per-ramp **group eyebrows** (MOOD/ENERGY/FOCUS) and the Emotions sub-group labels (PLEASANT/UNPLEASANT) as uppercase tracked micro-labels (`Typography.label`) per contract C5 — the numbered `cardEyebrow` scaffold removed in T009 must be intentionally re-expressed here, not dropped.
- [ ] T011 [US1] Replace the custom `NavigationStack` toolbar (Cancel / Save items) with the New Look nav-row grammar (T006): back/Cancel pill left, **centered "Edit check-in" title**, Save pill right; preserve `viewModel.cancel()`/`save()` actions and `dismiss()` exactly (C9, FR-005). Also decide the disposition of the **in-body "Save corrections" button** (`ExtractionReviewView.swift:44-46`, `.buttonStyle(.primary)` — a second P&P-styled Save affordance): a03 has a single nav Save, so **remove the body button** (preferred) or restyle it to New Look — do not leave a P&P primary button on the New Look screen.
- [ ] T012 [US1] Handle `GlyphRampPicker` WITHOUT bleeding into the Check-in screen (it is shared with `TextCheckInComposer`, FR-011): pass a New-Look style/tint via a parameter (default stays Paper & Pollen) — do NOT mutate the picker's shared default. **The selected ring is hardcoded `Theme.accent` bronze (`GlyphRampPicker.swift:22`); since a03's chips use selection-green, parameterizing the ring to `NewLook.selection` is REQUIRED (not optional) — a bronze ring beside green chips on the same screen is a mismatch.** Glyph shapes stay unchanged (FR-008). Verify `TextCheckInComposer` renders identically (default path).
- [ ] T013 [US1] Re-skin the chips to New Look: `segPill` (sleep) and the medication `dosePill`/`medGrid` chips move from `tint.opacity(0.16/0.18)` fills to the T005 grammar — solid `NewLook.selection` + white label when selected (standard), solid `Palette.medication` + white when a medication/dose chip; unselected = white + `NewLook.hairline`. Update `Chip.filter` (emotions/side-effects, US1-only) to the same treatment — **note: this edits the shared `Chip.swift`, so any future `Chip.filter` consumer inherits the New Look styling; keep the change behind the same selected/role logic so it degrades sensibly.**
- [ ] T014 [US1] Apply the **bold sentence-case header STYLE** to the card headers (Medications / Emotions / Side effects, etc.) — copy is already correct in `ExtractionReviewView` ("Side effects" is already lowercase at L446), so this is a style change only, no rename. (The one real casing fix, "Side Effects" → "Side effects", lives in `ADHDSummarySection` under T018.)
- [ ] T015 [US1] Style audit of `ExtractionReviewView.swift` + touched components: zero hardcoded color/radius/shadow — all via `NewLook.*`/`Palette.*`/`Radius.*`/`Spacing.*` (FR-006, SC-003). **Also confirm no P&P button style (`.buttonStyle(.primary/.secondary)`) survives on the New Look screen** (the grep for literals won't catch a button style — check by hand). Grep from quickstart.md.
- [ ] T016 [US1] Build + run full suite; confirm `ExtractionReviewViewModelTests` UNCHANGED and GREEN (regression gate, SC-002). Owner device QA vs a03 in light + dark, default + an accessibility text size (C1–C9, X2). **Confirm the type hierarchy matches a03's Inter ramp mapped to SF (FR-004) and that the edit→save round trip needs the same tap count as the pre-reskin flow (SC-005).**

**Checkpoint**: Edit check-in is New Look, behavior unchanged, suite green — MVP shippable.

---

## Phase 4: US2 — a02 Recording detail (Priority: P2)

**Goal**: `RecordingDetailView` + `ADHDSummarySection` render as Figma a02 (`308:1594`) — signal
hero strip, New Look info cards, audio card, delete row — behavior unchanged.

**Independent Test**: Open a recording detail on device, compare against a02, play audio / edit /
delete; visual parity, zero behavior change; `RecordingDetailViewModelTests` green.

**Files**: `app-four/Views/RecordingDetailView.swift`,
`app-four/Views/Components/ADHDSummarySection.swift` (used ONLY by this screen — safe to re-skin).

> No RED tests (view re-skin, D5). Regression gate below.

- [ ] T017 [P] [US2] Re-skin `RecordingDetailView` shell: background `NewLook.screen`, 16px gutter, inks to `NewLook.*`; `transcriptSection` and `audioCard` from `.card()` → `.newLookCard()`; `cardEyebrow` → bold sentence-case header style per a02. Restyle the **audio card internals per contract C14**: play control tinted `Palette.medication`, progress track, mono duration label (`AudioPlayerView` — restyle in place or via a New Look param, don't mutate a shared default it may have). **Decide the `.medicationBarOverlay()` (`RecordingDetailView.swift:39`) explicitly**: its card is `.card()` (P&P) and sits inside the re-skinned a02 — either leave it P&P as an accepted **within-screen seam** (state this in the checkpoint) or scope it to New Look; do not leave it silent.
- [ ] T018 [P] [US2] Re-skin `ADHDSummarySection` info cards (Medications, Sleep, Emotions, Side effects) from `.card()` → `.newLookCard()` with bold sentence-case headers + leading icons per a02 C12; fix the "Side Effects" casing to "Side effects" (a03/a02 consistency). Depends on US0 only; independent of T017's file.
- [ ] T019 [US2] Build the **signal hero strip** (a02 C11): upgrade `signalGlyphRow`/`glyphSummaryItem` from glyph+label to three equal columns — glyph · **level word** (`Typography.headline`) · uppercase micro-label · **level bar** — matching a02. Reuse existing `SignalGlyph` (shapes unchanged, FR-008).
- [ ] T020 [US2] Nav + edit/delete: keep the existing pencil-edit entry and `.confirmationDialog` delete flow **unchanged**; restyle the pencil button + delete row to New Look (delete row keeps `Theme.danger` — warm clay, C15). Verify the `onDisappear` pendingDelete pattern is untouched (crash-safety).
- [ ] T021 [US2] Style-literal audit of `RecordingDetailView.swift` + `ADHDSummarySection.swift`: zero hardcoded color/radius/shadow (FR-006, SC-003).
- [ ] T022 [US2] Build + run full suite; confirm `RecordingDetailViewModelTests` UNCHANGED and GREEN. Owner device QA vs a02 in light + dark, default + accessibility size; long-transcript wrap check; **type hierarchy matches a02's Inter ramp mapped to SF (FR-004)** (C10–C17, X2, X3).

**Checkpoint**: both screens New Look, both suites green — US0+US1+US2 = the PR.

---

## Phase 5: US3 — a01 Calendar timeline (Priority: P3) — 🚫 GATED, NOT IN THIS PR

**Goal**: Calendar day timeline → New Look per Figma a01 (`308:1930`).

**⚠️ GATE (FR-012)**: Do **not** start until spec-029 (`feat/029-calendar-day-context`) is merged
or abandoned — US3 rewrites the same calendar views 029 modifies. Ships in a separate follow-up PR.

- [ ] T023 [US3] **BLOCKED** — resolve the 029 gate first (merge or abandon `feat/029-calendar-day-context`), then rebase/branch and plan a01 timeline tasks (band header, entry rows with glyph column + chips, med bar, folded summary) reusing the US0 grammar. No work until the gate opens.

---

## Phase 6: Polish & Cross-Cutting (before PR)

- [ ] T024 Cross-screen consistency pass: card radius/shadow, chip selected/unselected, header style, and 16px gutter are identical on a03 and a02 (spacing on the 4/8/12/16/20/24 grid — swiftui-design-principles).
- [ ] T025 Isolation check: spot-check non-target screens unchanged — Calendar, Insights, Settings, the **Check-in composer** (`TextCheckInComposer`, shares `GlyphRampPicker`), the **mascot tab bar / `RootTabView` / status-bar chrome** (FR-011 names these explicitly), and the **2 remaining P&P `.card()` consumers** (`RecordingRow`, `MedicationBarView`) render exactly as before; app-wide mixed look is expected (FR-010/FR-011, X4).
- [ ] T026 Accessibility pass on both re-skinned screens: Dynamic Type to an accessibility size (no clip/overlap; chips wrap), VoiceOver labels intact on chips/nav/delete, contrast holds in light + dark (swift-accessibility; SC-004).
- [ ] T027 Full suite green on branch + final `git diff` review (only the 2 views + `ADHDSummarySection` + `Chip`/`GlyphRampPicker` param + `NewLook.swift` + `Radius.swift` + `DESIGN.md` touched; `Theme`/`Palette`/`Typography`/`.card()` clean).
- [ ] T028 Run `/code-review` on the diff; address findings; open PR to `main` (US0+US1+US2). Owner device-QA sign-off is the merge gate.

---

## Dependencies & Execution Order

- **Phase 1 (Setup)** → **Phase 2 (US0)** blocks everything.
- After US0: **US1 (P1)** and **US2 (P2)** are independent (different files) — can be done in either
  order or in parallel; US1 first = MVP.
- **US3** is gated on spec-029, excluded from this PR.
- **Phase 6** after US1 + US2.

### Within stories

- US0: T002 ‖ T003 ‖ T008 (different files) → T004/T005/T006 (all in `NewLook.swift`, sequential) → T007 build.
- US1: T009 → T010 → T011 → T012 → T013 → T014 (mostly same file, sequential) → T015 audit → T016 verify.
- US2: T017 ‖ T018 (different files) → T019 → T020 → T021 audit → T022 verify.

### Parallel opportunities

- T003, T008 with T002 (Radius vs NewLook vs DESIGN.md — 3 files).
- US1 and US2 across the two screens once US0 lands.
- T017 ‖ T018 within US2.

---

## Implementation Strategy

**MVP** = Phase 1 + Phase 2 (US0) + Phase 3 (US1). Stop, device-QA Edit check-in vs a03, and it is
independently shippable. Then add US2 (a02). US3 waits for the 029 gate. One PR carries US0+US1+US2.

## Notes

- No RED tests: pure view re-skin, no logic (D5); existing VM suites are the regression gate and
  MUST stay unedited + green. SwiftUI views verified by build + owner device run (Principle X, II).
- `GlyphRampPicker` is shared with the out-of-scope Check-in composer — parameterize, never mutate
  its default (T012), or Check-in silently changes (FR-011).
- Commit after each task or logical group; keep `main` releasable (Constitution V).
