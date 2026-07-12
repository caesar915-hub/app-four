# Implementation Plan: App-Wide New Look — Complete the Migration

**Branch**: `feat/033-newlook-app-wide` | **Date**: 2026-07-11 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/033-newlook-app-wide/spec.md`

## Summary

Finish the New Look migration that spec-032 started: make the sage-ground / borderless-white-card language the **single** visual system across every screen, re-skin the medication bar onto it, fix the defect where real logged doses are hidden, and delete the now-dead Paper & Pollen surface/ink tokens. The approach is **call-site migration, not token aliasing** — the New Look card is a *shape* change (bordered radius-16 `.card()` → borderless radius-20 `.newLookCard()`), which a colour alias cannot produce, and Constitution III forbids compat shims. The token layer gains exactly one new colour (`NewLook.tintNeutral = #ECEAE6`, the Figma `tint/neutral` groove token) plus a two-layer card shadow to reach 1:1 Figma parity (verified live against file Squil-Design). Delivery is **slice-first across four PRs** (Foundations → The Look → Ink → Cleanup), keeping `main` releasable. Everything is visual except one logic fix — `logManualDose` tags the dose to the active `isMockData` partition — which is built **test-first** (Constitution X).

## Technical Context

**Language/Version**: Swift 6 (strict concurrency), SwiftUI, iOS 26 deployment target

**Primary Dependencies**: `SquirlDesignSystem` local SPM package (tokens/`NewLook`/`Theme`/card modifiers); app target `app-four`; `MedicationBarViewModel` (`@MainActor @Observable`) + `MedicationEvent` (`@Model`) for the FR-009 fix only

**Storage**: SwiftData. **No schema change.** The only data-path touch is FR-009: `MedicationBarViewModel.logManualDose` sets the existing `MedicationEvent.isMockData` flag to the active mode (the Constitution-IX partition), so a dose logged in the current mode is visible in it.

**Testing**: Swift Testing (`@Test`/`#expect`). New RED test in `MedicationBarViewModelTests` for FR-009 (logic, test-first). All other work is view re-skin → verified by build + owner device run (Principle X exemption). Existing VM suites (`MedicationBarViewModelTests`, `RecordingDetailViewModelTests`, `ExtractionReviewViewModelTests`) are the regression gate.

**Target Platform**: iOS 26+, iPhone (iPhone 12 / A14 class floor)

**Project Type**: Native iOS app (mobile) + local SPM design-system package

**Performance Goals**: None new — static token/modifier swap; render/scroll parity with current screens

**Constraints**: On-device only (VI, unaffected); zero style literals on migrated screens (FR-011); light + dark from day one (FR-012); `main` releasable each PR (V); the two spec-032 screens verify-only (FR-013); Calendar timeline stays gated on spec-029 (FR-018)

**Scale/Scope**: ~14 production view/component files migrated + `RootTabView` tab-bar appearance + `FeedbackButton` + 1 VM (FR-009) + 1 new token + 2-layer shadow + `DayCardPaletteTests` update + `SandboxApp/` + a token-deletion pass. Two screens (`RecordingDetailView`, `ExtractionReviewView`, `ADHDSummarySection`) are verify-only.

## Constitution Check

*GATE: passed before Phase 0; re-checked after Phase 1 (below). Constitution v1.2.0.*

