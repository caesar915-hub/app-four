# Implementation Plan: Mockup-Exact Visual Parity

**Branch**: `feat/screen-parity` | **Date**: 2026-06-17 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/008-mockup-parity/spec.md`

## Summary

Bring §04–§07 of the live app to **exact visual parity** with the Paper & Pollen mockup. Pure visual rework of existing screens: the mockup is the source of truth, unshown elements stay untouched, **no app logic changes**, and views reference **existing DesignSystem tokens only** (no literals). Baseline is the committed screen-parity work (`91b0fd0`); this refines it to pixel fidelity. The single sanctioned logic touch is an optional `MedEvent.durationHours` that backs the Edit-sheet duration box.

## Technical Context

**Language/Version**: Swift 6, SwiftUI (iOS 26 target)
**Primary Dependencies**: SwiftUI, SwiftData, Swift Concurrency; in-repo `DesignSystem/` tokens (`Theme`/`Palette`/`Typography`/`Spacing`/`Radius`) + `SignalGlyph`
**Storage**: SwiftData (`Recording`, `MedicationEvent`) — unchanged by this feature
**Testing**: Swift Testing (`@Test`/`#expect`), serial; on-simulator screenshot verification (iPhone 17 sim) via the ios-debugger-agent
**Target Platform**: iOS 26 (light + dark, Dynamic Type, Reduce Motion)
**Project Type**: Mobile app (single SwiftUI target `app-four` + `app-fourTests`)
**Performance Goals**: 60fps; no new heavy work (all changes are layout/style)
**Constraints**: Tokens-only in views (no literals); no logic/persistence/navigation change; preserve the full passing suite; match the mockup in light + dark
**Scale/Scope**: 6 screens / ~10 view files + 1 DTO field + 1 setter wiring + 1 new shared picker component

## Constitution Check

*GATE: passed before Phase 0; re-checked after Phase 1. See `.specify/memory/constitution.md` (v1.2.0).*

- [x] **I. SwiftUI-First** — PASS. SwiftUI on modern APIs; the **HTML mockup is the design source** (mockup-first satisfied by `squirl-design-system.html`).
- [x] **II. Test-Build-Ship** — PASS. Each screen is built, the full suite is run, and the screen is screenshot-verified before it's considered done.
- [x] **III. Correctness Over Speed** — PASS. The superseded segmented-picker / per-row Meds code is removed (no dead code); tokens replace literals; tradeoffs (token deltas, single-line Meds dropping per-dose detail) are surfaced in the spec.
- [x] **IV. Minimal Surface** — PASS. One shared `GlyphRampPicker` (DRY across Type-note + Edit), reuse of `.card()`/`.cardEyebrow()`/`Chip`/`FlowLayout`; one optional DTO field. No new flags or abstractions.
- [x] **V. Solo Git Discipline** — PASS. One revertable feature on `feat/screen-parity`; `/code-review` before merge; `main` untouched.
- [x] **VI. On-Device Privacy** — PASS. Purely visual; no data leaves the device; no new logging.
- [x] **VII. Deterministic, Measured Extraction** — N/A. No extraction/NLP change.
- [x] **VIII. Service-Oriented Architecture** — N/A. No new services; existing VMs are already `@MainActor @Observable`; no heavy work added.
- [x] **IX. Pre-Release Data Posture** — PASS. `MedEvent` is a Codable DTO (not a `@Model`); the added `durationHours` is **optional/defaulted** (decodes as nil when absent) — backward-compatible, no `@Attribute(.unique)`, CloudKit-safe. The SwiftData `MedicationEvent` already has `durationHours`.
- [x] **X. Test-First Development** — PASS. The only logic is `MedEvent.durationHours` + its `setMedicationEvents` wiring → covered by a Swift Testing test written RED→GREEN before the wiring. All other work is SwiftUI views (exempt; build + simulator verified).

**No violations → Complexity Tracking is empty.**

