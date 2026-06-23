# Implementation Plan: Check-in — Capture That Lands

**Branch**: `016-checkin-capture-feel` | **Date**: 2026-06-23 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/016-checkin-capture-feel/spec.md`

## Summary

Deliver the four approved capture-experience improvements plus the P1 re-entry fix, all on the existing `CheckInView` / `CheckInViewModel` surface with **no schema change**: (1) the crescent→check **Settle** morph as the signature save motion with one `Haptics.success()` at completion and a single-"Done" Saved state; (2) a **never-lose-a-capture** retry buffer with a calm inline "try again" surface replacing the silent reset to idle; (3) the **VoiceOver pass** — per-prompt announcements (gated on active voice), a "Recording, elapsed" live region, and "Saving…"/"Captured." transition announcements; (4) the **8-minute soft landing** — a one-time approach cue and a graceful save-into-Settle at the cap; plus (5) a one-time **first-launch whisper hint**, and the **`startRecording()` re-entry guard**.

Technical approach: keep the single-screen state machine, but model the new failure/morph affordances as explicit `@MainActor @Observable` view-model state so they are unit-testable (Principle X); the morph and the hint are SwiftUI view work (Principle I, build + run). The retry buffer is a transient in-memory value in the VM; the first-run flag is `@AppStorage`. No `Services/` protocol changes, no new `@Model`.

## Technical Context

**Language/Version**: Swift 6+ (strict concurrency)

**Primary Dependencies**: SwiftUI (iOS 26+), SwiftData, Swift Concurrency, `Observation`. Reuses `Haptics` ([Haptics.swift](../../app-four/DesignSystem/Haptics.swift)), `Motion`/`Spacing`/`Typography`/`Theme`/`Radius`/`Metrics` tokens, `AudioRecordingService`/`AudioFileStorageService`/`TranscriptionService` via `AppServices`. No new third-party deps.

**Storage**: SwiftData (existing `Recording`). Retry buffer is in-memory (not persisted). First-run hint flag in `UserDefaults` via `@AppStorage` (existing app pattern, e.g. [DayCardSettingsSection.swift#L7](../../app-four/Views/Settings/DayCardSettingsSection.swift#L7)).

**Testing**: Swift Testing (`@Test`/`#expect`), test-first for logic per Principle X. Existing suite at [CheckInViewModelTests.swift](../../app-fourTests/ViewModels/CheckInViewModelTests.swift) with `MockAppServices`. Mock save-failure via the existing `MockAudioRecordingService.shouldThrowError` ([MockAudioRecordingService.swift#L10](../../app-fourTests/Mocks/MockAudioRecordingService.swift#L10)) and/or a throwing `MockAudioFileStorageService`.

**Target Platform**: iOS 26+ (primary), iPadOS (secondary).

**Project Type**: Mobile app (single Xcode target `app-four`).

**Performance Goals**: The Settle morph is buttery at 60fps; the save hot path adds no synchronous disk work beyond what exists; live-region/announcement updates are throttled so VoiceOver never chatters.

**Constraints**: On-device only; no audio/health/mood data leaves the device; logs are counts/durations/state-names only; tokens-only (no raw literals beyond justified content dimensions); honor Reduce Motion; 44pt tap targets.

**Scale/Scope**: One screen (`CheckInView`), one VM (`CheckInViewModel`), one decorative view (`CrescentRing` → a morphable variant). ~5 user stories, no new model types.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-checked after Phase 1 design — still PASS.*

See `.specify/memory/constitution.md` (v1.2.0).

