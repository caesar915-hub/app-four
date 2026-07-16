# Quickstart — Validating the App-Wide New Look Migration

Runnable validation for each slice. Owner builds/QAs on device (no simulator). Repo root = `app-four-spm` worktree.

## Prerequisites

- Green baseline on `feat/033-newlook-app-wide` (branched from the spec-032 New Look foundations): `swift build --package-path Packages/SquirlDesignSystem` + full app suite pass before any change (Constitution II).

## Per-PR validation

### PR-0 Foundations (invisible)
- Build the design package — clean.
- Confirm `NewLook.tintNeutral` exists (light `#ECEAE6`) and `.newLookCard()` uses the 2-layer shadow.
- Visual diff: **nothing changes on screen yet** (no consumer switched).

### PR-1 The Look
- **Grep gate** (migrated files only): no residual `Theme.background|Theme.cardBackground|Theme.elevatedBackground|\.card(` in the PR-1 files.
- Build + full suite green (`DayCardPaletteTests` updated to `NewLook.card`).
- **Device QA, light + dark, default + one accessibility text size**, against contract [newlook-appwide.md](contracts/newlook-appwide.md):
  - S1 sage ground on every tab (Calendar, Check-in, Insights, Settings) + sheets; nav bar matches.
  - S2 every card borderless white r20 with the 2-layer shadow; no bordered r16 card left.
  - S3 grooves (gauges, mini-bars, dose track, level bars) visible in `tintNeutral` on white.
  - S8 tab bar reads as sage ground, not floating system material.
  - X5 Recording detail + Edit check-in unregressed.

### PR-2 Ink
- **Grep gate**: no `Theme.textPrimary|Theme.textSecondary` outside semantic use across migrated files.
- Device QA: S4/S5 primary/secondary ink everywhere; S7 selection green; semantic text (danger warm clay, status, medication) intact; contrast holds light + dark.

### PR-3 Cleanup
- **Full-repo grep gate** (incl. `SandboxApp/`, tests): zero refs to the 8 deleted `Theme` surface/ink tokens + `.card(` → then delete them from `Theme.swift`/`Card.swift`.
- Clean rebuild (Clean Build Folder + DerivedData) — compiles; full suite green.

## Med-bar behaviour (FR-009 — US3)

**Test-first (Constitution X):** add a RED case to `MedicationBarViewModelTests` — with `debugMockMode = true`, a dose created via `logManualDose` is present in `activeDoses` (currently fails: `isMockData == false` is filtered out). Set `debugMockMode` explicitly in the test (it is unregistered under XCTest). Then implement the `isMockData` tag → GREEN.

**Device check:** in the app's running mode, log a dose whose window includes now → it appears in the bar; let it elapse / delete it → it disappears; the seeded demo doses still behave; toggling the visibility setting off hides the bar (contract M4).

## Acceptance gates

- SC-001 every screen sage + borderless cards (owner walkthrough) · SC-002 zero deleted-token refs · SC-003 zero style literals on migrated screens · SC-004 logged dose visible + test green · SC-005 full suite green + flow parity · SC-006 device QA light+dark, default+AX, no blocking finding.
- Each PR: `/code-review` on the diff before merge; owner device-QA sign-off is the merge gate.
