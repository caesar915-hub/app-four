<!-- Created: 2026-07-16 18:40 (WEST) · Updated: 2026-07-16 19:03 (WEST) -->
# Implementation Plan: Live Activity Recording Controls for Check-In

**Branch**: `feat/037-live-activity-controls` | **Date**: 2026-07-16 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/037-live-activity-controls/spec.md`

## Summary

Surface Lock Screen and Dynamic Island controls over an **already-running** check-in recording: live elapsed time, pause/resume, and stop-and-save — operable while the device is locked, without unlocking or reopening the app. The platform boundary (established by spec 030 + this session's research) is that a mic session cannot *start* in the background, but an *active* session can be *controlled* from the background; this feature lives entirely inside that allowance.

The technical crux, confirmed by code grounding: the audio **session** is already a process-level service (`AudioRecordingService` in `AppDependencies`), but the **finalize/save/transcribe pipeline** (`CheckInViewModel.stopRecording → attemptSave`, the `pendingSave` retry buffer, transcription chaining, and the recording state machine) is trapped in a `@MainActor` **view-model**. A background `LiveActivityIntent` has no view-model. So the core of this plan is a **Constitution VIII service extraction**: move the recording *lifecycle ownership* (start/pause/resume/stop + finalize) to a process-level, injectable owner that both `CheckInView` and the Live Activity intents drive through one seam — plus a WidgetKit extension target (a project first) to render the Live Activity, and an ActivityKit controller service to start/update/end it.

> Architecture specifics that depend on verified platform behavior (LiveActivityIntent process model, background-finalize reliability, locked-device data-protection, cap-while-suspended) are resolved in [research.md](research.md) and reflected in the Structure and Complexity sections below.

## Technical Context

**Language/Version**: Swift 6 (strict concurrency; Swift 5 language mode + MainActor-default + Approachable Concurrency, per repo config)

**Primary Dependencies**: SwiftUI, SwiftData, Swift Concurrency, **ActivityKit** (new to this project), **WidgetKit** (new — for the Live Activity presentation), App Intents (`LiveActivityIntent`, extends the spec-030 App Intents foundation), AVFoundation (existing `AudioRecordingServiceImpl`)

**Storage**: SwiftData (existing `Recording` model + `RecordingStore`); **no new persisted model** — the Live Activity state is transient (ActivityKit-owned). A small unfinalized-capture recovery marker may be needed for the terminated-app edge case (see research.md) — if so it reuses the existing `Recording.status` states, not a new entity.

**Testing**: Swift Testing (`@Test`/`#expect`), test-first per Constitution X. Testable logic: recording→Live-Activity `ContentState` derivation, the recording lifecycle state machine (recording/paused/ended), and the intent→controller control calls (via a mock service). The WidgetKit view + Dynamic Island layout are SwiftUI, exempt (build + device QA).

**Target Platform**: iOS 26+ (iPhone; Dynamic Island presentation only on devices that have one — degrade gracefully elsewhere)

**Project Type**: Mobile app (single app target) **+ a new WidgetKit app-extension target** for the Live Activity. Two targets exist today (app + unit tests); this adds a third.

**Performance Goals**: Live Activity appears < 1 s after recording starts (SC-002); displayed elapsed time within 1 s of true duration (SC-004, met by a self-updating `Text(timerInterval:)` rather than app-pushed ticks); activity removed within a few seconds of stop (SC-005).

**Constraints**: Controls MUST run with no unlock (FR-005) and no app foreground; stop MUST finalize the same saved entry as an in-app stop (FR-003, SC-003) even when backgrounded; the Lock Screen surface MUST never render transcript/mood/med content (FR-016, SC-006, Constitution VI); recording MUST keep capturing while locked/backgrounded via the already-declared `audio` background mode (FR-006).

**Scale/Scope**: One transient Live Activity at a time (FR-010); 3 P-ranked stories; ~1 new extension target, 1 new service (+ protocol + mock), 1 shared `ActivityAttributes` type, 2–3 `LiveActivityIntent`s, a lifecycle-owner extraction from `CheckInViewModel`, and the Live Activity/Dynamic Island SwiftUI views. `Info.plist`: add `NSSupportsLiveActivities` (confirmed absent today); `audio` background mode already present.

## Constitution Check

*GATE: re-checked after Phase 1 design (see "Post-Design Re-Check" at the end).*

Marked against `.specify/memory/constitution.md` (v1.2.0):

