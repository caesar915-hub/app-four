---
description: "Task list for Calendar Header Scroll-Fade"
---

# Tasks: Calendar Header Scroll-Fade

**Input**: Design documents from `/specs/001-calendar-header-scroll-fade/`

**Prerequisites**: plan.md, spec.md, research.md, contracts/scroll-fade-interaction.md, quickstart.md

**Tests**: INCLUDED — the spec names existing calendar tests as the regression baseline and quickstart requests a focused unit test for the opacity mapping. The opacity function is implemented as a pure, testable unit.

**Organization**: Grouped by user story (US1 P1, US2 P2, US3 P2) for independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no incomplete dependencies)
- **[Story]**: US1 / US2 / US3 (Setup, Foundational, Polish carry no story label)

## Path Conventions

Single SwiftUI target. Source under `app-four/`, tests under the existing test target (`app-fourTests/`).

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Branch + baseline verification before touching code.

- [ ] T001 Create branch `fix/calendar-header-scroll-fade` off `main`.
- [ ] T002 Establish the green baseline: build the `app-four` scheme on an iPhone simulator and run the full suite **serially** (`-parallel-testing-enabled NO`) via `ios-debugger-agent`; record the passing count so regressions are detectable.
- [ ] T003 Seed mock data (Debug → Mock Mode → Seed) so the Calendar timeline spans more than one viewport height for manual validation.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: The pure opacity primitive that every story depends on. MUST complete before US1.

- [ ] T004 Add a pure, testable opacity function `headerOpacity(scrollOffset:headerHeight:)` returning `clamp(1 - offset/height, 0, 1)` (guard `height <= 0` → return 1.0) — implement as a `private static` helper on `CalendarLibraryView` (or a small free function in the same file) in [app-four/Views/Library/CalendarLibraryView.swift](../../app-four/Views/Library/CalendarLibraryView.swift). Implements contract C1–C3, C15.

**Checkpoint**: Opacity primitive exists and is unit-testable.

---

## Phase 3: User Story 1 — Timeline reads cleanly while scrolling (Priority: P1) 🎯 MVP

**Goal**: Header moves into the scroll content and fades to nothing as the user scrolls up; no row is ever occluded; nothing replaces the header.

**Independent Test**: Open Calendar with several days seeded, scroll up past the header height — header fades in step with scroll, no content is occluded, nothing replaces it once gone (quickstart steps 1–3, 7).

