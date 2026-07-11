# Quickstart — Validation Guide

How to verify each story end-to-end. Build/test via the Xcode MCP (`mcp__xcode__BuildProject` / `RunAllTests`, tab `windowtab1`) since the CLI build is blocked by a `safe.bareRepository` git-config quirk in the SwiftPM cache.

## Prerequisites

- Clean working tree on `fix/022-view-audit-remediation` (the `feat/spm-designsystem` WIP committed or stashed first — see plan Constraints).
- Booted iOS 26.5 simulator (iPhone 17); Xcode project open (`windowtab1`).

## Per-story checks

**US1 — toolbar parity**
1. Run app. Create/seed a check-in.
2. Open it from the **Calendar** tab → confirm date title + Delete appear; Delete works.
3. Open the same from **Insights** → identical toolbar. (Regression guard: no double nav bar.)

**US2 — AX5 chips**
1. `RenderPreview` `Views/Components/TimelineChip.swift` with Dynamic Type override **AX 5** → labels are large and unclipped (compare against the pre-fix capture in the design-review report).
2. Default size render is unchanged.

**US3 — debug fence**
1. Build the **Release** configuration → succeeds with no `Test*` views compiled (grep the build or confirm via `#if`).
2. In a Debug build, open diagnostics → Done dismisses.

**US4 — dead code**
1. `grep -rn` each removed symbol/file across `app-four/` + `app-fourTests/` → zero production refs.
2. `BuildProject` + `RunAllTests` → green (incl. retargeted `ProcessingViewModelTests`).
3. Smoke the app: recording detail, summary, audio playback, calendar, insights, settings — unchanged.

**US5 — Insights perf + idiom**
1. Seed a month with 100+ recordings; page through Insights → smooth, no stutter.
2. Switch tabs → correct selection under `Tab(value:)`.

**US6 — polish**
1. Dark mode: secondary text contrast ≥ 4.5:1 (check the previously-flagged subtitle).
2. `RenderPreview` `ExtractionReviewView` and a populated `DayCard`/Insights preview → render.
3. Feedback/text-check-in inputs show placeholder text.

## Gate

Each story: `BuildProject` clean + `RunAllTests` green before moving on. The full suite green is the "done" bar (constitution II). No merge to `main` — open a PR and run `/code-review`.
