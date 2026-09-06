# Feature Specification: Adopt SpeechAnalyzer/SpeechTranscriber, fall back to DictationTranscriber, remove WhisperKit

**Feature Branch**: `045-speechanalyzer-migration`

**Created**: 2026-09-06

**Status**: Draft

**Input**: User description: "Adopt Apple's on-device SpeechAnalyzer/SpeechTranscriber as the primary speech-to-text engine for voice check-ins, with DictationTranscriber as an automatic fallback where SpeechTranscriber is unavailable (unsupported hardware or locale), and remove the WhisperKit dependency and its bundled/downloaded Whisper model from the codebase."

## Overview *(why)*

Voice check-ins are transcribed on-device today by WhisperKit running OpenAI Whisper Small — a large model (~500 MB) that must be delivered to the device, a path that is failure-prone enough to have its own hardening work. Apple's iOS 26 `SpeechAnalyzer` stack provides a **system-managed, shared, 0-MB-to-the-app** on-device speech model that is designed for long-form, conversational dictation. This feature replaces the app's primary transcription engine with `SpeechTranscriber`, adds `DictationTranscriber` as an automatic fallback for hardware/locales `SpeechTranscriber` does not support, and removes WhisperKit and its bundled model entirely. The outcome for the user: transcription that is at least as accurate, available faster on first use, with a smaller install and far fewer download failures — while all audio and transcripts stay on-device.

## Clarifications

### Session 2026-09-06

- Q: What happens to the existing `SFSpeechRecognizer`-based path (`SpeechTranscriptionService`)? → A: **Remove it.** The fallback ladder is exactly `SpeechTranscriber` → `DictationTranscriber`, with no third tier (clean on the iOS 26+ floor).
- Q: Capture mode — live/streaming or record-then-transcribe-from-file? → A: **Live/streaming** — feed the analyzer as audio is captured, show partial (volatile) results while the user speaks, finalize on stop.
- Q: Should the transcription layer bias toward domain terms (ADHD lexicon, medication names) via contextual strings? → A: **None initially** — keep domain handling in the extraction pipeline; revisit only if proper-noun accuracy proves insufficient.
- Q: Migration for existing users updating from a WhisperKit build? → A: **None** — leave stored transcripts untouched; do not re-transcribe historical audio.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Speak a check-in and get an accurate on-device transcript (Priority: P1)

A user records a spoken check-in. The app transcribes it entirely on-device using Apple's system speech model, and the transcript appears (streaming as they speak where supported, finalized when they stop). No audio or text leaves the device, and no network is required once the model is present.

**Why this priority**: This is the core loop of the product (speak → transcribe → extract → view). If transcription regresses, the whole product regresses. It is the minimum viable slice — everything else is graceful-degradation and cleanup around it.

**Independent Test**: On a SpeechTranscriber-supported device (verified: iPhone 12 Pro / A14, iOS 26) in a supported locale, record a spoken check-in with the device in airplane mode (model already installed) and confirm an accurate transcript is produced and stored, with no network access.

**Acceptance Scenarios**:

1. **Given** a supported device with the speech model installed and microphone permission granted, **When** the user records a spoken check-in, **Then** a transcript is produced on-device and attached to the check-in, matching the outgoing engine's accuracy or better.
2. **Given** the same, **When** the user is speaking, **Then** partial/volatile text is shown live where the engine provides it, and is replaced by the finalized transcript when recording stops.
3. **Given** a completed transcription, **When** the downstream extraction pipeline runs, **Then** it receives the transcript through the existing transcription boundary unchanged (no change to extraction behavior).

---

### User Story 2 - Transcription still works on unsupported hardware or locales (Priority: P2)

A user on a device where `SpeechTranscriber` is not available (e.g. an older 8-core-Neural-Engine device) or whose locale `SpeechTranscriber` does not cover still gets their check-in transcribed, automatically, via `DictationTranscriber` — without any manual choice or error.

**Why this priority**: The primary engine is hardware- and locale-gated. Without a fallback, a segment of users would lose the core feature entirely. It must degrade silently and correctly, but it is second to making the primary path work.

