# Implementation Plan: Onboarding & First-Run

**Branch**: `015-onboarding-first-run` | **Date**: 2026-06-23 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/015-onboarding-first-run/spec.md`

## Summary

Replace the three-step onboarding gate (welcome → mic permission → blocking model download) with a single Paper & Pollen welcome that lands on the Check-in hub. Permission moves to the existing just-in-time Check-in path; the transcription model downloads in the background (honoring `downloadOverCellular`) with no exit gate; and a new **pending-transcription queue** persists a recording captured before the model is ready and drains it automatically — through the existing transcription/extraction path — once the model lands. The hero is the existing breathing `CrescentRing`; all user-facing "Whisper"/"~150 MB" jargon is removed; model management stays in the Settings transcription row (shared with Feature 017).

The load-bearing engineering is the queue: it needs (1) a new persisted `Recording` status that means "captured, awaiting model", (2) a `Services/` actor that observes model-readiness and drains pending recordings in capture order serialized on the single transcription engine, and (3) a connectivity check used only to gate the background download to Wi-Fi when the user hasn't opted into cellular.

## Technical Context

**Language/Version**: Swift 6+ (strict concurrency)

**Primary Dependencies**: SwiftUI (iOS 26+), SwiftData, Swift Concurrency, Network (`NWPathMonitor` — new, for the cellular gate), WhisperKit (existing, behind `TranscriptionService`/`AIModelService`)

**Storage**: SwiftData — `AppSettings` (`hasCompletedOnboarding`, `downloadOverCellular`), `Recording` (new pending status value)

**Testing**: Swift Testing (`@Test`/`#expect`), test-first for logic per Principle X; views verified by build + simulator run

**Target Platform**: iOS 26 (primary), iPadOS (secondary)

**Project Type**: Mobile app (single Xcode target `app-four`, module `app_four`)

**Performance Goals**: Welcome → hub in one tap; first-run path renders at 60 fps; the breathing crescent and any draining happen off the capture critical path

**Constraints**: On-device only; no audio/transcript/health data leaves the device; background download must not spend cellular data when the preference is off; queue draining must serialize on the single WhisperKit instance; tokens-only (no raw color/font literals) on the first-run path

**Scale/Scope**: One first-run flow (1 screen), one new service (queue), one new connectivity helper, one new `Recording` status value, edits to the Check-in save path and launch wiring. ~1 model field, 2 services, 1 VM, 1 view.

## Constitution Check

*GATE: evaluated against `.specify/memory/constitution.md` (v1.2.0). Re-check after Phase 1 design.*

