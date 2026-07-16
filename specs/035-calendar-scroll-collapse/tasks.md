<!-- Created: 2026-07-16 14:20 (WEST) · Updated: 2026-07-16 14:41 (WEST) -->
# Tasks: Calendar Strip Scroll-Collapse & Fade

**Input**: Design documents from `/specs/035-calendar-scroll-collapse/`

**Prerequisites**: plan.md, spec.md, research.md (D1–D9), data-model.md, contracts/strip-fade-behavior.md (C1–C12), quickstart.md

**Tests**: Test-first is MANDATORY for the one logic component (`CalendarStripFade`) per Constitution **Principle X** — RED before the file exists, then GREEN. SwiftUI view wiring is exempt (build + owner device run; **no simulator** in this environment — owner is the device gate).

**Organization**: Grouped by user story. US1 (collapse effect) is the MVP; US2 (compact title) depends on US1's progress state by design (the spec itself says US2 is meaningless without US1).

## Format: `[ID] [P?] [Story] Description`

## Path Conventions

Single Xcode project: app code in `app-four/`, tests in `app-fourTests/` (Swift Testing). Design-system SPM package is **untouched** by this feature (research D9).

---

## Phase 1: Setup (merge gate)

**Purpose**: Land the branch on the code this plan was verified against.

- [X] T001 ~~Verify PRs #28/#31 merged, rebase onto `origin/main`~~ **Satisfied by owner override (2026-07-16): restacked onto `feat/034-daycard-a01` instead** — the owner didn't want to wait for GitHub; feat/034 contains exactly what the merges would deliver. `git rebase --onto feat/034-daycard-a01 main feat/035…`; CLAUDE.md pointer + feature.json conflicts resolved to 035; post-rebase `CalendarLibraryView.swift` verified to match plan.md §A (pinnedHeader sibling, `topDayID` at line 103). **Residual step when #28/#31 merge: retarget/rebase this branch onto `main` (spec files + these commits only — trivial).**

**Checkpoint**: branch based on post-merge main; plan assumptions re-verified against the rebased file.

---

## Phase 2: Foundational (blocking — the pure math both stories consume)

**⚠️ CRITICAL**: RED before GREEN; no view work before this phase is green.

