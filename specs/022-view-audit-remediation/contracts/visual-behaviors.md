# Phase 1 — Observable UI Contracts

This is a UI app; its "contracts" are user-observable behaviors. Each maps to a Functional Requirement and an acceptance scenario in [spec.md](../spec.md). These are the checks `/code-review` and the morning verification must satisfy.

## C1 — Detail toolbar parity (FR-001, FR-002)

- **Given** a saved check-in, opening its detail from **either** the Calendar tab or Insights, **then** the navigation bar shows the check-in date (`.principal`) and a Delete control (`.topBarTrailing`).
- Delete + confirm removes the recording and returns to the prior screen, from both entry points.
- The deletion guard (defer-until-disappear) still holds when a recording is removed out from under the open sheet.

## C2 — Chip Dynamic Type scaling (FR-003, FR-004)

- **Given** Dynamic Type at AX5, **then** mood/sleep/medication chip labels render scaled and legible; long labels wrap rather than clip.
- **Given** default size, chip appearance is pixel-unchanged from before.

## C3 — No debug surface in Release (FR-005, FR-006)

- **Given** a Release build, no internal test/diagnostic screen is reachable or compiled in.
- **Given** any build where a diagnostic screen is presentable, its Done control dismisses it.
- **Given** a Debug build, diagnostics still function.

## C4 — Behavior preservation after dead-code removal (FR-007, FR-008)

- Repo search for each removed file/symbol returns zero production references.
- Build + full test suite pass.
- Every existing user flow behaves identically (no visible change).

## C5 — Insights responsiveness (FR-011)

- **Given** a month with 100+ check-ins, paging through Insights sections stays smooth; month-derived analytics are not recomputed on every render.

## C6 — Modern idiom & polish (FR-012–FR-018)

- Tab bar uses the `Tab(value:)` builder; no deprecated `foregroundColor`/`Task.sleep(nanoseconds:)` remain in the touched files.
- Multi-line inputs show placeholder text; mutually-exclusive sheets use one selection value.
- Dark-mode secondary text meets WCAG AA (4.5:1 body).
- The extraction-review editor and day card have working previews (populated where relevant).
