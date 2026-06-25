# Feature Specification: Settings — recovery, privacy & clarity

**Feature Branch**: `017-settings-recovery-privacy`

**Created**: 2026-06-23

**Status**: Draft

**Input**: Approved brainstorm + critique for the Settings view ([docs/brainstorm-settings.md](../../docs/brainstorm-settings.md), [docs/ux-critique-settings.md](../../docs/ux-critique-settings.md)). Take the recommended direction of each thread: kill the dead Reduce-Motion toggle (honor iOS only), add model-download failure recovery, add a privacy + acknowledgements footer and greenlight an encrypted journal export, and run the clarity "S-pass" (title, rename, documented typography exemption).

---

## Overview

Squirl's Settings screen ([app-four/Views/SettingsView.swift](../../app-four/Views/SettingsView.swift)) is structurally solid but ships three correctness-of-intent failures the critique scored as ship-blocking, plus a missing privacy surface. This feature fixes them as four independently-shippable slices:

1. **Remove a dead control.** The "Reduce Motion" toggle writes `UserDefaults["reduceMotion"]`, which nothing in the app reads — every animation gates on the iOS system setting (`@Environment(\.accessibilityReduceMotion)`). The concept is triplicated across `UserDefaults`, an orphaned `AppSettings.reduceMotionEnabled`, and the system environment. Delete the in-app control; honor the system setting only.
2. **Make the one active task recoverable.** Downloading the transcription model is the only thing a user actively *does* on this screen, and failures are swallowed to a log with the status dot silently reverting. Add a pre-download size/conditions line, an inline cause-specific error with Retry, and the ability to cancel a download in progress.
3. **Persist the privacy promise and make the journal portable.** "All private, all on this device" is spoken once in onboarding and never again; the OFL font licences and WhisperKit attribution are absent everywhere. Add a "Your data" section (privacy statement + open-source acknowledgements) now, and greenlight an encrypted single-file journal export as a deliberate feature.
4. **Clarity S-pass.** Add the missing "Settings" screen title (also a VoiceOver landmark), rename the opaque "Medical Context Prompt" to "Recognize medication names" and relocate it out of Accessibility, and formally document the native-iOS-chrome typography exemption.

**Out of scope (deferred to their own specs):** journal *import* / device-migration (round-trip restore); a broader "Calm mode"; rebranding the grouped `List` to Paper & Pollen chrome; the dead `AppSettings.defaultLanguage` transcription-locale picker (decided separately); an app-wide visible-title ruling for the other three tabs.