- [x] **I. SwiftUI-First** — Live Activity + Dynamic Island are SwiftUI (WidgetKit `ActivityConfiguration`); iOS 26 APIs, no deprecated surfaces. The one unavoidable UIKit touch (`UIApplication.isIdleTimerDisabled`) already exists and is unrelated. **New UI (the Live Activity presentation) needs an HTML mockup before SwiftUI** — carried as a task (Lock Screen + Dynamic Island compact/expanded states). **PASS** (mockup gate noted).
- [x] **II. Test-Build-Ship** — plan produces a buildable, fully-tested change; device QA is mandatory (the whole feature's value is only observable on a physical locked device — quickstart covers it). **PASS**.
- [x] **III. Correctness Over Speed** — the extraction exists specifically to avoid a *second, drifting* finalize path (the anti-pattern would be duplicating save logic in the intent). No dead code/shims. Any degradation of P1 under the background-finalize edge case is surfaced explicitly, not hidden. **PASS**.
- [x] **IV. Minimal Surface** — the new service + extension target are the *minimum* required by the platform (a Live Activity cannot exist without a WidgetKit extension; a background intent cannot reach a view-model). Justified in Complexity Tracking. No feature flags, no speculative abstraction. **PASS** (with Complexity entries).
- [x] **V. Solo Git Discipline** — one revertable feature on `feat/037-live-activity-controls`; `/code-review` + device QA before merge; `main` stays releasable. **PASS**.
- [x] **VI. On-Device Privacy** — nothing leaves the device; ActivityKit Live Activities render locally (no push server used). FR-016/SC-006 forbid any transcript/mood/med content on the Lock Screen. Data-protection class for the locked-finalize must NOT be weakened carelessly — the safest class that still permits a locked save is chosen in research.md and its tradeoff surfaced. **PASS** (privacy is an explicit design constraint, not an afterthought).
- [x] **VII. Deterministic, Measured Extraction** — the NLP extraction pipeline is **untouched**; a Live-Activity stop routes into the *existing* transcription/extraction path unchanged. **N/A** (no extraction change → no eval-floor risk).
- [x] **VIII. Service-Oriented Architecture** — the recording lifecycle owner and the ActivityKit controller are both new `Services/` protocols injected via `AppDependencies`, mockable at the seam; the owner is `@MainActor @Observable`, heavy work stays off-main (audio/file/transcription already are). This principle is the *reason* for the extraction. **PASS**.
- [x] **IX. Pre-Release Data Posture** — no new `@Model`, no `@Attribute(.unique)`, no new required attribute; schema untouched → CloudKit-compatibility preserved trivially. **PASS**.
- [x] **X. Test-First Development** — the `ContentState` derivation, lifecycle state machine, and intent→controller calls are built RED→GREEN with Swift Testing, ordered before implementation; WidgetKit/Dynamic Island views are the exempt SwiftUI surface (build + device QA). **PASS**.

**Gate result: PASS** (2 justified complexity entries below; 1 N/A). No unjustified violations → Phase 0 proceeds.

## Project Structure

### Documentation (this feature)

```text
specs/037-live-activity-controls/
├── plan.md              # This file
├── research.md          # Phase 0 — platform + architecture decisions (LiveActivityIntent process model, background finalize, data protection, cap-while-suspended, timer API)
├── data-model.md        # Phase 1 — ActivityAttributes/ContentState shape + recording lifecycle states (no new SwiftData model)
├── quickstart.md        # Phase 1 — on-device QA scenarios (locked stop/pause/resume, Dynamic Island, edge cases)
├── contracts/           # Phase 1 — the recording-lifecycle service protocol + the ActivityKit controller protocol + the intents' behavioral contract
└── tasks.md             # Phase 2 (/speckit-tasks — NOT created here)
```

### Source Code (repository root)

```text
app-four/                         # existing app target
├── Services/
│   ├── Protocols.swift            # + RecordingSessionController protocol, + LiveActivityController protocol
│   ├── Audio/                     # existing AudioRecordingServiceImpl (unchanged session mechanics)
│   ├── Recording/                 # NEW — RecordingSessionController impl (process-level lifecycle owner: start/pause/resume/stop + finalize; wraps audioService + the save pipeline lifted out of CheckInViewModel)
│   └── LiveActivity/              # NEW — LiveActivityController impl (ActivityKit start/update/end; maps lifecycle state → ContentState)
├── Intents/
│   ├── AppIntentRouter.swift      # existing 030 seam
│   ├── PauseRecordingIntent.swift # NEW — LiveActivityIntent → controller.pause()
│   ├── ResumeRecordingIntent.swift# NEW — LiveActivityIntent → controller.resume()
│   └── StopRecordingIntent.swift  # NEW — LiveActivityIntent → controller.stopAndSave()
├── Shared/
│   └── CheckInActivityAttributes.swift  # NEW — ActivityAttributes + ContentState; MUST be visible to both app + widget targets
├── ViewModels/
│   └── CheckInViewModel.swift     # delegates recording lifecycle to RecordingSessionController (keeps view-only concerns: prompts, VoiceOver gate, cap cue)
├── Store/AppDependencies.swift    # + register the two new services + intents (AppDependencyManager)
├── App/SquirlApp.swift            # start/end the Live Activity around the recording lifecycle
└── Info.plist                     # + NSSupportsLiveActivities (audio background mode already present)

SquirlWidgets/                     # NEW WidgetKit extension target (project's first extension)
├── SquirlWidgetsBundle.swift      # @main WidgetBundle
├── CheckInLiveActivity.swift      # ActivityConfiguration: Lock Screen + DynamicIsland{} presentations, control buttons
└── Info.plist

app-fourTests/
├── Services/RecordingSessionControllerTests.swift   # NEW — lifecycle state machine + finalize routing (mock audio/store/transcription)
├── Services/LiveActivityContentStateTests.swift     # NEW — recording state → ContentState derivation
└── Intents/RecordingControlIntentsTests.swift       # NEW — each intent calls the right controller method (mock controller)
```

**Structure Decision**: Single app target + **one new WidgetKit extension** (`SquirlWidgets`). The shared `ActivityAttributes`/`ContentState` type lives in a `Shared/` file added to **both** targets' membership (the exact sharing mechanism — file membership vs. a small local SPM target — is decided in research.md against the objectVersion-77 synchronized-folders setup). The recording lifecycle is extracted into a process-level `RecordingSessionController` service so the view-model and the background intents share one owner; a separate `LiveActivityController` service owns ActivityKit start/update/end. This keeps the delicate, well-tested finalize pipeline as a single source of truth (Constitution III/VIII) rather than duplicating it for the intent path.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| **New WidgetKit extension target** (project's first extension; adds a target, an Info.plist, a shared type, and its own signing) | ActivityKit Live Activities *cannot* be declared in the app target — the `ActivityConfiguration` UI must live in a WidgetKit extension. It is a hard platform requirement, not a design choice. | No alternative exists — there is no in-app-target way to present a Live Activity or its Lock Screen/Dynamic Island controls. |
| **Extract `RecordingSessionController` from `CheckInViewModel`** (a process-level lifecycle owner; refactors a delicate, well-tested view-model) | A background `LiveActivityIntent` runs without a view (no `CheckInViewModel` instance), yet must pause/resume and *finalize+save* the live recording. The finalize pipeline (retry buffer, transcription chaining, state machine) must therefore live in a process-level, injectable owner both the view and the intents call. | (a) Duplicating the finalize/save logic inside the Stop intent → two paths that drift, violating Constitution III (correctness) and IV. (b) Router-flag-only (030 pattern) → requires the app to be foreground/awake to consume the flag, defeating background stop (FR-005). Neither delivers a *background* stop that produces an identical saved entry (SC-003). |

