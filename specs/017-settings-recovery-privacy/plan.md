# Implementation Plan: Settings — recovery, privacy & clarity

**Branch**: `017-settings-recovery-privacy` | **Date**: 2026-06-23 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/017-settings-recovery-privacy/spec.md`

## Summary

Repair the four correctness/trust gaps the Settings critique scored as ship-blocking, as four independent slices on one feature branch:

1. **Delete the dead Reduce-Motion control** and the two orphaned stores (`UserDefaults["reduceMotion"]`, `AppSettings.reduceMotionEnabled`); keep honoring the iOS system value (already read everywhere) and add one static footer line. Delete-only — no runtime motion behaviour changes.
2. **Model-download recovery**: a pre-download size/conditions line, an inline cause-specific error (`no-network` / `insufficient-space` / `cellular-disabled` / generic) with a single "Try again", a cellular shortcut, and a Cancel during download. The **download engine is feature 015's**; Settings consumes a typed failure cause and a cancel hook. The current engine swallows the error in its `AsyncStream` catch ([AIModelServiceImpl.swift#L45-L51](../../app-four/Services/AIModelServiceImpl.swift#L45)); Phase 0 defines the minimal cause-reporting + cancel seam Settings needs, which 015 owns/adopts.
3. **"Your data" section**: a static on-device privacy statement (onboarding voice) + an open-source/font acknowledgements list (WhisperKit; Fraunces / DM Sans / IBM Plex Mono under OFL). Plus **greenlight + spec** an encrypted single-file journal export as the final optional phase (import deferred).
4. **Clarity S-pass**: `title: "Settings"`, rename "Medical Context Prompt" → "Recognize medication names" relocated under Check-in/Transcription with a footer, gate the tab-reselect scroll animation on Reduce Motion with a `Motion` token, and document the native-`List` typography exemption in DESIGN.md.

Technical approach: keep everything in SwiftUI + the existing `@MainActor @Observable SettingsViewModel`; the only data-model change is *removing* an attribute; the only new types are a small `Sendable` failure-cause enum (in `Services/`, shared with 015) and — if 015 hasn't shipped reachability — a `NetworkConditionService` protocol behind `AppServices`. No new persisted entities for Settings.

## Technical Context

**Language/Version**: Swift 6+ (strict concurrency).

**Primary Dependencies**: SwiftUI (iOS 26), SwiftData, Swift Concurrency, WhisperKit (via the existing `AIModelService`), `Network` framework (`NWPathMonitor`) only if a reachability seam is needed and 015 hasn't provided one.

**Storage**: SwiftData (`AppSettings`, `ModelMetadata`); `UserDefaults` (`medicalPromptEnabled`); `@AppStorage` (calendar/med-bar keys). This feature *removes* one `AppSettings` attribute and one `UserDefaults` key.

**Testing**: Swift Testing (`@Test`/`#expect`), test-first per Principle X. `MockAIModelService` + `MockAppServices` already exist ([app-fourTests/Mocks/](../../app-fourTests/Mocks/)).

**Target Platform**: iOS 26 (primary), iPadOS (secondary).

**Project Type**: Single-target mobile app (`app-four`).

**Performance Goals**: 60 fps; Settings is a static `List` — no perf concern. Storage calc and model checks already run off the main actor in the VM.

**Constraints**: On-device only; no network egress of user data; the model download is the only network activity and is metered-data-aware. Inline (non-modal) error UI; Paper & Pollen tokens only (no raw literals); native grouped-`List` chrome retained.

**Scale/Scope**: One screen (`SettingsView`) + one VM + one row component (`ModelDownloadRow`) + one model edit + one new privacy section view + one optional export service. ~4 logic-bearing units → test-first; the rest are SwiftUI views (build + run).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-checked after Phase 1 design.* See [.specify/memory/constitution.md](../../.specify/memory/constitution.md) (v1.2.0).