**Coordination with feature 015 (onboarding & first-run):** Feature 015 owns the model **download engine** (the download/queue, progress, retry-orchestration, and the typed failure cause it must surface). Settings is a **consumer**: it renders download state, offers delete/redownload, surfaces the cause-specific error 015 reports, and offers Retry/Cancel. This spec MUST NOT duplicate or fork the download engine. Where the current engine swallows the error ([app-four/Services/AIModelServiceImpl.swift#L45-L51](../../app-four/Services/AIModelServiceImpl.swift#L45) finishes the stream silently on failure), the recovery story depends on the engine being changed to **report the failure cause** — that engine change is 015's; this spec consumes it. See the plan's coordination note for the contract.

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Honor the system Reduce Motion (no dead control) (Priority: P1)

A user who wants calmer animation opens Settings expecting a "Reduce Motion" switch to do something. Today it does nothing — they flip it, the breathing crescent keeps moving, and the app silently breaks a promise on the exact screen where they reached for control. After this change there is no in-app motion toggle; the app already honors **iOS Settings › Accessibility › Motion** everywhere, and Settings shows one quiet, non-interactive line stating so. Nothing the user can touch lies to them.

**Why this priority**: This is the only **P0** in the critique — a control with no effect is worse than absent for an overwhelm-sensitive audience, and it is the root of a triplicated-state bug. It is the smallest change (delete-only), kills the bug today, and unblocks the rest by clearing the Accessibility section.

**Independent Test**: Remove the toggle and the two orphaned state stores; confirm via the app that toggling iOS system Reduce Motion still stills the crescent/onset pulse (unchanged, because those already read the system value), that no in-app motion switch exists, and that the new footer line renders.

**Acceptance Scenarios**:

1. **Given** the Settings screen, **When** the user views the Accessibility area, **Then** there is no interactive "Reduce Motion" toggle.
2. **Given** iOS system Reduce Motion is ON, **When** the user opens any animated screen (Check-in crescent, medication bar), **Then** motion is stilled exactly as before this change (no regression).
3. **Given** the Settings screen, **When** the user scans for motion controls, **Then** they see one muted-ink, non-interactive line stating Squirl follows the iOS motion setting.
4. **Given** the codebase after this change, **When** searched, **Then** `UserDefaults["reduceMotion"]` and `AppSettings.reduceMotionEnabled` no longer exist and nothing references them.

---

### User Story 2 - Recover from a failed model download (Priority: P1)

A user taps to download the transcription model. It is the only required asset and the only action on this screen. If it fails — no network, not enough space, or cellular downloads are off while on cellular — they currently get nothing: the status dot reverts and the failure is logged out of sight, a dead end with no exit for a time-blind, easily-discouraged user. After this change: before they tap, they see the size and recommended conditions; if it fails, they see a plain-language cause and a single "Try again"; and during a long download they can cancel.

**Why this priority**: **P1** — this is the screen's one active task and its biggest functional gap (the critique flagged it three times: no error state, no size hint, no cancel). Recovery directly serves the low-executive-function audience: the user must know what to *do*, not just that it broke.

**Independent Test**: With the download engine reporting each failure cause (provided by 015), simulate each cause and confirm the matching message + Retry appears inline; confirm the pre-download size/conditions line is present before tapping; confirm an in-progress download can be cancelled and the row returns to "not installed".

**Acceptance Scenarios**:

1. **Given** the model is not installed, **When** the user views the download row, **Then** a line shows the approximate size and that Wi-Fi is recommended (e.g. "~150 MB · Wi-Fi recommended").
2. **Given** a download fails with no network, **When** it fails, **Then** an inline error states there is no connection and offers "Try again", with no modal alarm.
3. **Given** a download fails for insufficient storage, **When** it fails, **Then** the inline error says there isn't enough space (and does not offer a pointless immediate retry as the only option).
4. **Given** "Download over Cellular" is off and the user is on cellular, **When** they tap download, **Then** they are told cellular downloads are off and offered a one-tap way to allow them (or to open iOS settings), rather than a generic failure after the fact.
5. **Given** a download is in progress, **When** the user chooses to cancel, **Then** the download stops, no partial/corrupt model is left installed, and the row returns to "not installed".
6. **Given** the user taps "Try again" after a transient failure, **When** the retry succeeds, **Then** the row shows "Installed" and the error clears.

---

### User Story 3 - See the privacy promise and the acknowledgements (Priority: P2)

A privacy-sensitive user looks in Settings for proof that Squirl keeps its "on-device only" promise and for the open-source credits any honest app owes. Today they find only a version string. After this change a "Your data" section restates, in calm plain language, that everything stays on the device, and lists the open-source components and font licences Squirl is obligated to acknowledge (WhisperKit; Fraunces, DM Sans, IBM Plex Mono under the SIL Open Font License).

**Why this priority**: **P2** — pure trust infrastructure with no data-layer risk (static copy + a list), and it discharges a real OFL attribution obligation that is currently met nowhere. High value, low cost, but it doesn't unblock other slices.

**Independent Test**: Confirm a "Your data" section renders with the on-device statement and an acknowledgements list naming WhisperKit and the three fonts under OFL; confirm the copy reuses the onboarding voice and uses no surveillance/marketing tone.

**Acceptance Scenarios**:

1. **Given** the Settings screen, **When** the user scrolls to "Your data", **Then** one or two muted-ink lines restate that recordings, check-ins, and extracted signals stay on this device and are not uploaded.
2. **Given** the "Your data" section, **When** the user opens acknowledgements, **Then** WhisperKit and the three fonts (Fraunces, DM Sans, IBM Plex Mono) are credited with their licence (OFL for the fonts).
3. **Given** the privacy statement, **When** read, **Then** it matches the existing onboarding promise wording and posture (calm, non-technical, no "military-grade"/marketing language).

---

### User Story 4 - Read the screen: title, plain labels, documented chrome (Priority: P2)

A distractible user opens Settings and lands straight on "AI Models" with no "Settings" heading to anchor on, then meets "Medical Context Prompt" — clinical jargon filed under Accessibility where it doesn't belong. After this change the screen carries a visible "Settings" title (which also gives VoiceOver a landmark it lacks today), and the medical-vocabulary control is renamed to "Recognize medication names", relocated to the Check-in/Transcription area, with a footer explaining its effect. The native grouped-`List` look is kept deliberately, with its typography exemption documented.

**Why this priority**: **P2** — recognition-over-recall fixes that reduce scan cost (a P1 in the critique for the missing title and the jargon), but lower-risk and not blocking. Each is a small, high-clarity-per-effort edit.

**Independent Test**: Confirm the screen shows a "Settings" title and VoiceOver announces a "Settings" heading; confirm the renamed control reads "Recognize medication names" with an effect-describing footer and lives in the Check-in/Transcription section, not Accessibility; confirm DESIGN.md records the native-chrome typography exemption.

**Acceptance Scenarios**:

1. **Given** the user opens the Settings tab, **When** the screen appears, **Then** a visible "Settings" title is shown (inline) and VoiceOver exposes a "Settings" heading/landmark.
2. **Given** the medical-vocabulary toggle, **When** the user finds it, **Then** it is labelled "Recognize medication names", sits under Check-in/Transcription (not Accessibility), and has a footer such as "Helps transcription spell medication and side-effect terms correctly."
3. **Given** the renamed control is toggled, **When** the user transcribes, **Then** the medical-vocabulary biasing behaves exactly as the old "Medical Context Prompt" did (same underlying setting, no behaviour change).
4. **Given** the design system, **When** a reviewer checks DESIGN.md, **Then** the native-iOS-`List` system-font usage in Settings is recorded as a deliberate, HIG-aligned exemption rather than an unflagged drift.

---

### Edge Cases

- **Download fails, then succeeds on retry** — the inline error MUST clear and the row MUST settle to "Installed"; no stale error text lingers (US2 #6).
- **Insufficient-space failure** — retry alone won't help; the message MUST name the cause (space) rather than implying a tap will fix it (US2 #3).
- **Cellular-off while on cellular** — surfaced as a specific, actionable message tied to the existing "Download over Cellular" toggle, ideally *before* the failed attempt (US2 #4). Any auto-retry MUST be Wi-Fi-only (FR-014); the app MUST NOT silently re-pull a ~150 MB asset over metered data.
- **Cancel mid-download** — must leave no partially-written model that reads as "Installed"; the filesystem-as-truth check ([app-four/Services/AIModelServiceImpl.swift#L75-L80](../../app-four/Services/AIModelServiceImpl.swift#L75)) must still report "not installed" afterward.
- **iOS system Reduce Motion toggled while Settings is open** — the new footer line is static copy and need not react live; app animations continue to honor the system value as they do today.
- **VoiceOver on the download row** — the row already lacks accessible labelling (per the critique's a11y audit); when the error/Retry/Cancel states are added they MUST be announced (cause + available action), and the decorative status dot MUST be hidden from VoiceOver.
- **Dynamic Type at accessibility sizes** — the new size/conditions and error lines MUST remain legible and not clip on the download row at AX sizes.
- **A user with no recordings** views "Your data" — the privacy statement still applies and reads sensibly with an empty journal.

---

## Requirements *(mandatory)*

### Functional Requirements

#### Reduce Motion (US1)

- **FR-001**: The Settings screen MUST NOT present any interactive in-app control for reducing motion.
- **FR-002**: The app MUST continue to honor the iOS system Reduce Motion setting in every animated view exactly as it does today (no animation may regress to ignoring it).
- **FR-003**: The system MUST remove the `UserDefaults["reduceMotion"]` value and the `AppSettings.reduceMotionEnabled` attribute, and no code may read or write either afterward.
- **FR-004**: The Settings screen MUST show a single muted-ink, non-interactive line communicating that Squirl follows the device's iOS motion setting.

#### Model-download recovery (US2)

- **FR-005**: Before download, the Settings screen MUST display the approximate model size and recommended conditions (Wi-Fi), reusing the size already named in onboarding (~150 MB, [app-four/Views/Onboarding/OnboardingView.swift#L175](../../app-four/Views/Onboarding/OnboardingView.swift#L175)).
- **FR-006**: When a download fails, the Settings screen MUST show an inline (non-modal) error describing the cause in plain language.
- **FR-007**: The system MUST distinguish at least these failure causes and message each distinctly: **no network**, **insufficient storage**, and **cellular-disabled-while-on-cellular**; any other failure MUST fall back to a generic but non-alarming message.
- **FR-008**: The inline error MUST offer a single "Try again" affordance that re-attempts the download.
- **FR-009**: For the cellular-disabled cause, the system MUST offer a one-tap path to allow cellular downloads (toggle the existing "Download over Cellular" setting) or to open iOS settings, surfaced before the failed attempt where detectable.
- **FR-010**: The system MUST let the user cancel a download in progress, returning the row to "not installed".
- **FR-011**: A cancelled or failed download MUST NOT leave a partially-written model that reports as installed (the filesystem-as-truth check MUST report "not installed").
- **FR-012**: Failure causes consumed by Settings MUST originate from the download engine owned by feature 015; Settings MUST NOT implement its own download/queue. [NEEDS CLARIFICATION: 015's failure-cause contract — the exact type Settings consumes — is finalized in 015; until then Settings maps from the engine's reported cause. This spec assumes 015 exposes a distinguishable cause for no-network / insufficient-space / cellular-disabled.]
- **FR-013**: Error and cancel states MUST be announced to VoiceOver (cause + available action), and the decorative status dot MUST be hidden from assistive technology.
- **FR-014**: Any automatic retry MUST be restricted to Wi-Fi; the system MUST NOT auto-retry a download over cellular. (Whether *any* auto-retry ships at all is 015's call; if present it obeys this Wi-Fi cap.)

#### Privacy & acknowledgements (US3)

- **FR-015**: The Settings screen MUST include a "Your data" section restating, in plain language, that recordings, check-ins, and extracted signals stay on the device and are not uploaded.
- **FR-016**: The "Your data" section MUST credit the open-source components and font licences Squirl uses: WhisperKit, and Fraunces / DM Sans / IBM Plex Mono under the SIL Open Font License.
- **FR-017**: The privacy copy MUST reuse the onboarding promise's voice and posture (calm, non-technical) and MUST NOT introduce surveillance or marketing language.
- **FR-018**: An encrypted single-file journal **export** is greenlit as a near-term feature and MUST be specified such that, when built, the exported copy is encrypted so the privacy promise survives the data leaving the sandbox, and is placed in Settings directly above the destructive "Clear All Data" so the destructive path always offers "save a copy first." [NEEDS CLARIFICATION: whether export ships *within* this feature's implementation phases or is split to its own follow-up spec — see Assumptions; the recommendation is to spec it here and gate its build as the final, optional phase. Import/migrate is explicitly out of scope.]

#### Clarity S-pass (US4)

- **FR-019**: The Settings screen MUST present a visible "Settings" title and expose a corresponding VoiceOver heading/landmark (today `title: ""` with no navigation title, [app-four/Views/SettingsView.swift#L18](../../app-four/Views/SettingsView.swift#L18)).
- **FR-020**: The control currently labelled "Medical Context Prompt" MUST be renamed to "Recognize medication names".
- **FR-021**: That control MUST be relocated out of the Accessibility section into the Check-in/Transcription area and given a footer describing its effect (e.g. "Helps transcription spell medication and side-effect terms correctly.").
- **FR-022**: The rename/relocate MUST NOT change the underlying behaviour or persisted value — it remains the same medical-vocabulary biasing setting (`UserDefaults.medicalPromptEnabled`, default `true`, [app-four/Utils/Constants.swift#L30-L33](../../app-four/Utils/Constants.swift#L30)).
- **FR-023**: DESIGN.md MUST record an explicit typography exemption: Settings deliberately uses native iOS grouped-`List` system-font chrome (an HIG-aligned choice), exempt from the "do not use SF/system as display or body" rule.
- **FR-024**: The Settings tab-reselect scroll-to-top animation MUST honor Reduce Motion and use a motion token rather than a raw literal (currently `withAnimation(.easeOut(duration: 0.25))`, ungated, [app-four/Views/SettingsView.swift#L36](../../app-four/Views/SettingsView.swift#L36)).

### Key Entities *(include if feature involves data)*

- **AppSettings** (existing SwiftData `@Model`): the `reduceMotionEnabled` attribute is **removed** (FR-003). All other attributes (`downloadOverCellular`, `promptPaceSeconds`, `hasCompletedOnboarding`, `defaultLanguage`, `transcriptionCount`) are unchanged by this feature. Schema stays CloudKit-compatible (all attributes optional/defaulted; removal only).
- **Download failure cause** (consumed, not owned): a distinguishable reason a model download failed (no-network / insufficient-space / cellular-disabled / other), reported by feature 015's download engine and mapped by Settings to user-facing copy and the appropriate recovery affordance. No new persisted entity in Settings.
- **Journal export archive** (future, greenlit not built here): a single encrypted file bundling recordings, check-ins, and extracted signals — "a copy you control." Its data model is defined when its build phase/spec is undertaken; **import is out of scope**.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: There is no interactive control in Settings whose toggling produces no observable effect (the dead Reduce-Motion control is gone); a source search finds zero references to `reduceMotion`/`reduceMotionEnabled` as app state.
- **SC-002**: 100% of the three named download-failure causes (no-network, insufficient-space, cellular-disabled) produce a distinct, plain-language inline message with an appropriate recovery action; no failure path is silent.
- **SC-003**: A user can cancel an in-progress download and reach a clean "not installed" state in one tap, with no orphaned/partial model reported as installed.
- **SC-004**: Before committing to the ~150 MB download, the size and recommended conditions are visible on the row (the metered-data surprise is preventable, not post-hoc).
- **SC-005**: Settings exposes a persistent on-device privacy statement and complete open-source/font acknowledgements (WhisperKit + three OFL fonts) — discharging the attribution obligation currently met nowhere in the app.
- **SC-006**: The Settings screen shows a visible "Settings" title and VoiceOver announces a "Settings" landmark; no tab lands the user on a section header as the first label.
- **SC-007**: The medical-vocabulary control is found under Check-in/Transcription with effect-describing copy and zero clinical jargon ("Medical Context Prompt" no longer appears in the UI), with identical transcription behaviour.
- **SC-008**: The native-chrome typography exemption is documented in DESIGN.md, converting an unflagged drift into a deliberate decision.
- **SC-009**: No animation regresses on Reduce Motion: with iOS system Reduce Motion ON, every previously-gated animation (crescent breathe/revolve, onset pulse, calendar/insights transitions, Settings scroll-to-top) remains stilled.

## Assumptions

- **015 owns the download engine and will surface failure causes.** This spec assumes feature 015 (onboarding & first-run) is the home of the model download/queue and will expose a distinguishable failure cause (no-network / insufficient-space / cellular-disabled / other) that Settings consumes. The current engine swallows the error ([AIModelServiceImpl.swift#L45-L51](../../app-four/Services/AIModelServiceImpl.swift#L45)); making it report the cause is 015's work. If 015 has not landed that contract when Settings is built, the plan's Phase 0 defines the minimal cause-reporting seam Settings needs and 015 adopts it — Settings still does not fork the engine.
- **No network-reachability capability exists yet.** There is no `NWPathMonitor`/reachability service in the app today (only a Diagnostics metric reference). Detecting "no network" vs "cellular-disabled-while-on-cellular" *before* a tap requires such a capability; the plan treats it as a small service seam (shared with/owned by 015) rather than ad-hoc code in the view.
- **The medical-vocabulary setting keeps its `UserDefaults` home.** `UserDefaults.medicalPromptEnabled` (default `true`) is read off-main by the transcription actor; the rename/relocate is UI/labelling only and does not migrate the value (FR-022).
- **Reduce Motion removal is delete-only and safe.** Every animated view already reads `@Environment(\.accessibilityReduceMotion)` (verified across 7 files); deleting the toggle + the two orphaned stores cannot change runtime motion behaviour.
- **Export is greenlit and specified here, but its *build* may be the final optional phase or split to a sibling spec at the owner's discretion** (FR-018); **import/migrate is firmly out of scope** for 017 and belongs to its own later spec. Export format intent is an **encrypted archive** (recommended over plain JSON / Health-style), labelled warmly ("Save a copy of my journal — yours to keep"), not "export".
- **Settings keeps native grouped-`List` chrome.** No Paper & Pollen rebrand of the list; the typography exemption is documented instead (FR-023). The app-wide visible-title question (whether the other three tabs also get titles) is **not** resolved here — only Settings gains a title; a one-time app-wide ruling is left to a separate decision so this title isn't an orphan.
- **Mock test infrastructure exists.** `MockAIModelService` (with `setShouldThrowOnDownload`) and `MockAppServices` already exist ([app-fourTests/Mocks/](../../app-fourTests/Mocks/)); the disabled `SettingsViewModelTests` can be restored against them.