- [x] **I. SwiftUI-First** — pure SwiftUI, modern APIs. **Mockup gate**: the binding Figma a-screens (token-bound, QA'd) satisfy it for the mechanical colour/card swap; the two surfaces whose card *shape* changes non-trivially (Insights cards, Settings rows) get a Figma mockup before code, or Settings takes the recolour-only default (research D7). The one UIKit touch — a `UITabBarAppearance`/`UINavigationBarAppearance` for the sage tab bar — is permitted (no SwiftUI-only equivalent for global bar material on iOS 26) and isolated (D5).
- [x] **II. Test-Build-Ship** — every PR ends on build-green + full-suite-green + owner device QA; no increment ships unverified.
- [x] **III. Correctness Over Speed** — **strengthens** compliance: migrate-not-alias avoids a shim, and the final PR *deletes* the dead Paper & Pollen surface/ink tokens (FR-017). No stubs, no half-states.
- [x] **IV. Minimal Surface** — exactly one new token (`tintNeutral`); no runtime theme system, no feature flag, no abstraction layer. Complexity table empty.
- [x] **V. Solo Git Discipline** — four small revertable PRs on `feat/033-newlook-app-wide`, each `/code-review`'d, `main` releasable throughout; the interim mixed look between PRs is already sanctioned by spec-032 FR-010.
- [x] **VI. On-Device Privacy** — visual + one local data-tagging fix; no network, no logging of medication content, nothing leaves the device.
- [N/A] **VII. Deterministic, Measured Extraction** — no extraction/NLP code in scope.
- [x] **VIII. Service-Oriented Architecture** — no new service/capability; `MedicationBarViewModel` stays `@MainActor @Observable`; the FR-009 change is a one-line tag inside an existing method, no new seam.
- [x] **IX. Pre-Release Data Posture** — **aligns with** IX: it uses the `isMockData` partition exactly as the constitution prescribes ("mock vs real partitioned by `isMockData`"). No schema change, no `@Attribute(.unique)`, no new required attribute; CloudKit-compatibility untouched.
- [x] **X. Test-First Development** — the sole logic change (FR-009) is written RED→GREEN in `MedicationBarViewModelTests` before implementation; all re-skin work is SwiftUI-view-exempt (build + device run). Tasks MUST order the test before the fix.

**Result: PASS, no violations.** Complexity Tracking intentionally empty.

## Project Structure

### Documentation (this feature)

```text
specs/033-newlook-app-wide/
├── spec.md                      # complete (0 clarifications)
├── plan.md                      # this file
├── research.md                  # Phase 0 — D1–D10 decisions
├── data-model.md                # Phase 1 — token deltas + the one data touch
├── quickstart.md                # Phase 1 — per-PR validation / device-QA guide
├── contracts/
│   └── newlook-appwide.md       # Phase 1 — surface + med-bar behavioural contract
├── checklists/
│   └── requirements.md          # spec quality checklist (all pass)
└── tasks.md                     # Phase 2 — /speckit-tasks (NOT created here)
```

### Source Code (repository root = `app-four-spm` worktree)

```text
Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/
├── NewLook.swift        # EDIT — add `tintNeutral` (light #ECEAE6 + derived dark); 2-layer shadow on .newLookCard(); fix stale doc comment naming RecordingRow/MedicationBarView as .card() consumers
├── Card.swift           # EDIT (final PR) — delete `.card()` + cardStroke path once no consumers remain; cardEyebrow ink
├── Theme.swift          # EDIT (final PR) — delete surface/ink tokens (background, cardBackground, surface2, elevatedBackground, textPrimary, textSecondary, separator, cardStroke); KEEP accent/meadow/status/danger/gradient
└── Radius.swift         # UNCHANGED (newLookCard = 20 already present, spec-032 T002)

app-four/DesignSystem/
└── ScreenContainer.swift        # EDIT (PR1) — background + toolbarBackground → NewLook.screen (flips every tab)

app-four/Views/                  # EDIT — per-cluster (PR1 surfaces, PR2 ink):
├── RootTabView.swift            # EDIT (PR1) — add sage/white tab-bar appearance (D5)
├── Components/{DayCard,RecordingRow,TimelineBead,Chip,MedicationBarView,MedicationLogSheet}.swift
├── Insights/{SignalAverageGauges,ConnectionCardsView,...}.swift
├── Settings/{…}.swift · SettingsView.swift
├── CheckIn/{CheckInView,TextCheckInComposer}.swift
├── Onboarding/WelcomeView.swift
├── Feedback/FeedbackButton.swift  # EDIT (PR1) — .ultraThinMaterial → NewLook.card
├── RecordingDetailView.swift · ExtractionReviewView.swift · Components/ADHDSummarySection.swift  # VERIFY-ONLY (FR-013)

app-four/ViewModels/
└── MedicationBarViewModel.swift # EDIT (US3) — logManualDose tags isMockData (FR-009, test-first)

app-fourTests/
├── ViewModels/MedicationBarViewModelTests.swift  # EDIT (US3) — RED test for FR-009
└── Views/DayCardPaletteTests.swift               # EDIT (PR1) — Theme.cardBackground → NewLook.card

SandboxApp/                      # EDIT (before final delete) — same mechanical swap so it doesn't block token deletion
DESIGN.md                        # EDIT — "New Look is app-wide; Theme retained for accent/status/danger only"; add tintNeutral
```

**Structure Decision**: Existing native-app + local-SPM layout, unchanged. No new module, target, or architectural layer. The migration is in-place token/modifier swaps plus one new token and one one-line VM fix.

## Implementation Phasing (maps to user stories → PR sequence)

- **US0 Foundations (PR-0, invisible)** — `NewLook.tintNeutral` (D2), 2-layer card shadow (D3), doc-comment + DESIGN.md updates. Build green; no visible change.
- **US1 The Look (PR-1, MVP)** — `ScreenContainer` ground + toolbar; all card surfaces → `.newLookCard()` (DayCard, RecordingRow, Insights cards, MedicationLogSheet fields, TextCheckInComposer note-box, Settings row bg, med-bar container); grooves → `tintNeutral`; `RootTabView` appearance; `FeedbackButton`; `DayCardPaletteTests` update. Verify the two spec-032 screens unregressed. Device QA light+dark.
- **US2 Ink (PR-2)** — `Theme.textPrimary/Secondary` → `NewLook.inkPrimary/inkSecondary` app-wide; divider strokes → `hairline`; resolve deferred contrast pairs (CheckIn stop-button, chip selection green — D8). Keep semantic text colours.
- **US3 Med-bar data fix (can land with PR-1 or standalone)** — RED test then `logManualDose` `isMockData` tag (FR-009). Logic → test-first.
- **US4 Cleanup (PR-3)** — migrate `SandboxApp/`; grep-gate zero references; delete Theme surface/ink tokens + `.card()`. Clean rebuild.
- **Gated** — Calendar timeline (spec-032 US3 / Figma a01) excluded until spec-029 resolves (FR-018).

Each PR: build + full suite green → `/code-review` → PR to `main` → owner device QA → merge.

## Complexity Tracking

> No Constitution violations. Table intentionally empty.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| — | — | — |

## Post-Design Constitution Re-Check

Re-evaluated after Phase 1 artifacts (research, data-model, contract, quickstart): **still PASS.** The design adds one token + one two-layer shadow + one one-line VM tag (with a RED test) and otherwise replaces token references and deletes dead ones. No new entity, no runtime indirection, no schema change. Minimal Surface (IV) and Correctness (III) are *reinforced* by the deletion PR; the FR-009 fix satisfies X (test-first) and aligns with IX (`isMockData` partition). The one UIKit appearance touch (D5) is justified and isolated.