- [x] **I. SwiftUI-First** — PASS. All UI is SwiftUI on iOS 26 APIs; native grouped `List` retained deliberately (documented exemption, FR-023). No UIKit added; `UIApplication.openSettingsURLString` for the cellular shortcut follows existing precedent ([CheckInView.swift#L41](../../app-four/Views/CheckIn/CheckInView.swift#L41)). New visible UI (the inline error/Cancel states on the download row, the "Your data" section) is small and additive; HTML-mockup expectation is satisfied by the brainstorm's explicit per-row copy/states (no novel layout) — flagged in research.md for a quick mockup of the error-row + Your-data section before SwiftUI if the owner wants pixel sign-off.
- [x] **II. Test-Build-Ship** — PASS. Each task ends green (build + full suite via `ios-debugger-agent`). Logic changes (VM failure-cause mapping, model removal) are test-first; views verified by build + simulator run.
- [x] **III. Correctness Over Speed** — PASS. This feature *is* a correctness pass: it removes a dead control and a silent failure rather than adding surface. Deletes the orphaned `reduceMotionEnabled` + `UserDefaults["reduceMotion"]` (no shim left). No stubs; export is explicitly greenlit-and-specced, built only if its phase is taken, never half-merged.
- [x] **IV. Minimal Surface** — PASS. No abstraction beyond the task: one `Sendable` failure-cause enum (needed to message distinctly), and a `NetworkConditionService` protocol *only if* 015 hasn't provided reachability (justified in Complexity Tracking; otherwise consumed). No feature flags. The cause enum and cancel hook live with the engine 015 owns, not duplicated in Settings.
- [x] **V. Solo Git Discipline** — PASS. One `feat/017-settings-recovery-privacy` branch; four independently-revertable slices (US1–US4) each a clean checkpoint; `/code-review` before merge; `main` stays releasable (each slice ships value alone).
- [x] **VI. On-Device Privacy** — PASS (and strengthened). Adds the persistent on-device privacy statement and acknowledgements. The export is **encrypted** so the promise survives the file leaving the sandbox; no user data egresses. Download remains the only network activity; logs stay counts/durations (the cause enum carries no transcript/med content).
- [x] **VII. Deterministic, Measured Extraction** — N-A. This feature does not touch `NLNoteExtractor`, the lexicon, or extraction. The medical-prompt rename is label-only and does not change the transcription bias value or extraction. No eval-harness impact.
- [x] **VIII. Service-Oriented Architecture** — PASS. Download stays behind `AIModelService` (engine owned by 015); any reachability is a new `Services/` protocol injected via `AppServices`; export, if built, is an `ExportService` protocol behind `AppServices`. VM stays `@MainActor @Observable` with no persistence logic; storage/model/export work runs off-main.
- [x] **IX. Pre-Release Data Posture** — PASS. The only schema change is *removing* `AppSettings.reduceMotionEnabled` — strictly CloudKit-compatible (no unique/required attribute introduced). A removed attribute on a pre-release schema is recovered by the existing wipe-and-rebuild path ([AppModelContainer.swift#L46](../../app-four/App/AppModelContainer.swift#L46)); no migration plan needed. No `@Attribute(.unique)` added.
- [x] **X. Test-First Development** — PASS. Logic units — the VM's failure-cause→message mapping, the cancel/retry state transitions, the `AppSettings` attribute removal (and its fetch-or-create path), the reachability service (if added), and the export service (if built) — are RED→GREEN→refactor with Swift Testing, ordered before implementation in tasks.md. SwiftUI views (the error/Cancel row states, the "Your data" section) are exempt (build + simulator run).

**Result: PASS.** One conditional surface addition (reachability service) is justified in Complexity Tracking; it is only introduced if 015 has not already provided the capability.

## Project Structure

### Documentation (this feature)

```text
specs/017-settings-recovery-privacy/
├── plan.md              # This file
├── spec.md              # Authored (what & why)
├── research.md          # Phase 0 — folded inline below (light); see "Phase 0" section
├── data-model.md        # Phase 1 — folded inline below (one removal); see "Phase 1" section
└── tasks.md             # Phase 2 (/speckit-tasks)
```

`research.md` and `data-model.md` content is folded inline here because each is small (one decision cluster, one attribute removal). Promote to separate files only if the 015 coordination contract grows.

### Source Code (repository root)

```text
app-four/
├── Views/
│   ├── SettingsView.swift                     # title; remove RM toggle; add footer line; relocate medical row; gate scroll anim; mount privacy section
│   ├── Settings/
│   │   ├── DayCardSettingsSection.swift        # unchanged
│   │   ├── MedicationBarSettingsSection.swift  # unchanged
│   │   └── YourDataSection.swift               # NEW — privacy statement + acknowledgements (US3)
│   └── Components/
│       └── ModelDownloadRow.swift              # add size/conditions line, inline error + Retry, Cancel, a11y (US2)
├── ViewModels/
│   └── SettingsViewModel.swift                 # remove reduceMotion; add errorMessage/cause + cancel + retry; map cause→copy (US1, US2)
├── Models/
│   └── AppSettings.swift                       # remove `reduceMotionEnabled` (US1)
├── Services/
│   ├── Protocols.swift                         # AIModelService: + cancel hook & typed failure cause (coordinated w/ 015); + NetworkConditionService (conditional); + ExportService (optional)
│   └── (engine impl owned/changed by 015 — AIModelServiceImpl.swift consumes the new cause)
└── Utils/
    └── Constants.swift                         # `medicalPromptEnabled` stays (no migration); no RM key

app-fourTests/
├── ViewModels/
│   └── SettingsViewModelTests.swift            # RESTORE (currently disabled) + new cause-mapping/cancel/retry tests
├── Mocks/
│   ├── MockAIModelService.swift                # extend: inject specific failure cause + cancel
│   └── MockAppServices.swift                   # extend if reachability/export added
└── Services/
    └── (NetworkConditionServiceTests / ExportServiceTests — only for the units actually built)

DESIGN.md                                       # add native-List typography exemption to Decisions Log (US4, FR-023)
```

**Structure Decision**: Single iOS target `app-four`. Changes are localized to the Settings screen, its VM, the shared `ModelDownloadRow`, one model file, one new section view, and (conditionally) `Services/`. The download engine itself is **out of this feature's tree** — owned by 015; Settings only consumes its cause + cancel.

---

## Phase 0 — Research (folded inline)

### R1 — Reduce Motion: confirm delete-only is safe

**Finding (verified):** Exactly one writer of `UserDefaults["reduceMotion"]` exists ([SettingsViewModel.swift#L22-L31](../../app-four/ViewModels/SettingsViewModel.swift#L22)); `AppSettings.reduceMotionEnabled` ([AppSettings.swift#L9](../../app-four/Models/AppSettings.swift#L9)) is declared but never read/written; all 7 animated views read `@Environment(\.accessibilityReduceMotion)` (CheckInView, CrescentRing, MedicationBarView, CalendarHeaderView, InsightsView, CalendarLibraryView, plus the Settings scroll). **Decision:** Pure deletion of the toggle + both stores cannot change runtime motion. The static footer is copy-only. (Brainstorm T1 → Honor-only.)

### R2 — Download failure causes & the 015 seam (the load-bearing research)

**Finding (verified):** `AIModelService.download` returns `AsyncStream<Double>`; on mid-download failure its internal `catch` sets `metadata.isCorrupted = true`, logs, and `continuation.finish()`s **without surfacing the error** ([AIModelServiceImpl.swift#L45-L51](../../app-four/Services/AIModelServiceImpl.swift#L45)). The VM's own `catch` ([SettingsViewModel.swift#L101-L103](../../app-four/ViewModels/SettingsViewModel.swift#L101)) only fires for a throw from *starting* the stream, not for in-stream failure — so today most failures are invisible to the VM. There is **no reachability service** in the app (only a Diagnostics metric reference). `UIApplication.openSettingsURLString` is already used ([CheckInView.swift#L41](../../app-four/Views/CheckIn/CheckInView.swift#L41)).

**Decision / contract Settings needs from 015 (the engine owner):**
1. **Typed failure cause.** The download surface reports a `Sendable` cause — `ModelDownloadFailure { noNetwork, insufficientSpace, cellularDisabled, other(String) }` — instead of silently finishing. Mechanism is 015's to choose (a terminating `AsyncStream<DownloadEvent>` value, or `download` rethrowing the cause). Settings only requires that the cause reach the VM.
2. **Cancel hook.** A way to cancel an in-progress download that leaves no installed/partial model. `AsyncStream.onTermination` already cancels the task ([AIModelServiceImpl.swift#L53-L55](../../app-four/Services/AIModelServiceImpl.swift#L53)); Settings needs a VM-callable `cancelDownload()` that tears down the stream and re-checks filesystem truth.
3. **Pre-flight condition check.** To say "cellular downloads are off" *before* the tap, Settings reads a `NetworkConditionService` (`isConstrained`/`isCellular`) + the existing `downloadOverCellular` flag.

**If 015 has already landed (1)–(3):** Settings consumes them; no engine code in this feature. **If not:** this feature adds the minimal `ModelDownloadFailure` enum + a `cancelDownload()` + a `NetworkConditionService` protocol as the seam, *in `Services/` where 015 will own them* — never a forked download/queue. Complexity Tracking records the conditional `NetworkConditionService` addition.

**Rejected:** blind auto-retry (brainstorm T2 → mixed/cellular-hostile). Any auto-retry is Wi-Fi-only and is 015's orchestration, not Settings'.

### R3 — Privacy copy & acknowledgements source

**Finding (verified):** The on-device promise is stated in onboarding ([OnboardingView.swift#L175](../../app-four/Views/Onboarding/OnboardingView.swift): "Squirl runs entirely on this device…"); fonts ship bundled ([Info.plist#L11-L15](../../app-four/Info.plist#L11)) but **no OFL/licence file or acknowledgements surface exists anywhere** in the app. **Decision:** "Your data" reuses the onboarding sentence(s) verbatim-in-voice; acknowledgements list WhisperKit + the three fonts under OFL. Static `List` rows; an acknowledgements detail can be a pushed plain-text screen or inline rows (view choice, no logic). (Brainstorm T3 → Quiet trust footer now; export greenlit.)

### R4 — Export format intent (greenlit, build optional)

**Decision:** Encrypted single-file archive (recommended over plain JSON / Health-style) bundling recordings + check-ins + extracted signals, labelled "Save a copy of my journal — yours to keep," placed directly above "Clear All Data." Built via `fileExporter`/`ShareLink` behind an `ExportService` protocol; **no export/`ShareLink`/CryptoKit exists today** (verified). **Import/migrate is out of scope** (brainstorm T3 → its own later spec). This phase is the final, optional task block; if deferred, the privacy footer still ships.

### R5 — Title & typography exemption

**Finding (verified):** Every tab passes `title: ""`; `ScreenContainer` already wires `.navigationTitle(title)` + `.inline` ([ScreenContainer.swift]), so `title: "Settings"` is one string and yields a VoiceOver landmark for free. Section/row text is system-font because it's a vanilla `.insetGrouped` `List`. **Decision:** Pass `title: "Settings"` (Settings only; no app-wide title ruling here — left to a separate decision so it isn't an orphan). Keep native chrome; record the exemption in DESIGN.md (Brainstorm T4 → Minimal clarity pass).

---

## Phase 1 — Data Model (folded inline)

**Only change: remove one attribute.**

### `AppSettings` (`@Model`, [AppSettings.swift](../../app-four/Models/AppSettings.swift))

| Attribute | Action | Notes |
|---|---|---|
| `reduceMotionEnabled: Bool` | **REMOVE** | Orphaned — never read. Drop the stored property + its `init` parameter/assignment. |
| `id`, `hasCompletedOnboarding`, `defaultLanguage`, `downloadOverCellular`, `transcriptionCount`, `promptPaceSeconds` | unchanged | — |

**Posture (Principle IX):** all remaining attributes stay optional/defaulted; no `@Attribute(.unique)` added (the existing `id` unique is unchanged and out of scope). Removing an attribute on the pre-release schema is recovered by the existing wipe-and-rebuild conflict path; no migration. **No new persisted entity** is introduced by Settings — the download failure cause is transient (in-memory), and the export archive (if built) is a file, not a SwiftData type.

**Non-persisted types:**
- `ModelDownloadFailure` (enum, `Sendable`) — `noNetwork`, `insufficientSpace`, `cellularDisabled`, `other(String)`. Lives in `Services/` (with the engine 015 owns). Carries no transcript/med content (Principle VI).
- VM-held `downloadError: ModelDownloadFailure?` (or a small view state) drives the inline error row.

---

## Complexity Tracking

> Only the conditional additions need justification.

| Violation / addition | Why needed | Simpler alternative rejected because |
|---|---|---|
| `NetworkConditionService` protocol (new `Services/` seam) | FR-009 needs to say "cellular is off" *before* the failed tap, and FR-007 needs to distinguish no-network from cellular-disabled; no reachability exists in the app today. | Reading network state ad-hoc in the view violates Principle VIII (off-protocol capability) and isn't mockable for the test-first cause-mapping tests. Added **only if** 015 hasn't already provided reachability; otherwise consumed, not added. |
| `ModelDownloadFailure` enum | FR-006/007 require distinct messages per cause; the engine currently surfaces nothing. | A bare `Error`/`String` can't be exhaustively switched for guaranteed-distinct copy + the right recovery affordance, and a free-form string isn't testable. Defined once with the engine (015), not duplicated. |
| `ExportService` protocol (optional, final phase) | FR-018 greenlights encrypted export; it must be mockable and off-main (Principle VIII/X). | Inline `fileExporter` logic in the view would put serialization + encryption on the main actor and outside the DI seam. Built only if the export phase is taken; deferring it does not block US1–US4. |