**Independent Test**: Force the unsupported path (a device/locale where `SpeechTranscriber.isAvailable` is false or the locale is unsupported) and confirm the check-in still transcribes via the fallback, with no user-facing error and no manual engine selection.

**Acceptance Scenarios**:

1. **Given** a device where `SpeechTranscriber` is unavailable, **When** the user records a check-in, **Then** the app transcribes it via `DictationTranscriber` automatically and the user is not asked to choose an engine.
2. **Given** a locale supported by `DictationTranscriber` but not by `SpeechTranscriber`, **When** the user records, **Then** the fallback engine is selected for that locale.
3. **Given** the current device locale is a regional English variant not in the primary engine's supported list, **When** transcription runs, **Then** the app resolves to the nearest supported variant rather than treating the locale as unsupported.

---

### User Story 3 - Smaller install and reliable first-run, with WhisperKit gone (Priority: P3)

A user installing or updating the app no longer receives (or has the app download) the large Whisper model. Transcription's on-device model is provided by the system. The app is smaller, first-run is more reliable, and there is no bespoke large-model download to fail.

**Why this priority**: This is the structural payoff and the explicit "remove WhisperKit" half of the request. It is lower priority than a working transcription path, but it is the reason to do the migration and it removes a whole class of first-run failures.

**Independent Test**: On a clean install, confirm the app does not bundle or initiate a multi-hundred-MB Whisper download, and that no WhisperKit code or dependency remains (dependency + source grep returns zero). Confirm transcription becomes available after at most a system-managed asset fetch.

**Acceptance Scenarios**:

1. **Given** a clean install on a supported device, **When** the user first records a check-in, **Then** the app does not perform an app-initiated large (~500 MB) model download; any required model is obtained through the system-managed asset mechanism.
2. **Given** the shipped build, **When** the codebase and dependency manifest are inspected, **Then** there are zero references to WhisperKit and no bundled Whisper model file.
3. **Given** an existing user updating from a WhisperKit build, **When** they open the app, **Then** their existing check-ins and transcripts remain intact and viewable.

---

### Edge Cases & Error Handling

#### 1. Network & Connectivity Failures

- **Scenario:** First use on a supported device where the required speech model asset is **not yet installed**, and the device is offline.
- **System Behavior:** Transcription of that recording is deferred; the captured audio is persisted and the transcript is produced automatically once the model asset can be fetched (when connectivity returns). If a fallback engine's model is already present, the app uses it instead of waiting. No recording is discarded.
- **User Experience (UX):** A clear, non-blocking "preparing speech model" / "transcription pending" state on the affected check-in, with automatic retry; the user can keep recording other check-ins. No dead-end error.

- **Scenario:** Network is lost **mid-transcription**.
- **System Behavior:** In-progress transcription is unaffected — it runs fully on-device once the model is present; only the *initial* model download needs network.
- **User Experience (UX):** No interruption; transcription completes normally.

#### 2. Data Validation & Bad Input

- **Scenario:** Silent, empty, or non-speech audio (background noise only); or an extremely long recording; or a corrupt/unreadable audio file.
- **System Behavior:** Silence/non-speech yields an empty or "no speech detected" transcript, not a crash. Long recordings are supported (the primary engine is designed for long-form). A corrupt/unreadable file surfaces a handled error and preserves the original recording for retry.
- **User Experience (UX):** Empty result is shown as "no speech detected" (editable), not an error. Corrupt-input error is a retriable message, and the raw recording is never silently lost.

#### 3. State Restoration & Interruptions

- **Scenario:** The app is backgrounded, the screen locks, a phone call arrives, or the audio route changes (e.g. headphones unplugged) **mid-recording**.
- **System Behavior:** The capture session handles the interruption without corrupting or losing captured audio; on resume it continues or cleanly finalizes what was captured. A partial transcript up to the interruption point is preserved.
- **User Experience (UX):** The user sees a clear recording/paused state and either resumes or is left with a finalized partial transcript they can keep or re-record — never a corrupted or empty result from an interruption.