## Phase 0 / Phase 1 status

- **Phase 0 — [research.md](research.md): COMPLETE.** 19 decisions (D1–D19), adversarially verified against developer.apple.com, the on-machine iOS 26.5 SDK, and Apple DTS threads. All Technical-Context unknowns resolved. Key resolutions: `LiveActivityIntent.perform()` runs in the app process with no unlock (P1 genuinely achievable); a WidgetKit extension is mandatory; `ActivityAttributes` shares via a local Swift package; the SwiftData store already defaults to the lock-tolerant `.completeUntilFirstUserAuthentication` protection class (locked save works — must *verify* the app hasn't opted into `.complete` and pin it); the max-duration cap is enforceable while locked via `record(forDuration:)`.
- **Phase 1 — [data-model.md](data-model.md), [contracts/](contracts/recording-lifecycle.md), [quickstart.md](quickstart.md): COMPLETE.** No new `@Model`; two transient types + a reused-status marker; two `Services/` protocols + three `LiveActivityIntent`s; test-first seams identified; device-QA scenarios cover the two hardware-only load-bearing checks (locked save; locked cap-finish).
- **CLAUDE.md agent-context pointer**: updated to this plan.

## Post-Design Constitution Re-Check

Re-evaluated after Phase 1 — **still PASS**, no new violations introduced by the design:

- **I. SwiftUI-First** — Live Activity/Dynamic Island are WidgetKit SwiftUI; the new UI carries an HTML-mockup task (Lock Screen + Dynamic Island states) before implementation. **PASS**.
- **III / IV. Correctness / Minimal Surface** — the design *reduces* duplication risk: one idempotent finalize (research D14) shared by all four entry points, wrapping the existing pipeline rather than copying it. The two complexity entries (extension target, controller extraction) remain the platform-forced minimum. **PASS**.
- **VI. On-Device Privacy** — reinforced: FR-016/SC-006 are encoded as a hard `ContentState` invariant with a dedicated test (data-model §5). The one privacy *tradeoff* (protection class `.completeUntilFirstUserAuthentication` is weaker than `.complete` but `.complete` is incompatible with locked recording) is surfaced explicitly in research D13, not buried. **PASS**.
- **VIII. Service-Oriented Architecture** — the two new capabilities sit behind `Services/` protocols via `AppDependencies`, mockable at the seam (contracts §1–2). **PASS**.
- **X. Test-First** — three pure seams identified with named test files, ordered before implementation (data-model §5); WidgetKit views exempt. **PASS**.
- **VII** remains **N/A** (extraction pipeline untouched).

**Gate: PASS.** Ready for `/speckit-tasks`.
