# Implementation Plan: Medication Bar Consistency

**Branch**: `feat/feedback-specs` (Spec Kit feature `002-medication-bar-consistency`) | **Date**: 2026-06-15 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/002-medication-bar-consistency/spec.md`. Provenance: `docs/superpowers/2026-06-15-screen-recording-feedback-plan.md` §1.5, §2.1, §4.3, §4.4 and the "Decisions — resolved 2026-06-15" section. **The fade-under-the-bar item (§1.3) was removed from scope** — it is covered by `fix/calendar-header-scroll-fade`.

## Summary

Make the medication bar a single, fixed, fully-interactive anchor across every screen that shows it. Three coordinated changes, all presentation/interaction only, no schema change:

1. **Tap target (§2.1, P1)** — give the dose-row button label a hit-testable shape so the whole `maxWidth: .infinity × height` frame opens the menu, not just the opaque sub-views. The row label is a `ZStack` of a partial-width progress `Rectangle` and two pinned `Text`s with no `.contentShape`, so the empty middle isn't hit-tested. Fix is a `.contentShape(Rectangle())` on the row label in [`MedicationBarView.doseRow`](../../app-four/Views/Components/MedicationBarView.swift) (~L56–92).
2. **Fixed/consistent position (§4.4, P2)** — the bar is placed via `safeAreaInset(edge: .top)` in [`MedicationBarOverlay`](../../app-four/DesignSystem/MedicationBarOverlay.swift) (~L18). On a pushed nav stack the nav bar displaces it. Standardise the top chrome so the bar lands identically on every surface; audit the three call sites ([`CalendarLibraryView`](../../app-four/Views/Library/CalendarLibraryView.swift) ~L26, [`InsightsView`](../../app-four/Views/InsightsView.swift), [`RecordingDetailView`](../../app-four/Views/RecordingDetailView.swift) ~L36).
3. **Recording detail as a sheet (§4.3, P2)** — replace the `navigationDestination(for: UUID.self)` push ([`CalendarLibraryView`](../../app-four/Views/Library/CalendarLibraryView.swift) ~L50–53; mirrored in `InsightsView` ~L38) with a sheet presentation so the system back chevron disappears, the detail dismisses by swipe-down, and the bar stays fixed. Verify the selection/deep-link path still resolves the recording.
4. **One spacing token (§1.5, P3)** — define a single "below the medication bar" spacing token and apply it everywhere the bar sits above scroll content (calendar, insights, recording detail), so the gap to the first card is identical per screen. The bar's own insets live in [`MedicationBarOverlay`](../../app-four/DesignSystem/MedicationBarOverlay.swift) (~L21–22); per-screen top padding (e.g. [`CalendarLibraryView`](../../app-four/Views/Library/CalendarLibraryView.swift) ~L74) is unified against it.

**Technical approach**: pure SwiftUI view-layer work — a `contentShape` on the dose row, a shared `Spacing` token for the below-bar gap, standardised top chrome so the bar's position is identical per screen, and a presentation swap from push to sheet for the recording detail. No services, no view models' persistence logic, no model changes.

## Technical Context

**Language/Version**: Swift 6 (strict concurrency enabled)

**Primary Dependencies**: SwiftUI (iOS 26+), SwiftData (unchanged here), Swift Concurrency

**Storage**: SwiftData — no change. The bar's content derives from existing active-dose records; this feature touches no persisted attributes.

**Testing**: Swift Testing (`@Test`/`#expect`, unit + layout/interaction assertions); XCUITest for the cross-screen navigation/position flow

**Target Platform**: iOS 26+ (iPadOS secondary)

**Project Type**: mobile-app (single iOS target `app-four`, module `app-four`, display name **Squirl**)

**Performance Goals**: 60 fps scrolling; bar tap registers within one frame; no per-frame layout thrash from any cross-screen position measurement

**Constraints**: on-device only; no UIKit unless SwiftUI has no equivalent; below-bar spacing must be Dynamic Type-safe (preserved as the bar grows); the floating glass appearance is retained

**Scale/Scope**: three screens (calendar, insights, recording detail); ~four view/design-system files modified; no new models, no new services

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Marked PASS / N-A against `.specify/memory/constitution.md`. No FAILs — Complexity Tracking is empty.

