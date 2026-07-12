# Tasks: App-Wide New Look — Complete the Migration

**Input**: Design documents from `specs/033-newlook-app-wide/`
**Prerequisites**: plan.md, spec.md (required for user stories)
**Branch**: `feat/033-newlook-app-wide` (per `CLAUDE.md` Git Workflow — branch per feature off `main`, never commit straight to `main`)

**Tests**: Test-first (Constitution Principle X) applies only where this spec makes a **logic** change — that is **User Story 3** alone (T046 RED must precede T047 GREEN). Every other phase — Setup, Foundational, User Story 1, User Story 2, User Story 4, Polish — is a **pure SwiftUI view/token re-skin with no logic change**, so SwiftUI views are **EXEMPT** from test-first per Constitution Principle X and are instead verified by build + owner device run (each such phase repeats this exemption inline, mirroring how spec-032's `tasks.md` handled the same exemption — the exemption is stated, not silently assumed). No simulator anywhere in this document — owner builds and runs on device via the `ios-debugger-agent` skill (XcodeBuildMCP) per this project's standing "no iOS simulator" instruction.

**Organization**: by user story per spec.md's own priorities (US1 P1 🎯 MVP, US2 P2, US3 P3, US4 P4). Foundational blocks US1. Once Foundational lands, US1/US2/US3 are independent of each other. US4 depends on US1 **and** US2 **and** US3 all being complete — it deletes the `Theme` tokens they still reference until then.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: different file, no ordering dependency on an incomplete task in the same phase → parallelizable
- **[Story]**: US1 / US2 / US3 / US4 — omitted in Setup / Foundational / Polish phases
- Paths are repo-relative to the `app-four-spm` worktree root unless stated otherwise

---

## Phase 1: Setup

**Purpose**: Confirm a clean, green baseline before any change lands.

- [ ] T001 (OWNER GATE — no simulator) Confirm baseline: full build + full test suite (`SquirlDesignSystem` package, the `app-four-spm` app target, `SandboxApp`) are GREEN on `feat/033-newlook-app-wide` **before any change in this document lands**, via the `ios-debugger-agent` skill (XcodeBuildMCP). Record the pass so any later red is attributable to this feature (Constitution II). No simulator UI automation — device build/run only, per this project's standing "no iOS simulator" instruction.

**Checkpoint**: baseline green — Foundational work may start.

---

## Phase 2: Foundational (blocks User Story 1)

**Purpose**: Add the `NewLook.tintNeutral` token and the Figma-accurate two-layer card shadow that every US1 card task depends on, and correct the doc comments (`NewLook.swift`, `DESIGN.md`) that currently claim New Look is still scoped to two screens.

**⚠️ CRITICAL**: No User Story 1 work may begin until this phase is complete.

- [ ] T002 In `Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/NewLook.swift`, add a new token to the `NewLook` enum (lines 11-24), after `hairline` (line 21) and before `selection` (line 22): doc comment `/// Neutral tint — grooves, tracks, segmented-control fills (never a card background).` followed by `public static let tintNeutral = Color(lightHex: "#ECEAE6", darkHex: "#272A22")`.
  > The dark hex `#272A22` is a reasoned interpolation between `NewLook.card` dark (`#1C1E19`) and `NewLook.screen` dark (`#12140F`) — no Figma dark value was supplied for `tintNeutral`. Flag for design sign-off if a Figma variable surfaces later.
- [ ] T003 In `Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/NewLook.swift`, replace the single `.shadow(color: .black.opacity(0.06), radius: 8, y: 2)` call on line 36, inside `newLookCard(padding:)` (lines 32-37), with two chained shadow calls matching Figma "Tiimo/Shadow/Card": `.shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)` followed by `.shadow(color: .black.opacity(0.03), radius: 2, x: 0, y: 1)` — SwiftUI composites chained `.shadow()` modifiers sequentially onto the already-shadowed layer, so order matters.
- [ ] T004 In `Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/NewLook.swift`, rewrite the stale doc comment on lines 29-31 (currently asserts `.newLookCard()` is "distinct from" the Paper & Pollen `.card()`, naming RecordingRow and MedicationBarView as `.card()`'s "remaining consumers") to state that spec-033 makes New Look the app-wide look; `.card()`/`Theme` are retained only for the semantic-color set (accent/meadow/status/danger); RecordingRow and MedicationBarView are no longer permanent `.card()` consumers — they migrate to `.newLookCard()` under spec-033 (T010, T026). Also rewrite the file-level header comment on lines 3-6 (currently: New Look "runs alongside Paper & Pollen (Theme) on the two re-skinned screens ... the app-wide mixed look is an accepted, temporary transition state") to describe New Look as the app-wide default post spec-033, with `Theme` retained only for the semantic-color exceptions documented in `DESIGN.md`.
- [ ] T005 Amend `DESIGN.md`'s "New Look (spec 032) — second visual language, in adoption" section (lines 98-129): rewrite the heading/intro (lines 98-106, including the line 106 claim "Palette, Typography, and the `.card()` modifier are untouched") to state New Look is now the app-wide look (spec 033 supersedes the spec-032 two-screen scope) and `Theme` is retained only for accent/meadow/status/danger semantic colours (`Theme.accent`, `Theme.meadowGreen`, `Theme.meadowAmber`, `Theme.meadowGradient`, `Theme.statusDone`, `Theme.statusInProgress`, `Theme.danger`). Add a row to the palette table (lines 110-118) for `NewLook.tintNeutral` — light `#ECEAE6`, dark `#272A22`, role "grooves/tracks/segmented-control fills". Update the Cards bullet (lines 120-121) to document the two-layer shadow spec from T003 (0.05-opacity black, offset (0,2), radius 8 + 0.03-opacity black, offset (0,1), radius 2) replacing the old single-layer approximation. Add a new Decisions Log entry (after line 134) recording the spec-033 app-wide-adoption decision.
  > Must follow T002-T004 so the documented tokens/shadow match the actual code.

**Checkpoint**: `NewLook.tintNeutral` exists, the card shadow matches the Figma spec, docs describe the final app-wide state — User Story 1 may start.

---

## Phase 3: User Story 1 (P1) 🎯 MVP — "Every screen wears the New Look"

**Goal**: Every card, screen background, tab bar, and modal in the app renders in New Look (sage screen, white borderless radius-20 cards with the two-layer shadow, `NewLook.tintNeutral` tracks/grooves) instead of the old Paper & Pollen `Theme.background`/`Theme.cardBackground`/`.card()` surfaces — matching spec-032's two already-migrated screens.

**Independent Test**: Walk every tab (Calendar, Insights, Check-in, Settings) plus the Medication Log sheet and confirm no screen shows a Paper & Pollen cream/paper surface or bordered card — all surfaces are sage-ground / white-borderless-card / New Look track, in both light and dark, at default and an accessibility text size.

> **No "Tests for User Story 1" block.** This phase is a pure SwiftUI view/card-surface re-skin — no `@Model`, `Service`, or `@Observable` view-model logic changes. Per Constitution Principle X, SwiftUI views are EXEMPT from test-first; verification is build + owner device run (T029), mirroring how spec-032's `tasks.md` handled the identical exemption.

### US1 — shell (screen ground, tab bar, feedback chrome)

- [ ] T006 [P] [US1] In `app-four/DesignSystem/ScreenContainer.swift` line 52, change `.background(Theme.background.ignoresSafeArea())` to `.background(NewLook.screen.ignoresSafeArea())`; on line 53 change `.toolbarBackground(Theme.background, for: .navigationBar)` to `.toolbarBackground(NewLook.screen, for: .navigationBar)`.
  > Leave line 55's `.tint(Theme.meadowGreen)` unchanged — semantic accent token, not a surface.
- [ ] T007 [P] [US1] In `app-four/Views/RootTabView.swift`, add a New Look tab-bar background. After the `.tint(Theme.meadowGreen)` call on line 36, add `.toolbarBackground(NewLook.screen, for: .tabBar)` and `.toolbarBackgroundVisibility(.visible, for: .tabBar)` if verified sufficient against the iOS 26 deployment target. If SwiftUI's `.toolbarBackground(for: .tabBar)` proves insufficient for the Liquid Glass tab bar treatment (bleed/flash on tab transitions), fall back to a scoped `UITabBarAppearance` configured once at app launch (`UIColor(NewLook.screen)`, `.configureWithOpaqueBackground()`, assigned to `UITabBar.appearance().standardAppearance`/`.scrollEdgeAppearance`) — this is the one UIKit appearance-proxy exception permitted per Constitution I since SwiftUI has no direct equivalent for legacy tab bar chrome.
  > File currently has no tab-bar appearance code at all (confirmed by full read, 45 lines) — only line 36's `.tint`, which stays unchanged.
- [ ] T008 [P] [US1] In `app-four/Views/Feedback/FeedbackButton.swift` line 21, replace `.background(.ultraThinMaterial)` with `.background(NewLook.card)` so the button reads as a solid New Look card rather than translucent system chrome against the sage screen.
  > File is entirely `#if DEBUG || TESTFLIGHT` (lines 3, 32) — dev/TestFlight-only, no App Store production impact.

### US1 — cards: Calendar (DayCard, RecordingRow, TimelineBead, palette test)

- [ ] T009 [P] [US1] In `app-four/Views/Components/DayCard.swift`, replace the manual card-surface plumbing on lines 14 (`private let shape = RoundedRectangle(cornerRadius: Radius.card, style: .continuous)`), 39 (`.background(Theme.cardBackground)`), and 40 (`.clipShape(shape)`) with a single `.newLookCard()` on the VStack; remove the now-unused `shape` property.
- [ ] T010 [P] [US1] In `app-four/Views/Components/RecordingRow.swift` line 30, replace `.card(padding: Spacing.m)` with `.newLookCard(padding: Spacing.m)`.
  > This file was previously documented as a spec-032 "kept on `.card()`" exception (see T004) — spec-033 explicitly overrides that exception app-wide.
- [ ] T011 [P] [US1] In `app-four/Views/Components/TimelineBead.swift`: in the hollow/neutral bead centre (lines 48-51), replace `.fill(Theme.background)` (line 49) with `.fill(NewLook.screen)` and `.strokeBorder(Theme.separator, lineWidth: 1)` (line 50) with `.strokeBorder(NewLook.hairline, lineWidth: 1)`. In the carry-over badge (lines 74-84), replace `.background(Theme.elevatedBackground, in: .capsule)` (line 80) with `.background(NewLook.card, in: .capsule)` and `Capsule().strokeBorder(Theme.separator.opacity(0.3), lineWidth: 0.5)` (line 81) with `Capsule().strokeBorder(NewLook.hairline.opacity(0.3), lineWidth: 0.5)`.
  > Leave `Palette.medication` (lines 59, 77) and all mood-tint colours (lines 43-44) unchanged.
- [ ] T012 [US1] In `app-fourTests/Models/DayCardPaletteTests.swift` line 39, replace `Self.rgb(Theme.cardBackground, traits)` with `Self.rgb(NewLook.card, traits)` in `wordColourClearsAAOnItsBlockTint`.
  > MUST land in the same commit as T009 — this assertion checks contrast against the card surface color that `DayCard.swift` now renders via `.newLookCard()`; landing one without the other either breaks the build or silently mismatches the asserted colour against the real rendered surface.

### US1 — cards: Insights (gauges, connection cards)

- [ ] T013 [US1] TRACK: in `app-four/Views/Insights/SignalAverageGauges.swift` line 35 (`GaugeColumn.body`, RoundedRectangle track fill, lines 34-36), change `.fill(Theme.cardBackground)` to `.fill(NewLook.tintNeutral)`.
  > Mapping to `NewLook.card` would render the track invisible against the white NewLook card/screen background — this MUST be `tintNeutral`, not `card`.
- [ ] T014 [US1] TRACK: in `app-four/Views/Insights/SignalAverageGauges.swift` lines 79-82 (`GaugeColumn.fillGradient`), change the fallback branch `return AnyShapeStyle(Theme.cardBackground)` (line 81, used when `levelFill` is nil) to `AnyShapeStyle(NewLook.tintNeutral)` so the unfilled state matches the track token.
- [ ] T015 [US1] TRACK/DIVIDER: in `app-four/Views/Insights/SignalAverageGauges.swift` lines 112-114 (`TickLines.body`), change the dashed tick-line Rectangle `.fill(Theme.separator)` (line 113) to `.fill(NewLook.hairline)`.
- [ ] T016 [P] [US1] CARD SURFACE: in `app-four/Views/Insights/ConnectionCardsView.swift` lines 69-70 (`UnlockedCard.body`), change `.background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Radius.card))` to `.newLookCard()` (or `.background(NewLook.card, in: RoundedRectangle(cornerRadius: Radius.newLookCard))`) — borderless, radius 20, soft shadow. No separate stroke/border overlay exists on this card.
- [ ] T017 [P] [US1] CARD SURFACE (gated/dashed — keep the dash): in `app-four/Views/Insights/ConnectionCardsView.swift` lines 99-105 (`GatedCard.body`), keep the dashed `StrokeStyle(lineWidth: 1, dash: [5, 3])` (it signals the locked/gated affordance — do not remove it), but retint `Theme.textSecondary.opacity(0.35)` to `NewLook.hairline` (adjust opacity for visibility against the sage screen) and update `Radius.card` to `Radius.newLookCard`.
  > This card has no separate fill/background token — only the dashed border — so there is nothing else to remap. Open design question: confirm whether GatedCard should gain a `NewLook.card` base fill under the dash, or stay fill-less (screen shows through) — not assumed here.
- [ ] T018 [P] [US1] TRACK: in `app-four/Views/Insights/ConnectionCardsView.swift` lines 122-124 (`MiniBar.body`), change the background Capsule `.fill(Theme.separator)` (line 124, the empty track behind the progress fill) to `.fill(NewLook.tintNeutral)`.
  > Leave the fill Capsule `.fill(Theme.accent)` at line 126 unchanged — semantic accent.
  > `Radius.newLookCard` must exist (T002-T005 landed) before T016/T017 can compile as specified.

### US1 — cards: modals & Settings row

- [ ] T019 [P] [US1] In `app-four/Views/Components/MedicationLogSheet.swift` line 29, change `.background(Theme.background.ignoresSafeArea())` to `.background(NewLook.screen.ignoresSafeArea())`.
- [ ] T020 [US1] In `app-four/Views/Components/MedicationLogSheet.swift` lines 82-83 (medicationSection field card), replace `.background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Radius.card))` with `.newLookCard()` and DROP line 83's `.overlay(RoundedRectangle(cornerRadius: Radius.card).strokeBorder(Theme.separator, lineWidth: 1))` entirely — New Look cards are borderless.
- [ ] T021 [US1] In `app-four/Views/Components/MedicationLogSheet.swift` lines 118-119 (doseSection field card), same treatment as T020: `.newLookCard()`, drop the line 119 border overlay.
- [ ] T022 [US1] In `app-four/Views/Components/MedicationLogSheet.swift` lines 140-141 (durationSection field card), same treatment as T020: `.newLookCard()`, drop the line 141 border overlay.
- [ ] T023 [US1] In `app-four/Views/Components/MedicationLogSheet.swift` lines 155-156 (takenAtSection field card), same treatment as T020: `.newLookCard()`, drop the line 156 border overlay.
  > The `sheetNav` close-button Circle (lines 43-44, `.background(Theme.cardBackground, in: Circle())` + border) is card-tinted but is not a "field-card container" — out of scope here; flagged so it isn't silently dropped from the migration (likely belongs with the nav-chrome pass, T006-T008).
- [ ] T024 [P] [US1] In `app-four/Views/CheckIn/TextCheckInComposer.swift` lines 90-91 (noteBox card container), replace `.background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Radius.card))` with `.newLookCard()` and DROP line 91's border overlay. Do not touch ink/text tokens (lines 78, 85) — out of scope for this task, handled in US2.
  > Line 28's `.background(Theme.background.ignoresSafeArea())` (the composer's own screen fill) is NOT covered by this task — confirm at review whether it needs a NewLook.screen mapping too or is out of this spec's scope.
- [ ] T025 [P] [US1] In `app-four/Views/SettingsView.swift` line 60, change `.listRowBackground(Theme.cardBackground)` to `.listRowBackground(NewLook.card)`.
  > Keep `.listStyle(.insetGrouped)` (line 58) unchanged — Settings stays on the system inset-grouped list with system corner radius; this is a colour-only change, not a full `.newLookCard()` shape change.

### US1 — medication bar (visual re-skin only — not the data fix, that's US3)

- [ ] T026 [US1] In `app-four/Views/Components/MedicationBarView.swift` line 21, replace `.card(padding: Spacing.m)` with `.newLookCard(padding: Spacing.m)` on the outer VStack wrapping the dose rows.
- [ ] T027 [US1] In `app-four/Views/Components/MedicationBarView.swift` line 17 (inside the `ForEach` between stacked dose rows), replace `Divider().overlay(Theme.separator)` with `NewLook.hairline`.
- [ ] T028 [US1] In `app-four/Views/Components/MedicationBarView.swift` line 167 (`DoseTrack.body`), replace the groove `Capsule().fill(Theme.surface2)` with `Capsule().fill(NewLook.tintNeutral)`.
  > Keep the adjacent fill capsule at line 169 (`Capsule().fill(Palette.medication)`) unchanged — locked medication-purple progress fill, verify untouched after this edit.
  > The data-gating fix (`logManualDose` `isMockData` tagging) is a separate US3 story in `MedicationBarViewModel.swift` — not in scope here.

### US1 owner gate

- [ ] T029 (OWNER GATE — no simulator) [US1] Build + run on device. Confirm every screen and modal touched by T006-T028 (Calendar, Insights, Check-in composer, Settings, Medication Log sheet, medication bar) renders New Look — sage screen, white borderless radius-20 cards with the two-layer shadow, `NewLook.tintNeutral` tracks/grooves — in **light and dark**, at **default and an accessibility text size**, against contract S1-S10/M1-M3 per spec.md. No Paper & Pollen surface should remain visible on any screen this phase touched.

**Checkpoint**: every screen wears New Look surfaces; US1 (MVP) is independently shippable.

---

## Phase 4: User Story 2 (P2) — "One consistent ink typography"

**Goal**: All body/caption text across the app reads through `NewLook.inkPrimary`/`NewLook.inkSecondary` instead of `Theme.textPrimary`/`Theme.textSecondary`, and plain row dividers use `NewLook.hairline` — consistent ink weight app-wide, matching spec-032's two already-migrated screens.

**Independent Test**: Walk every screen touched below and confirm text renders in the New Look ink ramp (not the old Paper & Pollen ink), in light and dark, at default and an accessibility text size, with no contrast regression on the two flagged risk spots (T043, T044).

> **No "Tests for User Story 2" block.** This phase is a pure SwiftUI text-token re-skin — no logic change. Per Constitution Principle X, SwiftUI views are EXEMPT from test-first; verification is build + owner device run (T045), mirroring spec-032's identical exemption.

### US2 — ink pass A: CheckIn, Settings, Onboarding, MedicationLogSheet, MedicationBarView

- [ ] T030 [P] [US2] In `app-four/Views/CheckIn/CheckInView.swift`: replace `Theme.textSecondary` → `NewLook.inkSecondary` at L174, L185 (inside `.opacity(0.7)`), L270, L275, L283 (inside `.opacity(0.7)`), L322, L341 (inside `.opacity(0.3)`), L382, L400, L439; replace `Theme.textPrimary` → `NewLook.inkPrimary` at L177, L226, L227, L259, L312, L379, L436; replace `Theme.textSecondary.opacity(0.15)` at L294 (promptProgressBar track fill) → `NewLook.inkSecondary.opacity(0.15)` (default choice — track/decoration is text-adjacent here, not a groove/track component, so `inkSecondary` not `tintNeutral`; flag as a minor open call at review).
  > Do NOT touch L216-217/L392-393 (`Theme.meadowGradient`/`meadowAmber`) or L296 (`Theme.accent`) — semantic, not ink.
  > Leave the stopButton block (L348-371) and its `Theme.background` references untouched pending T043's owner decision.
- [ ] T031 [P] [US2] In `app-four/Views/CheckIn/TextCheckInComposer.swift`: replace `Theme.textPrimary` → `NewLook.inkPrimary` at L39, L50, L85, L136; replace `Theme.textSecondary` → `NewLook.inkSecondary` at L78, L115, L140; replace the plain row-divider `Divider().overlay(Theme.separator)` between signal-picker rows → `NewLook.hairline` at L64 and L66.
  > Do NOT touch L28 (`Theme.background`, screen bg — out of scope), L42/L91 (`Theme.separator` as a card/component border — card scope, T024), or L90 (`Theme.cardBackground` — card scope, T024).
- [ ] T032 [P] [US2] In `app-four/Views/SettingsView.swift`, replace `Theme.textSecondary` → `NewLook.inkSecondary` at L137, L176, L235.
  > No `Theme.textPrimary` occurrences in this file. No plain-row-divider `Theme.separator` usage (List uses row backgrounds). Do NOT touch L60 (`Theme.cardBackground` listRowBackground — card scope, T025).
- [ ] T033 [P] [US2] In `app-four/Views/Settings/JournalExportSection.swift`, replace `Theme.textPrimary` → `NewLook.inkPrimary` at L43, L51; replace `Theme.textSecondary` → `NewLook.inkSecondary` at L46.
  > No `Theme.separator` row-divider usage. Do NOT touch L55 (`Theme.surface2`, key-display background) or L78 (`Theme.background`, screen bg) — out of this cluster's ink scope.
- [ ] T034 [P] [US2] In `app-four/Views/Onboarding/WelcomeView.swift`, replace `Theme.textPrimary` → `NewLook.inkPrimary` at L44; replace `Theme.textSecondary` → `NewLook.inkSecondary` at L50.
  > No `Theme.separator` usage in this file. Do NOT touch L30 (`Theme.background`, screen bg).
- [ ] T035 [P] [US2] In `app-four/Views/Components/MedicationLogSheet.swift`: replace `Theme.textPrimary` → `NewLook.inkPrimary` at L41, L51, L79, L99, L104, L114, L129, L135; replace `Theme.textSecondary` → `NewLook.inkSecondary` at L72, L91, L106, L127, L149, and the `textSecondary` branch of the L59 ternary (`foregroundStyle(trimmedName.isEmpty ? Theme.textSecondary : Theme.meadowGreen)` — swap only the `textSecondary` side, leave `Theme.meadowGreen`); replace the plain in-card row divider `Divider().overlay(Theme.separator)` (chips/text-field split, dose-picker/onset split) → `NewLook.hairline` at L75 and L102.
  > Do NOT touch L44 (`Theme.separator` as the close-button circle border — component scope, T006-T008), L82-83/L118-119/L140-141/L155-156 (`Theme.cardBackground` + `Theme.separator` card borders — card scope, T020-T023), or L178 (`Palette.medication` — semantic, unchanged).
- [ ] T036 [P] [US2] In `app-four/Views/Components/MedicationBarView.swift`: replace `Theme.textPrimary` → `NewLook.inkPrimary` at L62; replace `Theme.textSecondary` → `NewLook.inkSecondary` at L74; replace the plain row divider `Divider().overlay(Theme.separator)` between stacked dose rows → `NewLook.hairline` at L17.
  > Do NOT touch L21 (`.card(padding:)` — card scope, T026), L67 (`Palette.medication` — semantic), or L167 (`Theme.surface2` in `DoseTrack` groove — surface scope, T028, not ink).

### US2 — ink pass B: Chip, Insights, Card.cardEyebrow, Buttons

- [ ] T037 [US2] In `app-four/Views/Components/Chip.swift` line 58 (`filterChip(title:isSelected:)`), migrate the unselected-state ink token: `.foregroundStyle(isSelected ? Theme.accent : Theme.textSecondary)` — replace only the `Theme.textSecondary` branch with `NewLook.inkSecondary`.
  > Same source line as T038 — land both edits to line 58 together in one pass.
- [ ] T038 [US2] In `app-four/Views/Components/Chip.swift` — distinct SELECTED-state semantic change (not a plain ink swap): at line 58 and line 62 (`isSelected ? Theme.accent.opacity(0.15) : Theme.cardBackground`), replace `Theme.accent` (both the L58 label color and the L62 background fill) with `NewLook.selection` (green) per the plan's decision to move filter-chip selection off bronze accent.
  > No medication-role chip variant exists in this file (only `.topic`/`.filter` styles) — nothing else to preserve.
- [ ] T039 [P] [US2] In `app-four/Views/Insights/SignalAverageGauges.swift`: line 51 `.foregroundStyle(Theme.textSecondary)` (gauge caption) → `NewLook.inkSecondary`; line 85 `guard let filled = levelFill else { return Theme.textPrimary }` (fillInkColor fallback) → `NewLook.inkPrimary`.
  > Do NOT touch line 35/81 (`Theme.cardBackground`, track/fill surface — T013/T014) or line 113 (`Theme.separator`, tick lines — T015).
- [ ] T040 [P] [US2] In `app-four/Views/Insights/ConnectionCardsView.swift`: replace `Theme.textSecondary` → `NewLook.inkSecondary` at L53 (UnlockedCard eyebrow), L85 (GatedCard eyebrow), L91 (GatedCard lock icon), L95 (GatedCard unlock copy), L136 (MiniBar leadingText), L145 (MiniBar trailingText); replace `Theme.textPrimary` → `NewLook.inkPrimary` at L59 (UnlockedCard sentence), L141 (MiniBar barLabel); replace `Theme.textSecondary.opacity(0.35)` at L102 (GatedCard dashed border tint — this is `textSecondary` used as a tint, not `Theme.separator`) → `NewLook.inkSecondary.opacity(0.35)`.
  > Do NOT touch L70 (`Theme.cardBackground` — card scope, T016), L124 (`Theme.separator` — track scope, T018), or L126 (`Theme.accent` — MiniBar fill, semantic, not ink).
- [ ] T041 [P] [US2] In `Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/Card.swift` line 39 (`cardEyebrow()`), replace `.foregroundStyle(Theme.textSecondary)` → `NewLook.inkSecondary`.
  > Do NOT touch the `.card()` modifier itself (lines 18-27, incl. `Theme.cardBackground` L21, `Theme.cardStroke` L24) — deleted in US4 (T054), not edited now.
- [ ] T042 [P] [US2] In `Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/Buttons.swift` (`SecondaryButtonStyle` only): line 23 `.foregroundStyle(Theme.textPrimary)` → `NewLook.inkPrimary`; line 26 `.background(Theme.cardBackground, in: .rect(cornerRadius: Radius.button))` → `NewLook.card`; line 29 `.strokeBorder(Theme.separator, lineWidth: 1)` → `NewLook.hairline` (this is a button border, not a card border — kept, not dropped).
  > Leave `PrimaryButtonStyle` (lines 5-16) fully untouched — `Theme.meadowGradient`/`Theme.meadowAmber` are semantic, out of scope.

### US2 — contrast-risk owner decisions (do not silently resolve)

- [ ] T043 [US2] OWNER DECISION — `app-four/Views/CheckIn/CheckInView.swift` stopButton (lines 348-371): an inverted-contrast capsule — dark fill via `Theme.textPrimary` (L366) with a light label/glyph via `Theme.background` (L362 foregroundStyle, L357 stop-glyph fill, L354 ProgressView tint). None of the three `Theme.background` usages has a NewLook mapping in this migration's token table (`NewLook.screen`/`NewLook.card` are surface tokens, not an "on-dark label" token). A naive swap of only the L366 fill to `NewLook.inkPrimary` while leaving the label on `Theme.background` is unverified against `NewLook.inkPrimary`'s exact hex — this pairing was hand-tuned for the old ink/paper palette. Owner must decide at review: (a) introduce a dedicated NewLook "onInk"/inverse-label token for this spot, or (b) explicitly approve leaving all three `Theme.background` references untouched with only the L366 fill swapped, then eyeball contrast on device. Do not blind-swap L354/357/362.
- [ ] T044 [US2] OWNER DECISION — `app-four/Views/Components/MedicationLogSheet.swift` L174: the UNSELECTED medication chip background is `Color.secondary.opacity(0.15)` (system secondary, not a `Theme` token), with the SELECTED state using `Palette.medication.opacity(0.25)`. No NewLook equivalent is named for this in the token mapping (`NewLook.tintNeutral` is scoped to grooves/tracks/segmented fills, not chip backgrounds). Owner must decide at review whether `NewLook.tintNeutral` covers this chip or a dedicated token is needed — do not guess a value.

### US2 owner gate

- [ ] T045 (OWNER GATE — no simulator) [US2] Build + run on device. Confirm ink renders through `NewLook.inkPrimary`/`NewLook.inkSecondary` across every file touched by T030-T042, in **light and dark**, at **default and an accessibility text size**, per spec.md's typography contract. Confirm T043 and T044's owner decisions were made (not silently defaulted) and their outcomes verified on device.

**Checkpoint**: ink is consistent app-wide; US1 + US2 both independently shippable.

---

## Phase 5: User Story 3 (P3) — "Medication bar shows real logged doses"

**Goal**: A dose logged via `MedicationBarViewModel.logManualDose` appears in `activeDoses` regardless of the current debug-mock-mode setting, because the created `MedicationEvent` is tagged with the mode it was logged under.

**Independent Test**: With `debugMockMode` on, log a manual dose; it appears in the medication bar's active doses immediately, without toggling mock mode off and back on.

### Tests for User Story 3 (test-first · RED — MANDATORY) ⚠️

> **NOTE (RED): Write this test FIRST and RUN it — it MUST FAIL before any implementation.** This is spec-033's one logic change (FR-009); Constitution Principle X requires RED before GREEN.

- [ ] T046 [US3] RED: in `app-fourTests/ViewModels/MedicationBarViewModelTests.swift`, add a new `@Test` case (after `logManualDoseAppearsInActiveDoses`, i.e. after line 144, before `deleteEventRemovesFromActiveDoses` at line 146) named e.g. `logManualDoseTaggedWithCurrentMockModeAppearsInActiveDoses`: set `UserDefaults.standard.set(true, forKey: "debugMockMode")` explicitly (matching how `refresh()` at line 61 reads the same raw key — unregistered under XCTest/Swift Testing), call `viewModel.logManualDose(name: "Concerta", dose: "36mg", takenAt: Date())` (signature per line 111), then assert `#expect(viewModel.activeDoses.first?.name == "Concerta")`. Reset `UserDefaults.standard.removeObject(forKey: "debugMockMode")` at the end (or in a `defer`) to avoid leaking state into other tests. Run it and confirm it FAILS: `logManualDose` (lines 111-123) constructs `MedicationEvent(...)` (lines 112-119) without ever setting `isMockData`, so it defaults to `false`; `refresh()`'s predicate at line 63 (`$0.isMockData == mockMode`) evaluates `false == true` and filters the event out, leaving `activeDoses` empty and `.first?.name` nil.

### Implementation for User Story 3

- [ ] T047 [US3] GREEN: in `app-four/ViewModels/MedicationBarViewModel.swift`, fix `logManualDose` (lines 111-123) so the newly created `MedicationEvent` is tagged with the current debug-mock-mode flag. Add an `isMockData:` argument to the `MedicationEvent(...)` initializer call (lines 112-119), set to `UserDefaults.standard.bool(forKey: "debugMockMode")` (mirroring the read already done in `refresh()` at line 61), so the event's `isMockData` matches the mode `refresh()` filters on at line 63. Do not alter `refresh()`'s predicate or any other behavior.
  > If `MedicationEvent`'s memberwise initializer does not expose `isMockData` as a parameter, set `event.isMockData = ...` after construction and before `context.insert(event)` (line 120) instead.

### US3 owner gate

- [ ] T048 (OWNER GATE — no simulator) [US3] Run `MedicationBarViewModelTests` and confirm T046's new test FAILS (RED) on the pre-fix code, then confirm it PASSES (GREEN) after T047 lands, with no other test in the file regressed. Device check: with `debugMockMode` on, log a real dose in the running app and confirm it appears in the medication bar immediately.

**Checkpoint**: the medication-bar data bug is fixed, test-first, and verified on device — US1 + US2 + US3 all independently shippable.

---

## Phase 6: User Story 4 (P4) — "A single design system, no dead styling"

**Goal**: `SandboxApp` no longer references any retired `Theme` member or `.card()`; the 8 retired `Theme` members and the `.card()` modifier are deleted from `SquirlDesignSystem`; the codebase has exactly one visual language.

**Independent Test**: Full-repo grep for the 8 retired `Theme` members and `.card(` returns zero matches outside their own now-deleted definitions; `SandboxApp` and the app target both build clean; full suite green.

**⚠️ DEPENDENCY**: This phase depends on **Phase 3 (US1) AND Phase 4 (US2) AND Phase 5 (US3) all being complete**. It deletes tokens (`Theme.background`, `.cardBackground`, `.surface2`, `.elevatedBackground`, `.textPrimary`, `.textSecondary`, `.separator`, `.cardStroke`, `.card()`) that US1/US2/US3 migrated away from — starting T049 before all three land will break the build for whichever story hasn't migrated yet.

> **No "Tests for User Story 4" block.** SandboxApp migration and dead-code deletion are non-logic changes — SwiftUI/build-graph only. Per Constitution Principle X, exempt from test-first; verified by build + full-suite green (T055), mirroring spec-032's exemption pattern.

### US4 — SandboxApp migration (must land before the grep gate)

- [ ] T049 [P] [US4] Migrate `SandboxApp/Sources/DesignGallery.swift`: L19 `.background(Theme.background.ignoresSafeArea())` → `NewLook.screen`; L23 `foregroundStyle(Theme.textPrimary)` (title helper) → `NewLook.inkPrimary`; L35 `foregroundStyle(Theme.textSecondary)` (glyphRow label) → `NewLook.inkSecondary`; L45 `foregroundStyle(Theme.textSecondary)` (swatches label) → `NewLook.inkSecondary`; L61 `swatches("Surfaces", [Theme.background, Theme.cardBackground, Theme.surface2])` → `[NewLook.screen, NewLook.card, NewLook.tintNeutral]` (leave the `Accents` row at L62 untouched); L68 `foregroundStyle(Theme.textSecondary)` (swatches label) → `NewLook.inkSecondary`; L73 `.strokeBorder(Theme.separator, lineWidth: 1)` (swatch tile outline) → `NewLook.hairline`; L83/L84/L85/L86 `foregroundStyle(Theme.textPrimary)` (typography samples) → `NewLook.inkPrimary`; L87 `foregroundStyle(Theme.textSecondary)` (caption sample) → `NewLook.inkSecondary`; L101 `foregroundStyle(Theme.textPrimary)` (card body text) → `NewLook.inkPrimary`; L104 `.card()` → `.newLookCard()`.
- [ ] T050 [P] [US4] Migrate `SandboxApp/Sources/CalendarMock.swift`: L75 `.background(Theme.background.ignoresSafeArea())` → `NewLook.screen`; L97 `.background(Theme.cardBackground)` (day-card surface) → `NewLook.card`, and drop the paired border overlay at L99 (`.overlay(...strokeBorder(Theme.separator, lineWidth: 1))`) entirely — New Look cards are borderless; L106 `Circle().fill(day.mood?.badgeTint ?? Theme.surface2)` → `NewLook.tintNeutral`; L111 `foregroundStyle(Theme.textSecondary)` (chevron) → `NewLook.inkSecondary`; L115 `Rectangle().fill(Theme.separator)` (divider under header) → `NewLook.hairline`; L128 `foregroundColor(Theme.textSecondary)` (middot) → `NewLook.inkSecondary`; L162 `Rectangle().fill(Theme.separator)` (timeline connector) → `NewLook.hairline`; L169/L171 `foregroundStyle(Theme.textSecondary)` (timestamp, chevron.right) → `NewLook.inkSecondary`; L179 `foregroundStyle(Theme.textPrimary)` (entry note) → `NewLook.inkPrimary`; L197 `foregroundStyle(item.med ? Palette.medication : Theme.textPrimary)` (chip text, non-med branch only) → `NewLook.inkPrimary` (leave the `Palette.medication` branch untouched).
  > This file builds its card surface by hand (background+clipShape+overlay) rather than calling `.card()`; the hardcoded 16pt corner radius (vs NewLook's 20pt) was not in the original token-mapping instructions — confirm with the author before assuming it should also become `.newLookCard()`.
- [ ] T051 [P] [US4] Migrate `SandboxApp/Sources/InsightsMock.swift`: L18 `.background(Theme.background.ignoresSafeArea())` → `NewLook.screen`; L23 `foregroundStyle(Theme.textPrimary)` (head title) → `NewLook.inkPrimary`; L24 `foregroundStyle(Theme.textSecondary)` (head subtitle) → `NewLook.inkSecondary`; L55 `foregroundStyle(Theme.textSecondary)` (mood legend) → `NewLook.inkSecondary`; L72 `foregroundStyle(Theme.textSecondary)` (sleep-not-tracked caption) → `NewLook.inkSecondary`; L75 `.overlay(Capsule().strokeBorder(Theme.separator, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))` → `NewLook.hairline`; L85 `foregroundStyle(Theme.textSecondary)` (strip summary) → `NewLook.inkSecondary`; L92 `Theme.textSecondary.opacity(0.4)` (empty-bead dashed stroke) → `NewLook.inkSecondary.opacity(0.4)`; L118 `RoundedRectangle(cornerRadius: 10).fill(Theme.cardBackground)` (gauge track background) → `NewLook.tintNeutral`; L139 `foregroundStyle(Theme.textPrimary)` (connection headline) → `NewLook.inkPrimary`; L140 `Capsule().fill(Theme.separator)` (progress track) → `NewLook.tintNeutral`; L143/L147 `foregroundStyle(Theme.textSecondary)` (Med days / Sharp+ focus labels) → `NewLook.inkSecondary`; L145 `foregroundStyle(Theme.textPrimary)` (75% value) → `NewLook.inkPrimary`; L151 `.card()` → `.newLookCard()`.
  > Flag L140 and L118 for author sign-off before merging: L140 is `Theme.separator` used as a progress-bar TRACK fill, not a divider — mapping to `hairline` would apply a 1px hairline weight to an 8pt-tall bar; `NewLook.tintNeutral` is the correct semantic match. L118 reads `Theme.cardBackground` but is functionally a gauge-track background behind a colored fill bar inside a card — `NewLook.tintNeutral` (not `NewLook.card`, which would be near-invisible against the card's own white background) is the intended mapping.

### US4 — grep gate (blocks deletion)

- [ ] T052 [US4] GREP GATE (blocks T053 and T054 — no [P]): after T049-T051 land, run a full-repo grep for the 8 retired `Theme` members and `.card(`, including `SandboxApp/` and all test targets: `grep -rn -E '\bTheme\.(background|cardBackground|surface2|elevatedBackground|textPrimary|textSecondary|separator|cardStroke)\b' --include='*.swift' /Users/caesargrey/Projects/app-four-spm` and `grep -rn '\.card(' --include='*.swift' /Users/caesargrey/Projects/app-four-spm`. Confirm ZERO matches remain anywhere outside the definitions in `Theme.swift` (lines 9, 11, 13, 15, 18, 19, 23, 24) and `Card.swift` (line 18's `func card(` declaration, plus its `#Preview` calls at lines 51 and 57 — the preview must also be migrated or deleted as part of this gate, since it will still fail the grep otherwise). Do not proceed to T053/T054 until this returns clean.

### US4 — dead-token deletion (sequential, same PR)

- [ ] T053 [US4] In `Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/Theme.swift`, delete the 8 retired members: L9 `background`, L11 `cardBackground`, L13 `surface2`, L15 `elevatedBackground`, L18 `textPrimary`, L19 `textSecondary`, L23 `separator`, L24 `cardStroke` (and their now-dangling doc comments at L8, L10, L12, L14, L17, L22, plus the now-empty `// MARK: - Backgrounds` (L7), `// MARK: - Text` (L17), `// MARK: - Separators` (L21) headers — remove those too). MUST KEEP unchanged: L28 `accent`, L29 `meadowGreen`, L30 `meadowAmber`, L33 `statusDone`, L34 `statusInProgress`, L36 `danger`, L40-43 `meadowGradient`, and their `// MARK: - Accent + Meadow` (L26), `// MARK: - Status (no raw system green/orange)` (L32), `// MARK: - The signature gradient` (L38) headers. Resulting file contains only the Accent/Meadow/Status/Gradient sections (lines 26-44 as currently numbered).
  > Must run after T052 confirms zero external references. Must land in the same commit/PR as T054 and T049-T051.
- [ ] T054 [US4] In `Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/Card.swift`, delete the `.card()` modifier: remove `func card(padding:)` (L18-27, including the border overlay L22-25 `.overlay(...strokeBorder(Theme.cardStroke, lineWidth: 1))`) and its doc comment block (L6-17). KEEP `cardEyebrow()` (L32-41) — confirm at this task whether its `Theme.textSecondary` reference at L39 was already migrated to `NewLook.inkSecondary` by T041; if not, migrate it here rather than letting the T053 deletion break the build. Update the `#Preview` block (L45-60): L51 `.card()` and L57 `.card(padding: Spacing.m)` must be deleted (if the preview only exists to demo the removed modifier) or migrated to `.newLookCard()` (if the preview is kept to demonstrate the replacement).
  > Must run after T052. Must land in the same commit/PR as T053.

### US4 — final verification

- [ ] T055 (OWNER GATE — no simulator) [US4] After T053 and T054 land: Clean Build Folder + delete DerivedData, then run the full test suite (SquirlDesignSystem package tests + SandboxApp build + app-four-spm app target tests) via `ios-debugger-agent`/XcodeBuildMCP and confirm all green before closing out US4/spec-033.

**Checkpoint**: exactly one visual language remains in the codebase; all four user stories complete.

---

## Final Phase: Polish & Cross-Cutting

- [ ] T056 Style-literal audit (SC-003): grep every file touched by T002-T055 for hardcoded colour/radius/shadow literals — zero should remain outside `NewLook.*`/`Palette.*`/`Radius.*`/`Spacing.*` tokens.
- [ ] T057 Isolation/regression check (FR-013, **verify-only, do not re-Theme**): confirm the spec-032 screens — `RecordingDetailView`, `ExtractionReviewView`, `ADHDSummarySection` — render unchanged from their spec-032 state; they are already New Look and must not be touched again by this spec.
- [ ] T058 Accessibility pass across every screen touched by T002-T055: Dynamic Type to an accessibility size (no clipping/overlap; chips wrap), VoiceOver labels intact on chips/nav/delete controls, contrast holds in light + dark — per `swift-accessibility-skill` conventions.
- [ ] T059 Full suite green on the branch + final `git diff` review confirming only the files named across T002-T055 are touched.
- [ ] T060 Run `/code-review` on the diff; address findings.
- [ ] T061 Open PR to `main` per this project's Solo Git Discipline (Constitution V, `CLAUDE.md` Git Workflow) — owner device-QA sign-off (T029, T045, T048, T055, T058) is the merge gate.

**Checkpoint**: spec-033 complete, mergeable.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: no dependencies — starts immediately.
- **Foundational (Phase 2)**: depends on Setup — BLOCKS User Story 1.
- **User Story 1 (Phase 3)**: depends on Foundational only.
- **User Story 2 (Phase 4)**: depends on Foundational only — independent of US1's files, though both should exist before US4.
- **User Story 3 (Phase 5)**: depends on Foundational only — fully independent of US1/US2 (different files, pure logic fix).
- **User Story 4 (Phase 6)**: depends on **US1 AND US2 AND US3 all complete** — deletes tokens they still reference until then.
- **Polish (Final Phase)**: depends on US4 complete.

### User Story Dependencies

- **US1 (P1)**: after Foundational — no dependency on US2/US3. Should be done first for the MVP.
- **US2 (P2)**: after Foundational — no dependency on US1/US3; can proceed in parallel with US1 or interleaved.
- **US3 (P3)**: after Foundational — no dependency on US1/US2; smallest, fully isolated (`MedicationBarView*` logic only).
- **US4 (P4)**: after US1 + US2 + US3 all land — cannot start early.

### Within Each User Story

- Foundational: T002 → T003 → T004 (all same file, sequential) → T005 (DESIGN.md, follows code).
- US1: shell (T006‖T007‖T008) ‖ Calendar cards (T009‖T010‖T011 → T012) ‖ Insights cards (T013→T014→T015, then T016‖T017‖T018) ‖ modal cards (T019‖(T020→T021→T022→T023)‖T024‖T025) ‖ medbar visual (T026→T027→T028) → T029 owner gate last.
- US2: ink pass A (T030‖T031‖T032‖T033‖T034‖T035‖T036) ‖ ink pass B (T037→T038, then T039‖T040‖T041‖T042) → T043, T044 owner decisions → T045 owner gate last.
- US3: T046 (RED) → T047 (GREEN) → T048 owner gate.
- US4: T049‖T050‖T051 → T052 (grep gate, blocks) → T053 → T054 (same PR) → T055 owner gate.

### Parallel Opportunities

- All Setup/Foundational tasks marked [P] — none in Foundational (all same-file sequential).
- US1, US2, US3 can proceed in parallel once Foundational lands (different files, different stories).
- Within US1: T006/T007/T008 (shell, 3 files); T009/T010/T011 (Calendar cards, 3 files); T016/T017/T018 (Insights cards, 1 file, independent structs); T019/T024/T025 (modal/settings surfaces, 3 files).
- Within US2: all of T030-T036 (ink pass A, 7 different files) run in parallel; T039/T040/T041/T042 (ink pass B tail, 4 different files) run in parallel.
- Within US4: T049/T050/T051 (3 SandboxApp files) run in parallel, but all must complete before T052.

---

## Parallel Example: Setup / Foundational

```bash
# Phase 1 and Phase 2 are single-threaded — no parallel tasks.
Task: "T001 owner-gate baseline build+suite green"
Task: "T002 add NewLook.tintNeutral"          # sequential, same file as T003/T004
Task: "T003 two-layer card shadow"
Task: "T004 fix stale NewLook.swift doc comments"
Task: "T005 amend DESIGN.md"                   # follows T002-T004
```

## Parallel Example: User Story 1

```bash
# Shell (3 different files):
Task: "T006 ScreenContainer.swift → NewLook.screen"
Task: "T007 RootTabView.swift tab-bar background"
Task: "T008 FeedbackButton.swift → NewLook.card"

# Calendar cards (3 different files):
Task: "T009 DayCard.swift → .newLookCard()"
Task: "T010 RecordingRow.swift → .newLookCard()"
Task: "T011 TimelineBead.swift track/border tokens"
# T012 (DayCardPaletteTests) must land WITH T009, not run standalone in parallel.

# Insights cards, ConnectionCardsView.swift structs (independent, same file):
Task: "T016 UnlockedCard → .newLookCard()"
Task: "T017 GatedCard dashed border retint"
Task: "T018 MiniBar track → NewLook.tintNeutral"
```

## Parallel Example: User Story 2

```bash
# Ink pass A (7 different files):
Task: "T030 CheckInView.swift ink tokens"
Task: "T031 TextCheckInComposer.swift ink tokens"
Task: "T032 SettingsView.swift ink tokens"
Task: "T033 JournalExportSection.swift ink tokens"
Task: "T034 WelcomeView.swift ink tokens"
Task: "T035 MedicationLogSheet.swift ink tokens"
Task: "T036 MedicationBarView.swift ink tokens"

# Ink pass B tail (4 different files, after T037/T038 land sequentially):
Task: "T039 SignalAverageGauges.swift ink tokens"
Task: "T040 ConnectionCardsView.swift ink tokens"
Task: "T041 Card.swift cardEyebrow ink token"
Task: "T042 Buttons.swift SecondaryButtonStyle ink tokens"
```

## Parallel Example: User Story 3

```bash
# US3 is strictly sequential — RED before GREEN, Constitution Principle X:
Task: "T046 RED — write + run failing MedicationBarViewModelTests case"
Task: "T047 GREEN — tag isMockData in logManualDose"
Task: "T048 owner gate — confirm RED→GREEN + device check"
```

## Parallel Example: User Story 4

```bash
# SandboxApp migration (3 different files, run first):
Task: "T049 DesignGallery.swift migration"
Task: "T050 CalendarMock.swift migration"
Task: "T051 InsightsMock.swift migration"

# Then strictly sequential, no [P]:
Task: "T052 grep gate — zero retired-token matches outside definitions"
Task: "T053 delete 8 retired Theme members"
Task: "T054 delete .card() modifier"
Task: "T055 owner gate — clean rebuild + full suite green"
```

---

## Implementation Strategy

### MVP First (Phase 1 + Phase 2 + Phase 3)

1. Complete Phase 1: Setup.
2. Complete Phase 2: Foundational (CRITICAL — blocks US1).
3. Complete Phase 3: User Story 1.
4. **STOP and device-QA** (T029): every screen wears New Look surfaces, light + dark, default + accessibility size.
5. Ship — US1 alone is a complete, revertable PR per Constitution V.

### Incremental Delivery

1. Setup + Foundational → foundation ready.
2. Add User Story 1 → device-QA (T029) → ship (MVP).
3. Add User Story 2 → device-QA (T045) → ship. Can interleave with US3 (independent files) if capacity allows.
4. Add User Story 3 → test-first RED/GREEN (T046-T047) → device-QA (T048) → ship.
5. Add User Story 4 last, only once US1+US2+US3 are all merged → SandboxApp migration → grep gate → token deletion → clean-rebuild verification (T055) → ship.
6. Polish (T056-T061) closes out the spec: style-literal audit, spec-032 isolation check, accessibility pass, full suite + diff review, `/code-review`, PR to `main`.

## Notes

- Test-first (Constitution Principle X) applies **only** to User Story 3 (T046 RED → T047 GREEN) — the one logic change in this spec. Every other phase is a SwiftUI-view re-skin, EXEMPT per Principle X, and is verified by build + owner device run instead.
- No shared-component (`GlyphRampPicker`) or cross-screen style-parameterization notes apply here — that concern was specific to spec-032's two-screen re-skin, not this app-wide migration.
- Commit after each task or logical group (e.g., T020-T023 as one commit, T049-T051 as one commit).
- Keep `main` releasable at every merge — one PR per user story where practical, per Constitution V.
- No simulator anywhere in this feature — owner builds and runs on device via `ios-debugger-agent`/XcodeBuildMCP per this project's standing instruction; all "OWNER GATE" tasks are explicit human checkpoints, not automatable.