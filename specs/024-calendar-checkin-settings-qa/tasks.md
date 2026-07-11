# Tasks: Calendar / Check-in / Settings — device QA round

**Branch**: `024-calendar-checkin-settings-qa` | **Spec**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md)

**Skill lenses applied**: swiftui-pro · swiftui-design-principles · swift-architecture (MV, align to
conventions) · swift-concurrency-pro · swift-accessibility. **swiftdata-pro = N/A** (no `@Model` change).

**Conventions**: `[P]` = parallelisable (different files, no dependency). `[US#]` = user story.
`[owner]` = run by the owner per [[feedback-no-sim-build]] (the agent writes code + tests + review;
the owner builds, runs the suite, and verifies on device — no simulator).

**Base branch**: cut `feat/024-calendar-checkin-settings-qa` from `feat/daycard-v8` — the QA was
recorded on the redesigned build and US3 edits `CalendarLibraryView`, which `daycard-v8` also
touches; basing here avoids a conflict. *(Tradeoff: stacks on unmerged work — rebase if v8 changes.)*

---

## Phase 1 — P1 fixes (ship first)

### US1 — Check-in crescent stays put on record (the core defect)

- [ ] **T001 [US1]** Anchor the crescent in [CheckInView.swift](app-four/Views/CheckIn/CheckInView.swift).
  Today idle (L132, `idleCrescent` 200) and `recordingStage` (L216, `recordingCrescent` 260) are
  **separate subtrees** with different surrounding layouts, so the centre jumps. Refactor to **one**
  `CrescentRing` anchored at a single fixed vertical centre (e.g. a root `ZStack`/overlay), its
  `.frame` size driven by `viewModel.state`, with the idle chrome (headline + Speak/Log-meds/Type-note)
  and the recording chrome (progress bar + prompt + timer/controls) laid out *around* the anchored
  crescent so its centre never moves. **Concurrency:** view stays `@MainActor`; no `Task`/async added.
  **A11y:** gate the size change `withAnimation(reduceMotion ? nil : Motion.smooth, value: state)`;
  keep `CrescentRing().accessibilityHidden(true)` and the timer live-region (L227-234) intact.
  *(swiftui-pro: one source of truth for the ring — delete the duplicate `CrescentRing` in the two
  branches. design-principles: a stable anchor avoids disorientation on state change.)*
- [ ] **T002 [US1] [owner]** Verify on device: tapping record does **not** move the crescent centre
  (SC-004); Reduce Motion → no grow; VoiceOver still reads "Recording, N elapsed".

### US2 — Remove the crashing feedback button