- [ ] T005 [US1] Move `CalendarHeaderView` + the trailing `Divider` out of the pinned `VStack` (currently [CalendarLibraryView.swift:27-44](../../app-four/Views/Library/CalendarLibraryView.swift#L27-L44)) and into `timelineList`'s `LazyVStack` as its first child, above the `ForEach(viewModel.timelineDays)`. Keep all existing `CalendarHeaderView` props/callbacks wired identically. (FR-001, FR-002, C8)
- [ ] T006 [US1] Add `@State private var scrollOffset: CGFloat = 0` and observe it via `.onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y } action: { _, new in scrollOffset = new }` on the internal `ScrollView` in `timelineList`. (R2, FR-011)
- [ ] T007 [US1] Measure the header's natural height into `@State private var headerHeight: CGFloat` using `.onGeometryChange`/background `GeometryReader` on the header block, so the fade completes exactly as the header clears (handles week vs expanded-month vs AX-text heights). (R2, edge cases)
- [ ] T008 [US1] Apply `.opacity(Self.headerOpacity(scrollOffset: scrollOffset, headerHeight: headerHeight))` uniformly to the header+divider block (single modifier on the wrapping container so all elements share opacity — no per-element staggering). (FR-003, FR-004, C4, C7)
- [ ] T009 [US1] Verify the medication bar (provided by `ScreenContainer`'s `.medicationBarOverlay`) and `.edgeFadeMask` on the list remain in place and are not moved into or affected by the header changes. (FR-008, FR-009, C16)
- [ ] T010 [P] [US1] Add `CalendarHeaderScrollFadeTests` in the test target asserting the opacity mapping: offset 0 → 1.0, offset == height → 0.0, offset == height/2 → ~0.5, monotonic non-increasing across a sweep, negative/over-height clamps to [0,1]. (C1–C3, C15)
- [ ] T011 [US1] Build + run the suite serially; manually validate quickstart steps 1–3 and 7 on simulator (collapsed week and expanded month). (SC-001, SC-002, II)

**Checkpoint**: US1 is a shippable MVP — the occlusion bug is fixed and the header fades to nothing. (US2 recovery still relies on manual scroll-up, which already works via the offset mapping.)

---

## Phase 4: User Story 2 — Recover the header and change days after scrolling (Priority: P2)

**Goal**: After the header has faded, a status-bar tap (and scrolling back up) restores it to full visibility and interactivity; the day row stays tappable until faded.

**Independent Test**: From a faded state, tap the status bar → header animates back to full opacity and is tappable; day taps register while the header is partially visible (quickstart steps 4–6).

- [ ] T012 [US2] Gate header interaction with `.allowsHitTesting(opacity > 0.05)` so day taps register while partially visible but an invisible header never intercepts taps. (FR-005, C6)
- [ ] T013 [US2] Confirm the scroll-up recovery path: because opacity is offset-driven (T006/T008), scrolling back to the top already restores the header — verify no extra code is needed and the resting opacity is exactly 1.0 at offset 0. (FR-006, C9)
- [ ] T014 [US2] Wire status-bar-tap-to-top for the internal `ScrollView`: give it a `ScrollPosition` and verify the system status-bar tap scrolls it to top. If the OS tap does not reach the inner scroll view, mirror `ScreenContainer`'s `scrollResetToken` → `scrollPosition.scrollTo(edge: .top)` pattern locally, animated with `withAnimation(reduceMotion ? nil : Motion.smooth)`. (FR-006, FR-012, C10, R4)
- [ ] T015 [P] [US2] Extend `CalendarHeaderScrollFadeTests` to assert the interactivity threshold flips at opacity 0.05. (C6)
- [ ] T016 [US2] Build + run suite serially; manually validate quickstart steps 4–6 and 11 (Reduce Motion). (SC-003, FR-012)

**Checkpoint**: Header is recoverable and day-selectable throughout the fade; the "fade to nothing" decision is safe for real use.

---

## Phase 5: User Story 3 — Day selection stays in sync while scrolling (Priority: P2)

**Goal**: The existing two-way scroll↔selection sync is preserved unchanged after the header moves into the scroll content.

**Independent Test**: Scroll the timeline → selected day tracks topmost visible day; tap a day → timeline scrolls to it; "Today" → scrolls to today + week-collapse (quickstart steps 1, 4, and "Today" edge case).

- [ ] T017 [US3] Verify `.scrollPosition(id: $topDayID, anchor: .top)` and `onChange(of: topDayID) → selectedDay` still behave correctly now that the header (un-`.id`'d) is the first `LazyVStack` child — confirm the at-rest top day still equals the first timeline day. (FR-007, C11, R5)
- [ ] T018 [US3] Verify `selectDay`/`scrollList`/`jumpToToday`/`pageMonth` still scroll to the right day and that "Today" ends with `headerOpacity == 1` (because it scrolls to top). (FR-007, C12, C13)
- [ ] T019 [P] [US3] Run the existing calendar day-selection + scroll-sync tests; if header placement shifted any anchor assumption, update assertions to reflect the in-scroll header (no behavior change, only structural). (SC-004)
- [ ] T020 [US3] Build + run suite serially; manually re-confirm quickstart steps 1, 4, and the "Today" pill behavior. (SC-004)

**Checkpoint**: No sync regression; all three stories integrated.

---

## Phase 6: Polish & Cross-Cutting Concerns

- [ ] T021 [P] Validate degenerate content: empty calendar shows a full, non-fading header (FR-010, C14); a short (sub-viewport) timeline rests the header at full opacity, never stuck mid-fade (SC-006, C15) — quickstart steps 9–10.
- [ ] T022 [P] Validate accessibility large-text (force-week) header fades correctly with its taller measured height — quickstart step 12.
- [ ] T023 [P] Validate medication-bar independence: repeat the fade with the bar shown and hidden; confirm the bar's frame/appearance is pixel-identical before vs after (SC-005, C5, C16) — quickstart step 8.
- [ ] T024 Run `/code-review` on the diff; address findings.
- [ ] T025 Add a `docs/DEVLOG.md` checkpoint entry (the why: occlusion fix via in-scroll header + offset-driven fade, "nothing replaces it" product decision, scroll-to-top recovery) and move the `docs/BACKLOG.md` row from 📐 Plan/idea to 🔨 In code with the branch/PR.
- [ ] T026 Open the PR; ensure the suite is green serially on the branch before requesting merge (II, V).

---

## Dependencies & Execution Order

- **Setup (T001–T003)** → blocks everything.
- **Foundational (T004)** → blocks US1 (opacity primitive).
- **US1 (T005–T011)** → MVP; depends on T004. Delivers the core fix alone.
- **US2 (T012–T016)** → depends on US1 (needs the in-scroll header + offset opacity).
- **US3 (T017–T020)** → depends on US1 (header moved); independent of US2.
- **Polish (T021–T026)** → after US1–US3.

US2 and US3 both build on US1 but are independent of each other and may be done in either order (or in parallel by a careful single editor, since they touch the same file).

## Parallel Opportunities

- T010, T015, T019 ([P]) are test-writing tasks in the test file — parallelizable with each other and with sibling impl tasks once their target behavior exists.
- T021, T022, T023 ([P]) are independent validation passes.
- Note: most impl tasks touch the single file `CalendarLibraryView.swift`, so they are **not** mutually [P] despite being small — sequence them to avoid edit conflicts.

## Implementation Strategy

**MVP = Phase 1 + Phase 2 + Phase 3 (US1).** That alone fixes the reported occlusion bug and delivers the fade-to-nothing. Ship-or-demo checkpoint after T011. Then layer US2 (recovery safety) and US3 (sync regression guard), then polish.