## Project Structure

### Documentation (this feature)

```text
specs/008-mockup-parity/
├── plan.md            # this file
├── research.md        # Phase 0 — token mapping + parity decisions
├── data-model.md      # Phase 1 — the one DTO touch (MedEvent.durationHours)
├── quickstart.md      # Phase 1 — build + screenshot verification per screen
├── contracts/
│   └── ui-parity.md   # Phase 1 — the mockup §→screen acceptance contract
└── tasks.md           # Phase 2 (/speckit-tasks)
```

### Source code (real paths touched)

```text
app-four/
├── DesignSystem/                      # referenced only (tokens) — not changed
│   ├── Theme.swift · Palette.swift · Typography.swift · Spacing.swift · Radius.swift
│   └── Card.swift (.card(), .cardEyebrow())
├── Views/
│   ├── ExtractionReviewView.swift     # US1 — Edit sheet (largest rework)
│   ├── RecordingDetailView.swift      # US2 — detail navbar/title/glyph row/cards order
│   ├── InsightsView.swift             # US6 — title + sleep chip (mostly done)
│   ├── CheckIn/
│   │   ├── TextCheckInComposer.swift  # US3 — Type-note Layout A
│   │   ├── CheckInView.swift          # US5 — 3 states (mostly done)
│   │   └── CrescentRing.swift         # US5
│   ├── Components/
│   │   ├── GlyphRampPicker.swift      # NEW — shared bare-glyph ramp (US1 + US3)
│   │   ├── ADHDSummarySection.swift   # US2 — Summary + single-line Meds card
│   │   ├── AudioPlayerView.swift      # US2 — gradient play + waveform
│   │   ├── PlaybackWaveformBars.swift # US2 — accent/hairline bars
│   │   └── MedicationBarView.swift    # US4 — §04 bar (mostly done)
│   └── Insights/*                     # US6 — readback + tokens
├── Services/NoteExtraction/NoteExtraction.swift   # MedEvent.durationHours (DTO field)
├── Models/Recording.swift             # setMedicationEvents per-med duration wiring
└── ViewModels/ExtractionReviewViewModel.swift     # dose/duration setters (name-keyed)

app-fourTests/
└── …/MedEventDurationTests.swift      # NEW — RED→GREEN for the duration wiring
```

**Structure Decision**: Single SwiftUI app target. All work lands in `app-four/Views/**` (visual) plus one DTO field (`NoteExtraction.swift`), one setter wiring (`Recording.swift`), and one VM setter group (`ExtractionReviewViewModel.swift`). Tokens in `DesignSystem/` are **referenced, not modified** (owner's "map to existing tokens" decision).

## Phase 0 — Research

See [research.md](research.md). Key decisions resolved: (1) token-mapping table (mockup px → existing `Radius`/`Typography`/`Spacing`), (2) one shared `GlyphRampPicker` reused by Type-note + Edit, (3) `Grid` for the inline-expand label column (no magic widths), (4) per-med duration via an optional DTO field + name-keyed setters (avoids the value-equality stale-capture bug), (5) screenshot-verification method (temporary root-swap harness, reverted). No `NEEDS CLARIFICATION` remain.

## Phase 1 — Design & Contracts

- [data-model.md](data-model.md) — the single entity touch (`MedEvent.durationHours`) and its flow to `MedicationEvent.durationHours`.
- [contracts/ui-parity.md](contracts/ui-parity.md) — the UI contract: each mockup section → the screen that must match it, as the screenshot-diff acceptance bar.
- [quickstart.md](quickstart.md) — how to build + screenshot-verify each screen (light + dark) and run the suite.
- Agent context: `CLAUDE.md` SPECKIT marker repointed to this plan.

**Post-design Constitution re-check**: still PASS — no new abstractions emerged; the design stays within existing tokens/components + one optional DTO field.

## Complexity Tracking

*No constitution violations — no entries.*
