<!-- Created: 2026-07-03 18:51 (WEST) · Updated: 2026-07-03 19:15 (WEST) -->
# Implementation Plan: App Intents Foundation + NFC Sticker Actions

**Branch**: `feat/030-app-intents` | **Date**: 2026-07-03 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/030-app-intents-foundation/spec.md`

## Summary

Expose Squirl's two highest-frequency actions as system verbs: a background **LogDefaultDoseIntent** (writes a `MedicationEvent` from a new "My medication" default, guarded by a new user-configurable dose guard, discreet-by-default confirmations) and a foreground **StartCheckInIntent** (opens directly into Listening, already recording, strict-gated on onboarding). Both are exposed zero-setup via an `AppShortcutsProvider` (Siri/Spotlight/Shortcuts) and become NFC-sticker-triggerable through user-created Shortcuts automations, supported by a guided setup screen. Technical approach (research-verified, [research.md](research.md)): intents live in the app target (headless background launch is safe — D1), execution modes use the iOS 26 `supportedModes`/`IntentModes` API — check-in `.foreground`, dose `[.background, .foreground(.dynamic)]` with `continueInForeground()` for the not-configured hand-off (D2/D9 as revised by **D15: deployment target raised 17.0 → 26.0, owner decision 2026-07-03**), the check-in trigger reuses the shipped `whispernotes://checkin` auto-start path behind a new router that also closes that path's pre-existing missing onboarding gate (D3/D4), and the dose pipeline lives behind a new `DoseLogService` protocol (D5) reusing the shipped boundary-exact guard math (D6). One honest platform limit surfaced: background intents cannot play haptics — FR-005 amendment carried for owner sign-off (D9).

## Technical Context

**Language/Version**: Swift 5 language mode, MainActor-default isolation + Approachable Concurrency (repo-wide build settings); Xcode 26 toolchain

**Primary Dependencies**: SwiftUI, SwiftData, **AppIntents** (new import — iOS 26 `supportedModes` execution-mode API; iOS 17.0+ `AppShortcut` initializer), SquirlDesignSystem (haptics, tokens); no new third-party packages

**Storage**: SwiftData — 5 new defaulted fields on the existing `AppSettings` singleton; `MedicationEvent` consumed unchanged ([data-model.md](data-model.md))

**Testing**: Swift Testing (`@Test`/`#expect`), test-first per Constitution X; inline in-memory `ModelContainer` per repo convention; `TestSupport.useRealData()` where mock-mode predicates apply

**Target Platform**: **iOS 26.0+** (raised from 17.0 by owner decision 2026-07-03 — D15; executed ahead of this feature on `feat/ios26-target`, app target + both SPM packages; device floor becomes iPhone 11/A13+, dropping iPhone XS/XR; baseline device iPhone 12 runs iOS 26); intents surface on both bundle IDs (dev + stable channel)

**Project Type**: Single-target mobile app (`app-four`) + test bundle; synchronized folders — new files need no pbxproj edits

**Performance Goals**: trigger→acknowledged dose log < 3 s (SC-001); trigger→actively-recording < 3 s on iPhone 12 (SC-002); background intent hard ceiling 30 s (platform)

**Constraints**: on-device only (Constitution VI); no new entitlements/Info.plist keys (verified — D10/item 10); background haptics impossible (D9 — FR-005 amendment); no Core NFC code, no associated domain (Shortcuts automations own the NFC layer); locked NFC behavior is community-verified only → quickstart S23 verifies on device; deprecated App Intents surfaces (`openAppWhenRun`, `ForegroundContinuableIntent`) banned on the 26 target (Constitution I); iOS 26 extras deliberately NOT adopted this feature (interactive snippets, `LongRunningIntent`, SwiftData `#Index`, Liquid Glass — D15)

**Scale/Scope**: 2 intents + 1 provider + 1 router + 1 service protocol/impl; 5 `AppSettings` fields; 4 Settings UI surfaces (3 controls + 1 guided walkthrough), each HTML-mockup-gated; ~6 new test suites

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.* (v1.2.0)