- **Scenario:** The app crashes or is killed mid-transcription.
- **System Behavior:** Captured audio is persisted before/independently of transcription so the transcript can be regenerated on next launch; no data is lost.
- **User Experience (UX):** On relaunch the affected check-in shows a "transcription pending/retry" state rather than a missing entry.

#### 4. Hardware/Permission Denials

- **Scenario:** Microphone permission is denied or revoked.
- **System Behavior:** Recording is not attempted; the app does not crash and remains usable for everything that does not require the mic.
- **User Experience (UX):** A clear explanation and a direct path to enable microphone access in Settings.

- **Scenario:** `SpeechTranscriber` is unavailable on the hardware, **and** `DictationTranscriber` is also unavailable/unusable for the locale.
- **System Behavior:** The app still captures and persists the audio; it reports that on-device transcription is not available for this device/locale, without discarding the recording.
- **User Experience (UX):** An informative state on the check-in ("transcription unavailable on this device") with the audio retained, rather than a silent failure or crash.

- **Scenario:** The OS reclaims/updates the shared speech model asset between launches.
- **System Behavior:** The app treats installed-model state as environmental and re-checks each session; it re-requests the asset if needed rather than assuming a cached "installed" flag.
- **User Experience (UX):** At worst a brief "preparing model" state on next transcription; never a hard failure.

- **Scenario:** Transcription is requested while another on-device ML workload (e.g. the extraction pass) is active and the system's concurrent-analysis limit is hit.
- **System Behavior:** The app treats a resource-limit condition as expected back-pressure — it serializes or retries rather than forcing past the limit.
- **User Experience (UX):** Transcription completes after the contended workload; no crash or dropped transcript.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST transcribe recorded check-in audio entirely on-device; neither audio nor transcript text may leave the device (aligns with the On-Device Privacy principle).
- **FR-002**: The system MUST use `SpeechAnalyzer`/`SpeechTranscriber` as the primary transcription engine on devices and locales where it is available.
- **FR-003**: The system MUST determine transcription availability at runtime (device capability AND locale) and MUST automatically fall back to `DictationTranscriber` when `SpeechTranscriber` is unavailable — with no user-facing engine choice.
- **FR-004**: The system MUST resolve the user's current locale to the nearest supported transcription locale rather than requiring an exact match, so users on regional locale variants are not incorrectly treated as unsupported.
- **FR-005**: The system MUST obtain any required on-device speech model through the system-managed asset mechanism; it MUST NOT bundle or app-download a large ASR model.
- **FR-006**: The system MUST NOT retain any WhisperKit dependency, bundled Whisper model file, or Whisper-specific transcription code path after this feature ships.
- **FR-007**: The system MUST present live/partial (volatile) transcription text during recording where the engine provides it, and a finalized transcript when recording ends.
- **FR-008**: When the required model is not yet installed, the system MUST NOT lose the recording; it MUST persist the audio and produce the transcript once the model is available, and clearly communicate the pending state.
- **FR-009**: The system MUST leave the existing check-in/transcript data model and the downstream extraction pipeline unchanged; transcription remains a swappable layer behind the existing transcription boundary in `Services/` (aligns with Service-Oriented Architecture).
- **FR-010**: The system MUST handle microphone permission denial without crashing and MUST guide the user to enable access.
- **FR-011**: The system MUST handle silent/empty/non-speech audio without crashing, producing an empty or "no speech detected" result.
- **FR-012**: The system MUST handle audio interruptions (calls, route changes, backgrounding, lock) without losing captured audio or corrupting the transcript.
- **FR-013**: No SwiftUI view or view-model may reference a concrete transcription engine; the capability MUST stay behind a protocol so it is mockable and swappable at the seam.
- **FR-014**: The system MUST NOT regress viewing, editing, or exporting of existing check-ins and their transcripts.
- **FR-015**: Diagnostics/logging for transcription MUST record counts, durations, and status only — never transcript text.
- **FR-016**: The system MUST select the fallback engine per-recording based on the availability determination at the time of that recording (availability can change between sessions as assets are installed/reclaimed).
- **FR-017**: The system MUST remove the existing `SFSpeechRecognizer`-based transcription path (`SpeechTranscriptionService`); the fallback ladder is exactly `SpeechTranscriber` → `DictationTranscriber`, with no third tier.
- **FR-018**: The system MUST use live/streaming capture — audio is fed to the analyzer as it is captured, partial (volatile) results are shown while the user speaks, and the transcript is finalized when recording stops (not record-then-transcribe-from-file).
- **FR-019**: The system MUST NOT add transcription-layer vocabulary biasing in this feature; domain/proper-noun handling stays in the extraction pipeline. (Contextual-string biasing MAY be revisited later if proper-noun accuracy proves insufficient.)
- **FR-020**: The system MUST NOT require any data migration for existing users: stored transcripts are left untouched and historical audio is NOT re-transcribed.