- [ ] **T003 [US2]** Remove `FeedbackButton()` at [SquirlApp.swift:39](app-four/App/SquirlApp.swift#L39)
  from the view tree. **Keep** `app-four/Views/Feedback/*` (FeedbackButton/IssueReportView/
  ScreenshotCapture) — unmount only (Principle-III exception, logged in plan).
- [ ] **T004 [US2]** Confirm no other `FeedbackButton` mount (grep) and the Feedback files remain (SC-005).

---

## Phase 2 — P2 calmer calendar (US3)

- [ ] **T005 [P] [US3]** [CalendarDayCell.swift](app-four/Views/Components/CalendarDayCell.swift):
  remove `.opacity(isAboveSelection ? Opacity.deEmphasis : 1)` (L36) and the `isAboveSelection`
  property (L11). Future days keep `.disabled(cell.isFuture)` (L39) **at full opacity**; keep the
  dropped-dot marker + the AX state `"future"` (L70) as the non-colour cue (FR-001/FR-011).
- [ ] **T006 [P] [US3]** [CalendarHeaderView.swift](app-four/Views/Components/CalendarHeaderView.swift):
  remove the "Today" `Button` (L75-77) and the `canJumpToToday` (L12) + `onJumpToToday` (L14) params
  (and their preview args L145/L147).
- [ ] **T007 [US3]** [CalendarLibraryView.swift](app-four/Views/Library/CalendarLibraryView.swift):
  delete `filterCaption` (L113-123) + its call (L84); drop the `canJumpToToday:`/`onJumpToToday:`
  args (L67/L69) and the `isAboveSelection:` arg at the day-cell call site. **Keep `jumpToToday()`**
  (still called on tab-entry, L50). *Depends on T005, T006 (signature changes).*

---

## Phase 3 — P2 settings (US4) — TDD

- [ ] **T008 [US4]** RED — [DayCardExpandStateTests.swift](app-fourTests/Views/DayCardExpandStateTests.swift):
  add `shouldExpandTruthTable` — `shouldExpand(d, alwaysExpand: false) == contains(d)`, and
  `== true` for any `d` when `alwaysExpand: true`. (Fails — method doesn't exist yet.)
- [ ] **T009 [US4]** GREEN — [ExpandedDayCards.swift](app-four/Views/Library/ExpandedDayCards.swift):
  add the pure value-method `func shouldExpand(_ date: Date, alwaysExpand: Bool) -> Bool { alwaysExpand || contains(date) }`.
  *(Concurrency: struct method is `nonisolated` by default — keep it that way so the test needs no
  `@MainActor`; Date/Bool are Sendable, no isolation concern.)*
- [ ] **T010 [US4]** [CalendarLibraryView.swift](app-four/Views/Library/CalendarLibraryView.swift):
  add `@AppStorage("alwaysExpandCards") private var alwaysExpandCards = false`; change the DayCard
  `isExpanded:` (L90) to `expandedCards.shouldExpand(day.date, alwaysExpand: alwaysExpandCards)`.
  *Depends on T009.*
- [ ] **T011 [P] [US4]** [DayCardSettingsSection.swift](app-four/Views/Settings/DayCardSettingsSection.swift):
  add `@AppStorage("alwaysExpandCards") private var alwaysExpandCards = false` + a `Toggle` with a
  `Label("Always expand cards", systemImage: …)` mirroring the auto-expand row. Native Toggle with
  visible text → **no** extra `.accessibilityLabel` (over-labelling hurts). Keep auto-expand (FR-009).
- [ ] **T012 [P] [US4]** [SettingsView.swift](app-four/Views/SettingsView.swift): remove the
  "Recognize medication names" `Toggle` (L166-167). Leave `Constants.medicalPromptEnabled` (defaults
  `true`) so extraction stays always-on (FR-007 — no extraction-logic change, Principle VII clean).

---

## Phase 4 — cross-cutting review & verification

- [ ] **T013** Concurrency pass (swift-concurrency-pro): confirm `shouldExpand` is pure/`nonisolated`,
  no `Task`/async introduced, `@AppStorage` reads stay view-`MainActor`. No `@unchecked Sendable`.
- [ ] **T014** Accessibility pass (swift-accessibility): future-day greyscale cue intact (dot + AX
  state, no opacity), calendar VoiceOver order sane after the removals, the new Toggle reads its
  visible label, crescent grow gated on Reduce Motion.
- [ ] **T015 [owner]** Build + full suite green + device QA across all four stories: light/dark,
  Dynamic Type, greyscale filter ([[feedback-no-sim-build]]).
- [ ] **T016** `/code-review` the diff → open PR (flag the retained-feedback Principle-III exception);
  owner approves/merges.

---

## Dependencies & parallelism

- **T001, T003** independent (P1) — can run first, in either order.
- **T005 ∥ T006** (different files) → then **T007** (consumes their new signatures).
- **T008 → T009 → T010**; **T011 ∥ T012** (different files), independent of T010.
- **T013/T014** after code lands; **T015/T016** last.
- Suggested order: **T001 → T003/T004 → T005/T006 → T007 → T008 → T009 → T010 → T011/T012 → T013/T014 → T015/T016.**
