# Implementation Plan: Calendar / Check-in / Settings — device QA round

**Branch**: `024-calendar-checkin-settings-qa` | **Date**: 2026-06-26 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/024-calendar-checkin-settings-qa/spec.md`

## Summary

A cross-view QA round from a narrated device recording. **Calendar:** stop fading days,
remove the "Today" button, remove the "Entries up to <day>" caption. **Check-in:** anchor
the crescent so tapping record grows it in place (no downward jump). **Settings:** remove
the "Recognize medication names" toggle (pin behaviour on), add an "Always expand cards"
preference, remove the crashing feedback button (keep its code). Architecture: the app is
**MV** (`@AppStorage` + the `@Observable` `ExpandedDayCards` value type); the new flag
mirrors the existing `autoExpandOnSelection` exactly — **no new abstractions** (Principle IV,
and the swift-architecture "align to local conventions, minimal" guidance).

## Technical Context

**Language/Version**: Swift 6 (strict concurrency) · **UI**: SwiftUI (iOS 26) ·
**Persistence**: none changed (settings via `@AppStorage`/`UserDefaults`) ·
**Testing**: Swift Testing, test-first per Principle X ·
**Workflow note**: per the owner's current rule ([[feedback-no-sim-build]]) the **owner**
builds, runs the suite, and verifies UI on a physical device; the agent delivers compiling
Swift + the tests + a `swiftui-pro` review (no simulator use by the agent).

## Constitution Check

*GATE — checked before Phase 0; re-confirm after Phase 1.*

- [x] **I. SwiftUI-First** — PASS. Edits to existing SwiftUI screens; no new screen needs an
      HTML mockup (the narrated device video is the visual reference; the new toggle reuses
      the existing Settings toggle pattern).
- [x] **II. Test-Build-Ship** — PASS (workflow-adjusted). Build + full suite + on-device QA
      run by the **owner** ([[feedback-no-sim-build]]); the agent ships compiling code, the
      tests, and a code review. No step ships unverified.
- [x] **III. Correctness Over Speed** — PASS with one justified exception: the feedback
      feature's files are **retained unmounted** at the owner's explicit request (see
      Complexity Tracking). All other removals delete the code, not just hide it.
- [x] **IV. Minimal Surface** — PASS. One new `@AppStorage` flag + one tiny testable helper;
      everything else is removal or a layout fix. No new protocols/services/VMs.
- [x] **V. Solo Git Discipline** — PASS. Own branch `feat/024-calendar-checkin-settings-qa`;
      `/code-review` before merge; one revertable feature.
- [ ] **VI. On-Device Privacy** — N/A. No data/logging change.
- [ ] **VII. Deterministic, Measured Extraction** — N/A. `medicalPromptEnabled` already
      defaults to `true`; pinning it on removes a control but changes **no** extraction
      logic, lexicon, or eval floors.
- [ ] **VIII. Service-Oriented Architecture** — N/A. No new capability; settings via the
      existing `@AppStorage` convention; no persistence logic added to any view.
- [ ] **IX. Pre-Release Data Posture** — N/A. No SwiftData schema change (`@AppStorage`).
- [x] **X. Test-First Development** — PASS. The only new logic — "is this day's card
      expanded?" given the always-expand flag — is extracted to a testable helper on
      `ExpandedDayCards` and built RED→GREEN. Views (crescent anchor, removals, the toggle)
      are exempt, verified by the owner on device.

**Result: PASS** — one justified exception (feedback code retained), in Complexity Tracking.

## Project Structure (files to change)

```text
app-four/Views/Components/
├── CalendarDayCell.swift        # FR-001: remove `.opacity(isAboveSelection ? deEmphasis : 1)`;
│                                #   drop `isAboveSelection` param; future days stay `.disabled`
│                                #   but at full opacity (FR-011 cue = disabled + dropped dot)
└── CalendarHeaderView.swift     # FR-002: remove the "Today" Button (L75-77) + `canJumpToToday`/
                                 #   `onJumpToToday` params

app-four/Views/Library/CalendarLibraryView.swift
                                 # FR-003: delete `filterCaption` (L112-126) + its use
                                 # FR-002: drop the canJumpToToday/onJumpToToday args (keep
                                 #   `jumpToToday()` — still called on tab-entry)
                                 # FR-008: add @AppStorage("alwaysExpandCards"); pass effective
                                 #   isExpanded = expandedCards.shouldExpand(day.date, alwaysExpand:)
                                 # FR-001: drop the `isAboveSelection:` arg at the day-cell call site

app-four/Views/CheckIn/CheckInView.swift
                                 # FR-004/5: anchor the crescent — one fixed-position container,
                                 #   size animates idle(200)↔recording(260) in place; idle
                                 #   secondaries + recording controls overlay the anchored centre

app-four/Views/SettingsView.swift           # FR-007: remove the "Recognize medication names" Toggle (L166-167)
app-four/Views/Settings/DayCardSettingsSection.swift
                                 # FR-008: add "Always expand cards" Toggle (@AppStorage,
                                 #   mirrors autoExpandOnSelection) ; FR-009: keep auto-expand
app-four/App/SquirlApp.swift     # FR-010: remove `FeedbackButton()` mount (L39); keep Views/Feedback/*

app-four/<ExpandedDayCards location>.swift  # add `shouldExpand(_:alwaysExpand:)` helper (test-first)
app-fourTests/Views/DayCardExpandStateTests.swift  # NEW test: always-expand override (RED→GREEN)
```

**Structure Decision**: existing MV layout; no new modules. The always-expand flag uses the
same `@AppStorage` shared-key pattern already proven by `autoExpandOnSelection`.

## Phase 0 — research.md (decisions, resolved)

- **Entries** → remove the single `"Entries up to <day>"` filter caption (owner-confirmed;
  no per-day count exists).
- **Always-expand precedence** → ON ⇒ all cards open; auto-expand-on-selection is moot.
- **Crescent anchor** → anchor at the **idle** centre; recording grows around it.
- **Medical prompt** → remove UI only; behaviour pinned on (default already `true`).
- **Feedback** → unmount `FeedbackButton()`; retain `Views/Feedback/*`.
- **Day-fade vs greyscale (FR-011)** → drop the opacity fade; future days remain
  non-interactive (`.disabled`) + keep the dropped-dot marker as the non-colour cue.

## Phase 1 — data-model / contracts

New/changed (testable) logic only:

```text
ExpandedDayCards.shouldExpand(_ date: Date, alwaysExpand: Bool) -> Bool   // alwaysExpand || contains(date)
@AppStorage("alwaysExpandCards") var alwaysExpandCards = false            // Settings toggle + Calendar read
```

Everything else is view-layer (no contract): crescent anchoring, the three removals, the
toggle row. Contract test maps FR-008 → `shouldExpand` truth table (false/contains/alwaysOn).

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Retain the `Views/Feedback/*` files while removing the button (Principle III — unused code) | Owner explicitly wants the feedback/DebugBridge capability kept for later re-enable; only the *mount* is the problem (crash). | Deleting the files would lose the issue-report + screenshot flow the owner intends to restore; unmounting is the minimal, reversible fix. |