- [x] **I. SwiftUI-First** — PASS. The welcome is SwiftUI on iOS 26 APIs reusing `CrescentRing`, `Theme`, `Typography`, `ScreenContainer`-style layout, and `.primary`/`.secondary` button styles. Mockup: the welcome reuses the shipping Check-in hub's visual language (crescent + Fraunces on paper); a static HTML mockup is produced as task T002 before the SwiftUI rewrite per Principle I. `NWPathMonitor` (Network framework) is used only as a non-UI connectivity check behind a service — no UIKit UI.
- [x] **II. Test-Build-Ship** — PASS. Logic (queue actor, connectivity gate, view-model, the `Recording` status change, the Check-in save branch) is built test-first; the view is verified by build + on-simulator run via `ios-debugger-agent`. The full Swift Testing suite must be green before the PR.
- [x] **III. Correctness Over Speed** — PASS. The old three-step `OnboardingView`/`OnboardingViewModel` `DownloadPhase` machinery and the dead `modelsReady` property ([OnboardingViewModel.swift#L27](../../app-four/Views/Onboarding/OnboardingViewModel.swift#L27)) are *removed*, not left as shims. No placeholder stubs; the queue is a complete capability. Tradeoffs (e.g. NWPathMonitor dependency, new status value) are surfaced here and in Complexity Tracking.
- [x] **IV. Minimal Surface** — PASS. One new status value, one queue service, one small connectivity helper, one welcome view + VM. No feature flags, no speculative abstraction. The download already streams progress and short-circuits when installed; we reuse it. Model management is NOT rebuilt — the existing Settings row is reused.
- [x] **V. Solo Git Discipline** — PASS. One revertable feature on `feat/015-onboarding-first-run` (the spec dir uses the `015-` prefix; the working branch is `feat/…` per CLAUDE.md). `/code-review` before merge; `main` stays releasable; tasks are independent checkpoints.
- [x] **VI. On-Device Privacy** — PASS. Nothing leaves the device. The model download is a binary asset fetch (no user data). Logs stay counts/durations (the queue logs recording IDs/counts, never transcript text). The cellular gate reads connection type only. The privacy posture is *strengthened* (the welcome states the on-device promise; jargon that undermined trust is removed).
- [x] **VII. Deterministic, Measured Extraction** — PASS (N-A for changes). Extraction is untouched: queued recordings drain through the exact existing `transcribe → applySummary` path ([CheckInViewModel.swift#L123-L161](../../app-four/ViewModels/CheckInViewModel.swift#L123)), which already runs `NLNoteExtractor` off-main with the lexicon-as-data overlay. No lexicon, matching, or floor changes; the eval harness is not affected because extraction inputs/ordering are unchanged.
- [x] **VIII. Service-Oriented Architecture** — PASS. The queue is a new `Services/` protocol (`PendingTranscriptionService`) injected via `AppServices`/`AppDependencies`; the connectivity check is a small `Sendable` helper behind a protocol so it is mockable. The download gate consults it; nothing references `AppDependencies` from a view/VM. The new VM is `@MainActor @Observable` and holds no persistence logic. Heavy work (download, transcription) stays off the main actor on its existing actors; model lifecycle stays RAM-isolated (WhisperKit loads then unloads before extraction — unchanged).
- [x] **IX. Pre-Release Data Posture** — PASS. The new `Recording` status is a defaulted enum value on an existing optional/defaulted attribute — no `@Attribute(.unique)`, no new required field. Schema stays CloudKit-compatible. Mock/real partitioning via `isMockData` is unchanged. No migration plan needed (pre-release wipe-and-rebuild posture).
- [x] **X. Test-First Development** — PASS. Every logic task below is ordered test-first (RED → GREEN → refactor) with Swift Testing: the queue actor, the connectivity gate, the model-ready trigger, the Check-in pending-branch, the `Recording` status behavior, and the welcome VM's completion/persistence. The welcome view itself is exempt (build + simulator run). The previously-disabled `OnboardingViewModelTests` ([app-fourTests/ViewModels/OnboardingViewModelTests.swift](../../app-fourTests/ViewModels/OnboardingViewModelTests.swift)) are replaced by tests for the new VM using `MockAppServices`.

**Result: PASS.** No principle fails; the two justified additions (a connectivity dependency and a new status value) are recorded in Complexity Tracking.

## Project Structure

### Documentation (this feature)

```text
specs/015-onboarding-first-run/
├── plan.md              # This file
├── research.md          # Phase 0 — decisions & alternatives (inline below; promote to file if it grows)
├── data-model.md        # Phase 1 — Recording status + queue/connectivity contracts (inline below)
├── spec.md              # Authored (what & why)
└── tasks.md             # Phase 2 — /speckit-tasks output
```

### Source Code (repository root)

```text
app-four/
├── App/
│   └── SquirlApp.swift                         # EDIT: RootContainerView — welcome cover wiring; kick off background download + queue drive on launch
├── Models/
│   ├── Recording.swift                         # EDIT: status semantics (pending-transcription) + displayTitle wording
│   └── AppEnums.swift                          # EDIT: RecordingStatus gains `.pendingTranscription`
├── Services/
│   ├── Protocols.swift                         # EDIT: add PendingTranscriptionService + Connectivity protocols
│   ├── PendingTranscriptionServiceImpl.swift   # NEW: actor — observe model-ready, drain pending recordings in capture order
│   └── Connectivity/
│       └── NetworkConnectivity.swift           # NEW: NWPathMonitor-backed Sendable check (cellular vs wifi vs offline)
├── Store/
│   ├── AppServices.swift                       # EDIT: add pendingTranscriptionService + connectivity
│   └── AppDependencies.swift                   # EDIT: compose the two new services
├── ViewModels/
│   └── CheckInViewModel.swift                  # EDIT: on stop, if model not ready → mark .pendingTranscription instead of transcribing now
├── Views/
│   ├── Onboarding/
│   │   ├── WelcomeView.swift                   # NEW: single Paper & Pollen welcome (replaces OnboardingView)
│   │   ├── WelcomeViewModel.swift              # NEW: completion + persistence (replaces OnboardingViewModel)
│   │   ├── OnboardingView.swift                # DELETE: three-step flow
│   │   └── OnboardingViewModel.swift           # DELETE: DownloadPhase machinery + dead modelsReady
│   └── SettingsView.swift                      # EDIT (coordinate w/ 017): de-jargon the transcription row label/copy
└── DesignSystem/                               # (reused; no new tokens)

app-fourTests/
├── Services/
│   ├── PendingTranscriptionServiceTests.swift  # NEW: queue ordering, drain-on-ready, serialization, relaunch persistence
│   └── NetworkConnectivityTests.swift          # NEW: cellular/wifi/offline decision (via injected path provider)
├── ViewModels/
│   ├── WelcomeViewModelTests.swift             # NEW: completion persists; failure still proceeds; idempotent
│   ├── CheckInViewModelTests.swift             # EDIT/NEW: stop-while-model-not-ready → .pendingTranscription
│   └── OnboardingViewModelTests.swift          # DELETE (disabled, stale)
├── Store/
│   └── RecordingStoreTests.swift               # EDIT: orphan recovery must NOT sweep .pendingTranscription
└── Mocks/
    ├── MockAppServices.swift                   # EDIT: add the two new mock services
    ├── MockAIModelService.swift                # (reuse — drives model-ready)
    └── MockConnectivity.swift                  # NEW: scriptable connection type
```

**Structure Decision**: Single Xcode target `app-four` with the established `Services/` + `Store/` (DI) + `ViewModels/` + `Views/` layering. New capabilities (`PendingTranscriptionService`, connectivity) sit behind `Services/` protocols injected through `AppServices`, consistent with every other capability in the app (Principle VIII). First-run UI replaces the `Views/Onboarding/` contents.

---

## Phase 0 — Research (`research.md` content, inline)

### R1 — First-run shape: single welcome vs. keep-and-ungate vs. no-screen

**Decision**: Single welcome that lands on the hub (brainstorm Thread 1 Direction A).
**Rationale**: It is the only option that removes the connectivity dead-end *and* the redundant permission gate while delivering the strongest "relief, then permission" first impression. Direction B keeps three screens of ceremony; Direction C (no screen) under-delivers the privacy beat and is riskiest if the first tap fails. The cost — the record-before-ready queue — is worth building regardless because the same dead end can hit any user whose later download fails.
**Alternatives rejected**: B (half-measure, still a wizard); C (abrupt on privacy, fuzzy comprehension, fragile first tap).

### R2 — How to detect "model ready" to trigger draining

**Decision**: Model-readiness is "the transcription model is installed on disk", read via `AIModelService.localPath(for: .whisper) != nil` (filesystem as source of truth, matching `SettingsViewModel.checkModels` [SettingsViewModel.swift#L82-L86](../../app-four/ViewModels/SettingsViewModel.swift#L82)). The queue service is *driven* both (a) by the background-download completion (the `AsyncStream<Double>` from `AIModelService.download` finishing) and (b) by an explicit drive on app launch/foreground, so it is robust to missed in-process signals.
**Rationale**: Reusing the existing filesystem-truth check avoids a second, drifting notion of readiness. Driving on launch makes the queue survive process death without needing a persistent observer.
**Alternatives rejected**: A SwiftData `isDownloaded` flag alone (can lie if files were evicted — the codebase already distrusts it); a long-lived in-memory observer only (lost across relaunch).

### R3 — Representing "captured, awaiting model"

**Decision**: Add `RecordingStatus.pendingTranscription`. The Check-in stop path persists the recording with this status when the model is not ready instead of starting a transcription that would fail.
**Rationale**: `RecordingStatus` is the existing, single vocabulary for a recording's lifecycle ([AppEnums.swift#L5-L11](../../app-four/Models/AppEnums.swift#L5)). A dedicated value is the minimal, honest representation: it is queryable for draining, distinguishable from `.failed` (so the UI shows a calm "ready shortly" rather than an error), and distinguishable from `.transcribing` (so launch-time orphan recovery [RecordingStore.swift#L21-L32](../../app-four/Store/RecordingStore.swift#L21) does not sweep it to `.failed`).
**Alternatives rejected**: Overloading `.recorded` (ambiguous — `.recorded` already means "saved, not yet transcribed" in other flows and would be swept/ignored inconsistently); a separate boolean column (a second source of truth that can disagree with `status`); a separate queue table (heavier; the recording IS the queue item — a fetch predicate on status is enough).

### R4 — Where the queue lives (service vs. extend CheckInViewModel)

**Decision**: A new `Services/` actor `PendingTranscriptionServiceImpl`, injected via `AppServices`. It owns: a fetch of `.pendingTranscription` recordings in capture order, draining them one-by-one through `TranscriptionService`, then applying extraction via the same `SummarizationService`/`applySummary` path, serialized so only one inference runs at a time.
**Rationale**: Principle VIII requires capabilities behind a `Services/` protocol; the queue is app-level (it must run even when `CheckInView` is not on screen, e.g. after relaunch). A VM cannot own cross-screen, post-relaunch background work.
**Alternatives rejected**: Extending `CheckInViewModel` (dies with the view; can't drain after relaunch or when on another tab); a free function (no place for the single-engine serialization state).

### R5 — Honoring `downloadOverCellular` (the cellular gate)

**Decision**: Introduce a small `Connectivity` protocol backed by `NWPathMonitor`, returning the current interface class (wifi / cellular / other / unsatisfied). The background-download trigger checks: if `downloadOverCellular == false` and the path is cellular, defer; begin (or resume) automatically when the path becomes Wi-Fi. The Settings-initiated manual download is *not* gated by this (explicit user action overrides the passive policy — consistent with how a manual "Download" tap reads as consent).
**Rationale**: `downloadOverCellular` is stored but never consulted today ([AIModelServiceImpl.download](../../app-four/Services/AIModelServiceImpl.swift#L22) has no cellular check) — a real gap and a stated requirement (FR-009). `NWPathMonitor` is the standard, on-device, no-permission API. Behind a protocol it is mockable for the decision tests.
**Alternatives rejected**: Pushing the gate into `AIModelServiceImpl` (couples model download to networking policy and would also gate the explicit Settings download, surprising the user); third-party reachability (unnecessary dependency).

### R6 — Reuse permission, don't reimplement

**Decision**: Delete the onboarding permission step entirely; rely on `CheckInViewModel.startRecording`'s existing `requestPermission()` + `permissionDenied` alert ([CheckInViewModel.swift#L55-L60](../../app-four/ViewModels/CheckInViewModel.swift#L55), [CheckInView.swift#L39-L46](../../app-four/Views/CheckIn/CheckInView.swift#L39)). `requestPermission()` returns the already-granted state without re-prompting, so already-authorized users are never asked twice (resolves the critique's "seed from recordPermission" finding without extra code).
**Rationale**: The recovery is already shipped and on-brand. Less code, one teacher of permission.
**Alternatives rejected**: A reassurance-framed permission screen (Thread 3 B) — keeps a gate; the one privacy sentence lives on the welcome instead.

### R7 — Model management home & replay

**Decision**: No onboarding replay. The existing Settings "AI Models → Whisper Transcription" row ([SettingsView.swift#L58-L70](../../app-four/Views/SettingsView.swift#L58)) is the single home; de-jargon its label/copy (coordinated with Feature 017). Optionally surface one gentle hub hint when the model is not set up/failed.
**Rationale**: A recurring model action (re-download/delete) should be a tappable row, not a re-run wizard (Thread 4 A over B). The row already exists with working VM logic — reuse it.
**Alternatives rejected**: Replayable onboarding (Thread 4 B) — wrong granularity, more state for little benefit; building a *new* Settings surface (duplicates 017).

### R8 — De-jargon copy

**Decision**: Replace user-facing "Whisper" with "on-device transcription"/"voice transcription" and drop the bare "~150 MB" wall everywhere on these paths; the background nature means size no longer needs to be a foregrounded gate.
**Rationale**: Critique P1 — the audience is non-technical and overwhelm-sensitive. Also fixes the leak in `WhisperKitTranscriptionService`'s placeholder segment text ([WhisperKitTranscriptionService.swift#L105](../../app-four/Services/WhisperKit/WhisperKitTranscriptionService.swift#L105)) "Downloading AI Model (~150MB)…" if that string can surface to the user; the pending path should show the calm queue affordance instead.

---

## Phase 1 — Design (`data-model.md` content, inline)

### Entity changes

**`RecordingStatus` (enum, [AppEnums.swift](../../app-four/Models/AppEnums.swift))** — add one case:

| Case | Meaning | Notes |
|---|---|---|
| `recorded` | saved, not yet transcribed (legacy generic) | unchanged |
| `transcribing` | inference in flight | unchanged; launch-orphan recovery sweeps these to `.failed` |
| **`pendingTranscription`** | **captured, awaiting the model to become ready** | **NEW; queryable for draining; NOT swept by orphan recovery; surfaced as a calm "ready shortly" affordance, never `.failed`** |
| `completed` | transcript + extraction applied | unchanged |
| `failed` | terminal failure (timeout/cancel/error) | unchanged; a late model is NOT a failure |
| `placeholder` | initial pre-save | unchanged |

Schema posture: `Recording.status` is a non-unique, defaulted attribute (CloudKit-compatible) — adding a case is additive and needs no migration (Principle IX; pre-release wipe-and-rebuild).

**`Recording.displayTitle`** ([Recording.swift#L42-L44](../../app-four/Models/Recording.swift#L42)) — extend so a `.pendingTranscription` recording reads with the calm pending affordance instead of falling through to its provisional title (exact wording per FR-017, e.g. a "ready shortly" hint), while keeping the `.transcribing` → "Transcribing…" behavior.

### Service contracts (`Services/Protocols.swift`)

```text
protocol Connectivity: Sendable
  var currentInterface: NetworkInterface { get async }   // wifi | cellular | other | unsatisfied
  // (a stream/notification of changes so the download can resume when Wi-Fi returns)

protocol PendingTranscriptionService: Sendable
  func enqueue(_ recordingID: PersistentIdentifier) async       // optional fast-path; drain() also discovers via fetch
  func drainIfModelReady() async                                // fetch .pendingTranscription in capture order; if model ready, transcribe+extract each, serialized
  // driven on: app launch/foreground, and on background-download completion
```

**Draining contract**: for each pending recording (oldest first) — set `.transcribing`, run `TranscriptionService.transcribe`, on success `applySummary`/`setMedicationEvents` exactly as [CheckInViewModel.transcribeInBackground](../../app-four/ViewModels/CheckInViewModel.swift#L123) does, set `.completed`, persist; on real error set `.failed` with the existing retry copy. Serialized so the single WhisperKit actor never runs two inferences (mirrors the existing back-to-back chaining). If the recording was deleted meanwhile, skip it (guard like the existing stream consumer [CheckInViewModel.swift#L175](../../app-four/ViewModels/CheckInViewModel.swift#L175)).

**Background-download trigger (launch)**: on app launch, if the model is not installed: consult `Connectivity`; if `downloadOverCellular == false` and cellular, subscribe for Wi-Fi and defer; else start `AIModelService.download(.whisper)`; when the stream finishes (model installed), call `PendingTranscriptionService.drainIfModelReady()`.

### View / VM

- **`WelcomeView`** (SwiftUI, exempt from unit tests): `Theme.background` paper, `CrescentRing()` breathing hero, `Typography.largeTitle`/`title` Fraunces headline, one `Typography.body` privacy sentence, one `.primary` Meadow-gradient button, clamped to `Metrics.maxContentWidth`, `Motion.smooth` for any transition, Reduce-Motion honored by `CrescentRing` already. Presented via `.fullScreenCover` from `RootContainerView` (same hook as today).
- **`WelcomeViewModel`** (`@MainActor @Observable`, tested): `complete(modelContext:)` upserts `AppSettings.hasCompletedOnboarding = true` (idempotent, like the current `completeOnboarding` [OnboardingViewModel.swift#L101-L112](../../app-four/Views/Onboarding/OnboardingViewModel.swift#L101)); on save failure it still signals completion so the cover dismisses (FR-005 — the critique's silent-strand finding).

### Wiring (`SquirlApp` / `AppDependencies`)

- `RootContainerView` keeps the `hasCompletedOnboarding`-driven `.fullScreenCover`, now presenting `WelcomeView`.
- On launch, `RootContainerView.task` (or App init) kicks the background-download trigger and an initial `drainIfModelReady()` (also re-driven on `scenePhase` → active so a download that finished while backgrounded drains).
- `AppDependencies` composes `NetworkConnectivity` and `PendingTranscriptionServiceImpl(context:, aiModelService:, transcriptionService:, summarizationService:, connectivity:)`; both added to `AppServices`.

### Quickstart (manual verification)

1. Delete app → launch → see the paper welcome with breathing crescent → one tap → Check-in hub. Relaunch → no welcome.
2. Airplane mode → launch fresh → reach hub → record → "Captured." → recording shows "ready shortly", not an error. Disable airplane mode (Wi-Fi) → recording auto-transcribes; title + signals populate.
3. Cellular only + "Download over Cellular" OFF → fresh launch → no download starts; record → pending; switch to Wi-Fi → download runs → pending drains.
4. Deny mic at first record → "Open Settings" recovery appears; typed check-in still works. Grant mic → record starts with no second prompt.
5. Token-grep the first-run path: clean. String-grep "Whisper"/"150 MB" on first-run + queue strings: none.

---

## Complexity Tracking

| Violation / addition | Why needed | Simpler alternative rejected because |
|---|---|---|
| New `NWPathMonitor`-backed `Connectivity` dependency | FR-009 requires honoring `downloadOverCellular`, which is stored but never consulted today; deciding "defer to Wi-Fi" needs the live interface class | No-gate (ignore the preference) would spend the user's cellular data — a trust-breaking surprise for this audience and a direct spec violation. Pushing the check into `AIModelServiceImpl` would also wrongly gate the explicit Settings download. |
| New `RecordingStatus.pendingTranscription` value | A recording captured before the model is ready must be persisted, queryable for draining, distinguishable from `.failed` (calm UI) and `.transcribing` (so orphan recovery doesn't sweep it) | Overloading `.recorded` or adding a parallel boolean creates a second source of truth that disagrees with `status` and breaks the launch-time recovery logic. The single enum is the minimal honest representation. |
| New `PendingTranscriptionService` actor | The queue must run app-level: across tabs and across relaunch, not just while `CheckInView` is mounted | Extending `CheckInViewModel` cannot drain after the view dies or after process death; the post-relaunch drive has nowhere else to live. |