- [x] **I. SwiftUI-First** — PASS. All work is SwiftUI on iOS 26+ APIs (`contentShape`, `safeAreaInset`, `.sheet`); no UIKit, no shims. Per the constitution's "new views start as an HTML mockup," the changed UI — the sheet-presented detail and the fixed-bar chrome — is a visual change and MUST have an HTML mockup approved before SwiftUI implementation; this is sequenced as a blocking precursor task in Phase 1 (see Project Structure note).
- [x] **II. Test-Build-Ship** — PASS. The plan ends in a buildable change with build + full test suite green via `ios-debugger-agent` (XcodeBuildMCP), including a new hit-testing test, a below-bar spacing assertion, and a cross-screen bar-position UI test. No step ships unverified.
- [x] **III. Correctness Over Speed** — PASS. The change fixes real defects (dead tap zones, per-screen position/spacing drift, a back chevron over the bar) rather than layering over them; no compat shims or stubs; the push→sheet tradeoff is surfaced in research.
- [x] **IV. Minimal Surface** — PASS. One `contentShape`, one shared spacing token, standardised top chrome, one presentation swap. No new abstractions, protocols, or feature flags.
- [x] **V. Solo Git Discipline** — PASS. One revertable feature on `feat/feedback-specs` (off `main`), `/code-review` before merge, `main` stays releasable. (Note: this branch also carries sibling feedback specs as docs; the code change for this feature is a self-contained slice.)
- [x] **VI. On-Device Privacy** — PASS. No audio/health/mood/medication data leaves the device; no network, no cloud, no new logging. Purely view-layer presentation.
- [x] **VII. Deterministic, Measured Extraction** — N-A. The NLP extraction pipeline (`NLNoteExtractor`, lexicon) is untouched.
- [x] **VIII. Service-Oriented Architecture** — PASS. No new external capability and no new service; existing `@MainActor @Observable` view models keep their roles and hold no persistence logic.
- [x] **IX. Pre-Release Data Posture** — PASS. No schema change: no entities added, no attributes added/changed, no `@Attribute(.unique)`, no required attribute. CloudKit compatibility is preserved unchanged. See [data-model.md](./data-model.md).

## Project Structure

### Documentation (this feature)

```text
specs/002-medication-bar-consistency/
├── plan.md              # This file
├── spec.md              # Feature specification (WHAT/WHY)
├── research.md          # Phase 0 decisions + rejected alternatives
├── data-model.md        # Phase 1 — confirms NO schema change
├── quickstart.md        # Phase 1 — manual validation + automated tests + build gate
└── tasks.md             # Phase 2 (/speckit-tasks — NOT created here)
```

No `contracts/` directory: this is an on-device UI feature with no external API or network surface. The behavioural contract is the spec's acceptance scenarios.

### Source Code (repository root)

```text
app-four/                                         # Xcode target & module (display name: Squirl)
├── Views/
│   ├── Components/
│   │   └── MedicationBarView.swift               # MODIFY — contentShape on doseRow label so the whole row is tappable (§2.1)
│   ├── Library/
│   │   └── CalendarLibraryView.swift             # MODIFY — push→sheet for detail (§4.3); apply shared below-bar spacing token (§1.5)
│   ├── InsightsView.swift                        # MODIFY — push→sheet for detail; audit bar placement (§4.3, §4.4)
│   └── RecordingDetailView.swift                 # MODIFY — present as sheet; ensure bar fixed, no back chevron (§4.3, §4.4)
├── DesignSystem/
│   ├── MedicationBarOverlay.swift                # MODIFY — standardise top chrome so bar position is identical everywhere (§4.4)
│   └── Spacing.swift                             # MODIFY/REUSE — add/define the single "below-the-bar" spacing token (§1.5)
└── (bar content source: existing active-dose records — REUSE, unchanged)

app-fourTests/                                    # Unit/integration tests (Swift Testing)
└── (NEW) bar hit-testing + below-bar spacing assertions

app-fourUITests/                                  # UI flow tests (XCUITest)
└── (NEW) cross-screen bar-position + sheet-dismiss flow

docs/superpowers/plans/                           # HTML mockup (NEW, Principle I precursor) for the
                                                  #   sheet detail + fixed bar (before SwiftUI)
```

**Structure Decision**: Single iOS app target (`app-four`). All changes live under `app-four/Views/**` and `app-four/DesignSystem/**`, with tests under `app-fourTests/` and `app-fourUITests/`. The exact `Spacing.swift` token name/value and the precise file names for the new tests are settled in Phase 1 / tasks; paths above reflect the real repository layout verified against the cited files.

## Complexity Tracking

> No Constitution Check violations — this table is intentionally empty.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| — | — | — |