- [x] **I. SwiftUI-First** — PASS. All UI is SwiftUI on iOS 26 APIs (the morph, the inline retry line, the hint, the paused state). No UIKit beyond the existing `UINotificationFeedbackGenerator` inside `Haptics` and `UIAccessibility.post` for announcements — both are the platform's only API for those affordances, permitted under "no SwiftUI equivalent". The two changed/added views (Settle morph + Saved single-button; first-launch hint) are visual refinements of an existing, already-mockup'd screen ([DESIGN.md#L92](../../DESIGN.md#L92) specs the Settle and the single-Done Saved state); no net-new screen requires a fresh HTML mockup — the design intent is already documented. See research R1.
- [x] **II. Test-Build-Ship** — PASS. Plan produces a buildable change; every task ends green; build + full suite + extraction eval verified via `ios-debugger-agent` before any "done".
- [x] **III. Correctness Over Speed** — PASS. Fixes a real bug (re-entry) and a real trust gap (silent discard) rather than papering over them; no dead code (the discarded `audioLevelStream` is either consumed for the announcement-gate or left exactly as-is, not expanded into half-wired glow); no compat shims. Tradeoffs surfaced in research.
- [x] **IV. Minimal Surface** — PASS. No new abstractions, no feature flags, no `Services/` changes. Retry buffer is a plain struct held in the VM; the morph reuses one canvas; the hint is one `@AppStorage` bool. The voice-reactive ring *glow* (a tempting expansion) is explicitly NOT built here — only the active-voice gate the announcements need.
- [x] **V. Solo Git Discipline** — PASS. One revertable feature on `016-checkin-capture-feel` (a `feat/…`-class branch); `/code-review` before merge; `main` stays releasable; each task is a clean checkpoint.
- [x] **VI. On-Device Privacy** — PASS. No new data leaves the device. Announcements speak prompt text and "Captured." only (no transcript). Retry buffer holds an audio file URL the app already wrote locally. Logging stays counts/durations/state-names (FR-020).
- [x] **VII. Deterministic, Measured Extraction** — PASS (N-A for new extraction). This feature does not touch `NLNoteExtractor`, the lexicon, or the extraction path; the background transcription→extraction pipeline is preserved byte-for-byte (FR-021). The eval harness is still run as a regression gate (Principle II/X), expected unchanged.
- [x] **VIII. Service-Oriented Architecture** — PASS. No new capability ⇒ no new `Services/` protocol. The VM stays `@MainActor @Observable`, holds no persistence logic (it delegates to `RecordingStore`/`AudioFileStorageService`), and heavy work stays off-main (transcription unchanged; the morph is pure UI). The retry buffer adds VM *state*, not persistence logic.
- [x] **IX. Pre-Release Data Posture** — PASS. No schema change: no new `@Model`, no new attribute, no `@Attribute(.unique)`, no required field. CloudKit-compatibility is untouched. The retry buffer is transient; the hint flag is `UserDefaults`, not SwiftData.
- [x] **X. Test-First Development** — PASS. All logic added to `CheckInViewModel` (re-entry guard, retry-buffer state machine, cap-approach flag, save-failure routing, text-save failure surface) is built RED→GREEN→refactor with Swift Testing. SwiftUI views (the morph, the inline line, the hint, the paused visual) are exempt — verified by build + on-simulator run.

**Result: PASS.** No Complexity Tracking entries required.

## Project Structure

### Documentation (this feature)

```text
specs/016-checkin-capture-feel/
├── plan.md              # This file
├── spec.md              # Authored (what & why)
├── research.md          # Inline below (§ Research) — no separate file needed
├── data-model.md        # Inline below (§ Data Model) — no new @Model, kept inline
└── tasks.md             # /speckit-tasks output
```

Research and data-model are folded inline because there is **no new persisted entity** and the open decisions are few and self-contained — a separate `research.md`/`data-model.md` would be ceremony over substance for this change.

### Source Code (repository root)

```text
app-four/
├── ViewModels/
│   └── CheckInViewModel.swift          # re-entry guard; retry-buffer state machine;
│                                       #   saveFailed surface; cap-approach flag;
│                                       #   text-save failure; (announcement hooks)
├── Views/CheckIn/
│   ├── CheckInView.swift               # Settle host; single-"Done" Saved; inline retry
│   │                                   #   line; first-launch hint; paused visual; a11y
│   │                                   #   announcements + grouped "Recording, elapsed"
│   ├── CrescentRing.swift              # gains a morph-to-check capability (or a sibling
│   │                                   #   SettleRing view) sharing one animatable canvas
│   └── TextCheckInComposer.swift       # (unchanged unless text-save failure surface
│                                       #   needs a hook; failure handled in VM)
└── DesignSystem/
    └── Haptics.swift                   # unchanged (reused)

app-fourTests/
└── ViewModels/
    └── CheckInViewModelTests.swift     # new RED tests for every VM behavior above
```

**Structure Decision**: Single mobile target `app-four`; this feature is confined to the Check-in MV(VM) slice — one view file, one decorative view, one view-model, one test file — matching the existing layout. No new directories.

## Research

### R1 — The Settle: one animatable canvas vs `matchedGeometryEffect`

**Decision**: Build the morph as a single animatable shape inside (or beside) `CrescentRing` — the arc trim animates closed/contracts and a checkmark path is drawn in the same canvas — rather than a `matchedGeometryEffect` between the recording ring and a separate `CheckInSavedView` circle. **Rationale**: the recording ring is an `AngularGradient`-stroked `Circle().trim` ([CrescentRing.swift#L13-31](../../app-four/Views/CheckIn/CrescentRing.swift#L13)) and the saved check is a filled `Circle` + SF `checkmark` ([CheckInView.swift#L286-294](../../app-four/Views/CheckIn/CheckInView.swift#L286)); morphing two *different* primitives via `matchedGeometryEffect` across a state switch is exactly the fiddly cross-fade the critique flags as "faked" ([critique §8](../../docs/ux-critique-checkin.md)). One canvas that owns "recording arc → check stroke" as a single progress-driven drawing is the textbook approach and degrades cleanly. **Reduce Motion**: the canvas renders the final check state instantly (`progress = 1`) when `reduceMotion` — mirrors the existing static-pop fallback ([CheckInView.swift#L317](../../app-four/Views/CheckIn/CheckInView.swift#L317)). **Haptic timing**: `Haptics.success()` fires once when the morph reaches completion (or immediately under Reduce Motion). Use a `Motion` token for the deceleration, not a raw literal ([Motion.swift](../../app-four/DesignSystem/Motion.swift)). **Alternatives rejected**: (a) keep the cross-dissolve — rejected, it's the unmet spec; (b) `matchedGeometryEffect` between two views — rejected as the harder, jankier path for two dissimilar shapes.

### R2 — Where the success haptic fires (once, both paths)

**Decision**: The single source of truth for "a capture just completed" is the VM's transition into `.done` (voice: [CheckInViewModel.swift#L107](../../app-four/ViewModels/CheckInViewModel.swift#L107); text: [#L274](../../app-four/ViewModels/CheckInViewModel.swift#L274)). The haptic is fired from the **view** at the moment the Settle resolves (so it's frame-aligned with the check), gated by a one-shot guard so a re-render can't double-fire. **Rationale**: firing from the view ties the buzz to the visible completion (the textbook "it landed" frame); a VM-side fire would lead the animation. The one-shot guard (e.g. fire on the morph's completion handler / `onAppear` of the resolved check, keyed so it runs once per `.done` entry) satisfies FR-002's idempotence. Under Reduce Motion there is no animation, so the haptic fires on appearance of the final check. **Alternative rejected**: firing inside `stopRecording()`/`saveTextCheckIn()` — rejected, it desyncs the buzz from the visual and complicates the Reduce-Motion path.

### R3 — Retry buffer shape & failure routing

**Decision**: Add a transient VM value capturing the just-stopped audio so a failed save can be retried without re-recording. The natural buffer is the `(fileURL, duration)` returned by `audioService.stopRecording()` ([CheckInViewModel.swift#L101](../../app-four/ViewModels/CheckInViewModel.swift#L101)) — i.e. the audio is already on disk; only the `saveRecording` / `store.addRecording` step failed. On failure, instead of `state = .idle` ([#L117](../../app-four/ViewModels/CheckInViewModel.swift#L117)), set a `saveFailed` flag (and keep the buffer); the view renders the inline retry line over the recording stage. Retry re-runs `saveRecording(from: buffer.fileURL, duration: buffer.duration)`; success clears the buffer + flag and proceeds to `.done`; repeated failure keeps both. Discard clears the buffer, releases the audio file, resets to `.idle`. **Rationale**: smallest possible state addition that makes discard structurally impossible (FR-005); reuses the existing storage call; mirrors the established alert/recovery vocabulary inline ([CheckInView.swift#L39-51](../../app-four/Views/CheckIn/CheckInView.swift#L39)) as the critique suggests ([§4 P2](../../docs/ux-critique-checkin.md)). **Lifetime**: in-memory for the session (see open clarification on cold-relaunch survival). **Cap path**: the 8-minute auto-stop calls the *same* `stopRecording()`, so a failure there routes through the identical buffer automatically (FR-015). **Text path (FR-009)**: `saveTextCheckIn` ([#L261](../../app-four/ViewModels/CheckInViewModel.swift#L261)) gains an analogous non-alarming failure flag rather than returning `Void` silently. **Alternative rejected**: a `saveFailed` *alert* mirroring `lowDiskSpace` — workable, but an inline line keeps the user in the capture context and is warmer than a modal; chosen per the brainstorm's "inline and gentle" recommendation.

### R4 — VoiceOver: announcement gating & the live region

**Decision**: (a) **Prompt advances** — post a `UIAccessibility` announcement on the visual prompt swap (driven by `currentPromptIndex` changing), but **suppress** it while the audio level indicates active voice; consume `audioLevelStream` ([Protocols.swift#L49-50](../../app-four/Services/Protocols.swift#L49)) into a lightweight `isSpeaking` signal on the VM (this finally gives the currently-discarded level stream, [CheckInViewModel.swift#L290-297](../../app-four/ViewModels/CheckInViewModel.swift#L290), a real, minimal job — the *announcement gate*, NOT a glow). When a swap occurs during active voice, defer the announcement until the next quiet. (b) **Live region** — group the crescent + timer into one accessibility element with a composed label "Recording, [elapsed] elapsed" and `.updatesFrequently`, throttled (e.g. announce on ~5–10s granularity, not every 0.1s tick) to avoid chatter. (c) **Transitions** — post "Saving…" on `.processing` and "Captured." on `.done`. **Rationale**: closes both P1 a11y gaps ([critique §6](../../docs/ux-critique-checkin.md)) without a visual redesign; the active-voice gate prevents the ironic "app talks over the speaker" failure the brainstorm calls out. **Modern API note**: prefer SwiftUI `AccessibilityNotification.Announcement(...).post()` where available on iOS 26, falling back to `UIAccessibility.post(notification:argument:)` only if needed (research during implementation; both are platform a11y APIs, Principle I-compliant). **Alternative rejected**: announcing on every tick or on every swap unconditionally — rejected as VoiceOver chatter / talking over the user.

### R5 — Cap-approach cue: one-shot, not a countdown

**Decision**: Derive an `isApproachingCap` boolean in the VM (true once `elapsedTime` crosses `maxDuration − approachWindow`), and a one-shot `hasShownCapApproach` guard so the cue shows exactly once. The view renders a single faint line ("wrapping up soon") on the transition, fading after a beat — explicitly NOT a ticking bar (the deadline-framing the brainstorm rejects). `approachWindow` is a named constant (a tuned content value, ~30s, documented), not magic. At the cap, the existing `stopRecording()` auto-call ([CheckInViewModel.swift#L282-285](../../app-four/ViewModels/CheckInViewModel.swift#L282)) already routes through the Settle once US1 lands, so the "graceful save" requirement is satisfied by US1 + this cue. **Rationale**: serves time-blind users ([DESIGN.md#L9](../../DESIGN.md#L9)) with one warm cue, honoring "no you're-late alarms" ([DESIGN.md#L86](../../DESIGN.md#L86)). **Alternative rejected**: a visible approaching countdown — rejected as clock-pressure.

### R6 — `startRecording()` re-entry guard

**Decision**: At the top of `startRecording()` ([CheckInViewModel.swift#L46](../../app-four/ViewModels/CheckInViewModel.swift#L46)), guard that the current state is startable — `.idle` (or `.done`, resetting first) — and early-return otherwise *before* any `elapsedTime = 0` or audio-session request. In `consumeAutoStart()` ([CheckInView.swift#L54-59](../../app-four/Views/CheckIn/CheckInView.swift#L54)), early-return when already `.recording`/`.paused`/`.processing` instead of calling through. **Rationale**: exactly the critique's prescribed fix ([§7 P1](../../docs/ux-critique-checkin.md)); prevents zeroing a live timer and double audio sessions. Also clear the stale `permissionDenied`/`lowDiskSpace` flags on a clean start ([critique §4 P3](../../docs/ux-critique-checkin.md)). **Testability**: the guard's effect (no state change, no second start) is directly unit-testable on the VM with the mock services. **Alternative rejected**: disabling the button during the async permission round-trip only — insufficient, the auto-start path also fires re-entrantly.

### R7 — First-launch hint storage

**Decision**: A single `@AppStorage("checkInHintSeen")` bool in `CheckInView`, set `true` when any capture starts. **Rationale**: matches the app's existing first-run/preference flag idiom ([DayCardSettingsSection.swift#L7](../../app-four/Views/Settings/DayCardSettingsSection.swift#L7), [MedicationBarView.swift#L8](../../app-four/Views/Components/MedicationBarView.swift#L8)); avoids a SwiftData schema touch (Principle IX). The hub already has the headline + ring; the hint is two ghost `Text`s gated on the flag — pure view work. **Alternative rejected**: a SwiftData `AppSettings` field — rejected, heavier and schema-touching for a UI-only one-time flag.

### Open clarifications (carried from spec)

- **Retry-buffer cold-relaunch survival**: session-lifetime is assumed sufficient for v1 (the failure surface already prevents a *silent* loss while the screen is alive). Persisting the buffer across a kill would mean writing a recovery record — out of scope unless the owner wants it.

## Data Model

**No new persisted entities. No schema change.** This feature is logic-and-UI over existing types.

- **`Recording`** (`@Model`, unchanged) — created by `AudioFileStorageService.saveRecording` / `store.createCheckInNote` exactly as today.
- **`CheckInDraft`** (struct, unchanged) — text-composer payload ([CheckInDraft.swift](../../app-four/Models/CheckInDraft.swift)).
- **`RecordingState`** (enum, unchanged) — `.idle/.recording/.paused/.processing/.done` ([AppEnums.swift#L14](../../app-four/Models/AppEnums.swift#L14)); this feature finally gives `.paused` a distinct rendering (FR-017) and routes the cap through `.processing → .done`.
- **`InterruptionType`** (enum, unchanged) — exists ([AppEnums.swift](../../app-four/Models/AppEnums.swift)); referenced only for the minimal paused visual.

**New transient VM state (not persisted):**

| Field | Type | Lifetime | Purpose |
|---|---|---|---|
| `pendingSave` (retry buffer) | a small value of `(fileURL: URL, duration: TimeInterval)` | session, cleared on save/discard | Re-attempt a failed save without re-recording (FR-005, FR-007). |
| `saveFailed` | `Bool` | session | Drives the inline "try again" surface (FR-006); replaces the silent `state = .idle`. |
| `textSaveFailed` | `Bool` | session | Non-alarming text-save failure surface (FR-009). |
| `isSpeaking` | `Bool` | session | Active-voice gate for prompt announcements (FR-010), derived from `audioLevelStream`. |
| `hasShownCapApproach` | `Bool` | per recording | One-shot guard for the cap cue (FR-014). |
| `isApproachingCap` | `Bool` (derived) | per recording | True in the final approach window (FR-014). |

**New UI-only flag (UserDefaults):** `checkInHintSeen: Bool` via `@AppStorage` (FR-018).

## Complexity Tracking

> No Constitution Check violations. Table intentionally empty.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| — | — | — |