- [x] **I. SwiftUI-First** — PASS. All new UI is SwiftUI (Settings sections + sticker guide). Every new view is HTML-mockup-gated before SwiftUI (mockup tasks precede view tasks in Phase 2). Intents/service/router are non-UI. No UIKit beyond the existing `Haptics` wrapper. With the 26.0 target (D15) the modern `supportedModes` API is used and the deprecated foregrounding surfaces are banned — the constitution's "iOS 26+ / no deprecated APIs" clause is now met literally, not by exception.
- [x] **II. Test-Build-Ship** — PASS. Plan ends in build + full serial suite green before PR; device QA per [quickstart.md](quickstart.md).
- [x] **III. Correctness Over Speed** — PASS. Two tradeoffs surfaced, not hidden: (1) background-haptic impossibility → FR-005 wording amendment carried as an explicit owner sign-off task (D9); (2) the shipped `whispernotes://checkin` path has no onboarding gate — fixed via the router as part of FR-022, called out as a congruent pre-existing-hole fix (D4). No stubs, no dead code; the orphaned-`medicalPromptEnabled` anti-pattern is explicitly not copied (every new setting ships with its visible control).
- [x] **IV. Minimal Surface** — PASS. No speculative abstraction: `DoseLogService` exists because an intent cannot depend on a UI view-model (VIII) — single consumer today, not retrofitted into the sheet (clarification Option A). Router exists because trigger state is currently private `@State` in `SquirlApp` and FR-022 needs one choke point — see Complexity Tracking.
- [x] **V. Solo Git Discipline** — PASS. One branch `feat/030-app-intents`, one revertable PR, `/code-review` before merge, owner device QA mandatory.
- [x] **VI. On-Device Privacy** — PASS. Everything on-device; no network surface. Confirmations are discreet by default (FR-023) and never contain journal content (FR-021); logging stays counts/durations only. `.alwaysAllowed` on the dose intent is the documented platform default, owner-accepted (D8).
- [x] **VII. Deterministic, Measured Extraction** — N/A. Extraction pipeline, lexicon, and eval harness untouched (intent-started recordings enter the existing pipeline unchanged — FR-015).
- [x] **VIII. Service-Oriented Architecture** — PASS. New capability behind `DoseLogService` protocol in `Services/`, injected via `AppDependencies` and bridged to intents with `AppDependencyManager`/`@AppDependency` (D11). Router is `@MainActor @Observable`; heavy work is none (one fetch + insert).
- [x] **IX. Pre-Release Data Posture** — PASS. All 5 new `AppSettings` fields defaulted/optional, no `@Attribute(.unique)`, CloudKit-compatible ([data-model.md](data-model.md) per-field check). Pre-existing `.unique` on `AppSettings.id` untouched (tracked separately).
- [x] **X. Test-First Development** — PASS. RED-first suites for: `AppSettings` new-field defaults (Mirror pattern), `DoseGuardMode` decode + boundary math, `DoseLogService` outcomes (logged/guarded×2 modes/notConfigured/dangling-default), confirmation copy matrix, router gate (onboarding complete/incomplete, one-shot consumption). Intent `perform()` bodies are thin translation layers verified by build + device QA (views-exempt spirit, D14); SwiftUI surfaces verified by build + quickstart.

**Post-design re-check (after Phase 1)**: no new violations introduced by the design artifacts; Complexity Tracking below carries the one transparency row. GATE: PASS.

## Project Structure

### Documentation (this feature)