- [X] T002 RED — create `app-fourTests/Views/CalendarStripFadeTests.swift` (Swift Testing, style of `app-fourTests/Views/DayCardExpandStateTests.swift`) pinning contract rows C1–C8 of `contracts/strip-fade-behavior.md`: rest → progress 0 (C1); dead-zone boundary incl. negative rubber-band offsets → bit-exact 0 (C2); mid-band linearity (C3); completion exactly at `offset == stripHeight` for 130 and 290 heights (C4, C8); `stripHeight == 0` floors the band at `minFadeDistance` — finite, no instant collapse (C5); clamp + 1/100 quantization (C6); `showsTitle` false at 0.79 / true at 0.80 (C7). Run the suite — it MUST FAIL to compile/pass (the enum doesn't exist yet). Record the RED evidence in the task log.
- [X] T003 GREEN — create `app-four/Views/Library/CalendarStripFade.swift`: pure `enum CalendarStripFade` (no SwiftUI import) with documented constants `deadZone = 24`, `minFadeDistance = 44`, `titleReveal = 0.8` and functions `progress(offset:stripHeight:)`, `stripOpacity(progress:)`, `showsTitle(progress:)` exactly per plan.md §D. Full suite green; no other file touched.

**Checkpoint**: contract C1–C8 pinned green — view wiring may begin.

---

## Phase 3: User Story 1 — strip scrolls away & fades (Priority: P1) 🎯 MVP

**Goal**: The calendar strip scrolls with the content and fades after the dead zone; every existing interaction is preserved; med bar untouched.

**Independent Test**: On a day with enough entries, scroll: no fade for ~24pt, then fade-while-scrolling completing as the strip clears; reverse symmetric; date tap keeps the strip visible; med bar pixel-identical (quickstart §US1).

- [X] T004 [US1] Restructure at parity (NO fade yet) in `app-four/Views/Library/CalendarLibraryView.swift`: replace the outer `VStack(spacing: 0)` with `Group` (the ScrollView must own the top edge — plan.md §A load-bearing subtlety); move `headerBlock` inside the ScrollView as the first element of a plain `VStack(spacing: 0)` ahead of the existing `LazyVStack` (which keeps its spacing/paddings); keep `.edgeFadeMask(top: 0, bottom: Spacing.section)`; leave the empty-state branch (`pinnedHeader` fixed) untouched (FR-012).
- [X] T005 [US1] Same file — replace id-based scrolling (research D3, FR-008): delete `@State topDayID: Date?` and `.scrollPosition(id: $topDayID, anchor: .top)`; add `@State listPosition = ScrollPosition(edge: .top)` + `.scrollPosition($listPosition)`; `scrollList(to:)` now calls `listPosition.scrollTo(edge: .top)` inside the existing RM-gated `withAnimation(Motion.smooth)` block. Grep-confirm zero `topDayID` survivors.
- [ ] T006 [US1] (OWNER GATE — folded into T012) Parity verification: build + full test suite + rest-layout pixel-parity (strip, divider, first card, med bar) + the three programmatic scrolls (date tap, out-of-month tap, Today jump) land at top with the strip visible. No local build environment (no simulator; device signing is owner's) — T004/T005/T007 were implemented in one pass with `swiftc -parse` syntax gates + grep hygiene; the behavioral parity check happens on the owner's first device build alongside T012.
- [X] T007 [US1] Fade wiring, same file: add `@State collapseProgress: CGFloat = 0` and `@State stripHeight: CGFloat = 0`; `.onGeometryChange(for: CGFloat.self, of: { $0.size.height })` on `headerBlock` → `stripHeight`; `.onScrollGeometryChange(for: CGFloat.self)` on the ScrollView with transform `CalendarStripFade.progress(offset: geo.contentOffset.y + geo.contentInsets.top, stripHeight: stripHeight)` → `collapseProgress`; apply `.opacity(CalendarStripFade.stripOpacity(progress: collapseProgress))` to `headerBlock`; add `.scrollBounceBehavior(.basedOnSize, axes: .vertical)` (FR-013, research D8).
- [X] T008 [US1] US1 hygiene + a11y audit, same file: no unguarded animations added (the fade is un-animated direct tracking — correct per D6); zero style literals (only `CalendarStripFade` constants + existing `Spacing`/`Motion` tokens); confirm opacity-0 strip drops out of the accessibility tree (FR-015 unit-verifiable half; device half in T012); doc comment on `headerBlock` explaining the in-content placement (the WHY: reclaim space by layout, fade by compositor).

**Checkpoint**: US1 is a complete, shippable MVP — collapse works with no title.

---

## Phase 4: User Story 2 — compact date title (Priority: P2)

**Goal**: The selected day's label snap-fades into the inline nav bar at ≥80% collapse (Tiimo cross-fade; supersedes 001-FR-004).

**Independent Test**: Scroll to near-full collapse → title appears with a quick fade, wording identical to the app's day labels; disappears on the way back; nothing shown at rest (quickstart §US2).

- [X] T009 [US2] In `app-four/Views/Library/CalendarLibraryView.swift`: add `.toolbar { ToolbarItem(placement: .principal) { … } }` on the `Group` content — `Text(viewModel.dayLabel(for: selectedDay))` in `Typography.headline`, `NewLook.inkPrimary`; visibility via `let showsTitle = CalendarStripFade.showsTitle(progress: collapseProgress)` driving `.opacity(showsTitle ? 1 : 0)` + `.animation(reduceMotion ? nil : Motion.snappy, value: showsTitle)` (research D5, FR-005/006). Verify the principal item coexists with `ScreenContainer`'s empty `navigationTitle("")` (plan risk note) and that the empty-state branch never shows it (progress stays 0 — FR-012).
- [X] T010 [US2] Title accessibility, same file: `.accessibilityHidden(!showsTitle)` so VoiceOver only reaches it when visible (C11); confirm the label reads naturally ("Today, 16 Jul"); check AX-size truncation behavior (single line, no `minimumScaleFactor` hack — fix layout if it truncates to uselessness).

**Checkpoint**: full Tiimo cross-fade behavior complete.

---

## Phase 5: Polish & Cross-Cutting

- [ ] T011 [P] Docs: mark `specs/001-calendar-header-scroll-fade/spec.md` as superseded by 035 (header note, per this spec's supersession block); DESIGN.md motion section gains one line documenting the calendar collapse pattern (dead zone 24pt · height-scaled band · title reveal 0.8 — constants live on `CalendarStripFade`); DEVLOG entry + BACKLOG stage move (📐 Plan → 🔨 In code with branch/PR).
- [ ] T012 (OWNER GATE — no simulator) Device QA per `quickstart.md`: full US1 + US2 checklists, cross-cutting (120 Hz, dark mode, Reduce Motion, AX sizes, VoiceOver, push/pop + tab round-trip), and the three eyeball-flags (deep-scroll date-picker access, expand-mid-scroll opacity step, `.basedOnSize` bounce feel). C9–C12 of the contract close here.
- [ ] T013 Code review on the full diff (multi-agent per house practice); fix confirmed findings; re-run suite.
- [ ] T014 Open PR `feat/035-calendar-scroll-collapse → main` (one revertable feature); after merge: regen `docs/WORKLOG.md` (`scripts/worklog.sh`), BACKLOG → ✅ Shipped.

---

## Dependencies

```
T001 (merge gate)
  └─ T002 (RED) ─ T003 (GREEN)
        └─ T004 → T005 → T006 (parity) → T007 → T008   [US1 — all same file, serial]
              └─ T009 → T010                            [US2 — needs collapseProgress from T007]
                    └─ T011 [P] ─┐
                                 ├─ T012 (owner) → T013 → T014
                                 ┘
```

- US2 depends on US1's T007 (the progress state) — deliberate, spec-sanctioned coupling.
- Parallel opportunities are minimal by design: T004–T010 all edit `CalendarLibraryView.swift` (serial); only T011 (docs) can run alongside T009/T010.

## Implementation Strategy

**MVP = Phase 1–3 (T001–T008)**: ship-worthy collapse with no title; US2 is a 2-task increment on top. If device QA (T012) rejects the title feel, US2 reverts cleanly without touching US1. The math constants are owner-tunable on device without re-speccing (spec Assumptions) — expect T012 to possibly feed a one-line constant tweak back into T003's file (tests updated in lockstep).