### Key Entities *(include if feature involves data)*

- **Transcript segment**: the unit passed across the transcription boundary — text, start/end time, finalized-vs-volatile flag, optional confidence. (Matches the existing transcription DTO; no schema change intended.)
- **Transcription capability**: the runtime determination for a given recording — whether the primary engine is available, which engine and locale were selected, and the model-installed state. (Ephemeral, not persisted.)
- **Speech model asset**: the system-managed on-device model, in one of: available/installed, downloading, not-installed. Owned by the OS, not the app.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The app's install/download footprint is reduced by approximately the size of the removed Whisper model (~500 MB) — measured before/after.
- **SC-002**: On a clean install on a supported device, a user can complete their first transcription without any app-initiated multi-hundred-MB download (at most a system asset fetch) — verified on device.
- **SC-003**: Transcription accuracy on a fixed English check-in evaluation set is no worse than the outgoing engine (no measurable WER regression), and latency to first result is acceptable for live capture (target verified on device).
- **SC-004**: On an unsupported device or locale, 100% of recorded check-ins still receive an on-device transcript via the fallback (zero hard failures).
- **SC-005**: No transcription failure results in lost audio — in every error path the raw recording remains recoverable.
- **SC-006**: Zero references to WhisperKit remain in the codebase and dependency manifest after the migration (grep/dependency audit returns zero).
- **SC-007**: The full existing test suite passes, and existing check-ins/transcripts remain intact and viewable after updating from a WhisperKit build.

## Assumptions

- The app's minimum deployment target is **iOS 26+** (per the constitution and SPECKIT hard constraints), so no pre-iOS-26 transcription floor is required and WhisperKit can be removed entirely rather than kept for OS compatibility.
- `SpeechTranscriber` availability has been **verified on the primary test device** (iPhone 12 Pro / A14, iOS 26.6.1) via an on-device probe, including a successful model download and end-to-end transcription.
- The existing transcription boundary in `Services/` (protocol + transcript DTO) remains the integration seam; the downstream extraction pipeline is unaffected by this feature.
- The on-device speech model is Apple-managed and shared system-wide; its storage, updates, and reclamation are handled by the OS, not the app.
- Removing WhisperKit changes the app's model memory lifecycle (Whisper no longer loads/unloads in-process); the peak-shaving sequence around extraction must be re-evaluated at plan time.

## Dependencies

- **Constitution amendment (required before ship)**: the Technology Stack section names WhisperKit/Whisper Small as the transcription engine, and Principle VII references "Whisper unloads before Llama loads." Removing WhisperKit and adopting SpeechAnalyzer requires amending both (a MINOR version bump) — to be handled at `/speckit-plan`/governance time, not silently.
- **Technical reference**: the verified adoption guide at `docs/engineering/speechanalyzer-adoption.md` (API surface, fallback ladder, asset lifecycle, audio pipeline, gotchas) is the source for the plan phase.
- **Backlog/log**: a new backlog entry and devlog note for this migration.

## Out of Scope

- Changing the extraction pipeline (`MLXJournalService`) or the lexicon.
- Multilingual transcription beyond what `SpeechTranscriber`/`DictationTranscriber` provide out of the box.
- Any cloud/server transcription fallback (prohibited by the On-Device Privacy principle).
- Re-transcribing historical audio already captured on prior builds.
- Consolidating extraction into Apple's on-device language model (a separate, later question).