```text
specs/030-app-intents-foundation/
├── plan.md              # This file
├── spec.md              # Feature spec (clarified 2026-07-03, 23 FRs)
├── research.md          # Phase 0 — 14 decisions, D1–D14
├── data-model.md        # Phase 1 — AppSettings fields, guard semantics, copy matrix
├── quickstart.md        # Phase 1 — 26-scenario device QA
├── contracts/
│   └── app-intents.md   # Phase 1 — verb + seam + Settings-surface contracts
└── tasks.md             # Phase 2 (/speckit-tasks — NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
app-four/
├── App/
│   └── SquirlApp.swift                      # MODIFY: register deps with AppDependencyManager;
│                                            #   drive selectedTab/shouldAutoStart from router;
│                                            #   rewire onOpenURL through router (D3/D4)
├── Intents/                                 # NEW folder (synchronized — no pbxproj edit)
│   ├── LogDefaultDoseIntent.swift           # NEW: background verb (contracts §Verb 1)
│   ├── StartCheckInIntent.swift             # NEW: foreground verb (contracts §Verb 2)
│   ├── SquirlAppShortcuts.swift             # NEW: AppShortcutsProvider (D10)
│   └── AppIntentRouter.swift                # NEW: @MainActor @Observable router + FR-022 gate
├── Models/
│   ├── AppSettings.swift                    # MODIFY: +5 defaulted fields (data-model.md)
│   └── DoseGuardMode.swift                  # NEW: non-persisted enum + boundary semantics
├── Services/
│   └── DoseLog/
│       ├── DoseLogService.swift             # NEW: protocol + DoseLogOutcome
│       └── DoseLogServiceImpl.swift         # NEW: settings resolve → guard → write → notify
├── Store/
│   └── AppDependencies.swift                # MODIFY: compose DoseLogService + router
└── Views/Settings/
    ├── MyMedicationSection.swift            # NEW (mockup-gated): default med+dose picker
    ├── DoseGuardSection.swift               # NEW (mockup-gated): off/total/window + hours
    ├── ConfirmationStyleSection.swift       # NEW (mockup-gated): naming toggle (or folded
    │                                        #   into MyMedicationSection — mockup decides)
    └── StickerSetupView.swift               # NEW (mockup-gated): guided walkthrough,
                                             #   shortcuts:// hand-off (D12)

app-four/Views/SettingsView.swift            # MODIFY: mount new sections
app-four/Views/CheckIn/CheckInView.swift     # MODIFY (minimal): consume router-driven autostart
                                             #   (existing consumeAutoStart path)

app-fourTests/
├── Models/AppSettingsTests.swift            # MODIFY: new-field defaults (RED first)
├── Models/DoseGuardModeTests.swift          # NEW: decode + boundary math (RED first)
├── Services/DoseLogServiceTests.swift       # NEW: outcome matrix (RED first)
├── Intents/AppIntentRouterTests.swift       # NEW: gate + one-shot consumption (RED first)
└── Views/ConfirmationCopyTests.swift        # NEW: copy matrix (RED first; pure helper)

html-mockups/                                # Constitution I gates (before SwiftUI)
├── 030-settings-medication.html             # My medication + Dose guard + naming toggle
└── 030-sticker-guide.html                   # Guided walkthrough screens
```

**Structure Decision**: single app target extended in place. New `Intents/` folder groups the App Intents surface; the service follows the existing `Services/<Capability>/` convention (cf. `Services/WhisperKit/`, `Services/Audio/`); Settings sections follow the self-contained-section-view pattern (`Views/Settings/MedicationBarSettingsSection.swift` precedent). Synchronized folders mean zero pbxproj churn.

## Complexity Tracking

> Constitution Check passes; one transparency row (no violation, justification recorded).

| Addition | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| `AppIntentRouter` (@MainActor @Observable) | Trigger state (`selectedTab`, `shouldAutoStartRecording`) is private `@State` in `SquirlApp`, unreachable from an intent; FR-022 needs ONE gate covering both the intent and the shipped ungated `whispernotes://checkin` path | NotificationCenter signal: stringly, no ownership, two gate sites to keep in sync; intent → `OpenURLIntent` round-trip: same gate problem plus URL indirection |

## Owner sign-off carried into tasks (not silently decided)

1. **FR-005 wording amendment** (D9): "accompanied by a haptic" → haptic only where the platform allows (foreground); background acknowledgment = system banner/spoken dialog. Spec edit lands with the PR, or the owner overrules with a notification-with-sound alternative (adds notification permission — not recommended).
2. **S23 lock-behavior verification** (quickstart): the one community-verified-only claim; guide copy and spec assumption must match observed device behavior in the same PR.
