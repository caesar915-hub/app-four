# Feature Specification: Update PR37 (Model Interception)

**Feature Branch**: `041-update-pr37`

**Created**: 2026-08-10

**Status**: Draft

**Input**: User description: "run speckit-specify on the branch feat/1.1-release-prep) to update PR37"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Model Download Interception Before Recording (Priority: P1)

As a user who skipped the 150MB Whisper model download during onboarding, I want to be prompted to download it when I try to record my first voice check-in, so that I don't accidentally record audio that never gets transcribed and understand why the model is needed.

**Why this priority**: Core user flow for those who skipped onboarding. Voice is the primary input method for the app.

**Independent Test**: Can be fully tested by deleting the local model, tapping the microphone, seeing the alert, and accepting the download while recording proceeds.

**Acceptance Scenarios**:

1. **Given** the Whisper model is not downloaded, **When** the user taps the microphone button, **Then** a system-native alert appears explaining the need for the model.
2. **Given** the alert is visible, **When** the user taps "Download & Record", **Then** the recording starts immediately, the UI transitions to recording state, and the model begins downloading in the background.
3. **Given** the alert is visible, **When** the user taps "Record Only", **Then** the recording starts immediately and is saved to the pending queue for later transcription.
4. **Given** the alert is visible, **When** the user taps "Cancel", **Then** the alert dismisses and the app remains in the idle check-in state.

---

### Edge Cases

- What happens when the app is backgrounded or the screen locks during the 150MB model download while recording? (The download is wrapped in a background task assertion so it completes successfully).
- How does the system handle recording stops before the download completes? (Saves audio with `.pendingTranscription` status; the existing `PendingTranscriptionService` drains it once the model lands).
- What happens if the background download fails due to network issues? (A retry prompt is presented to the user).
- What happens if there is not enough free storage space for the 150MB model? (An explicit "Not enough space in storage" error is shown).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST intercept manual recording via the UI if `AIModelService.localPath` is nil and `isDownloading` is false.
- **FR-002**: System MUST present a system-native alert (`.alert`) to prompt the download.
- **FR-003**: System MUST NOT block the user from recording while the model downloads (i.e. start recording immediately upon "Download & Record").
- **FR-004**: System MUST ensure background download tasks are preserved using `UIApplication.shared.beginBackgroundTask` to survive app backgrounding.
- **FR-005**: System MUST allow the background download to proceed even if the user is not on a Wi-Fi network (bypass cellular restrictions for this specific prompt).
- **FR-006**: System MUST show a retry prompt if the model download fails.
- **FR-007**: System MUST check for available storage before starting the download and show a "Not enough space in storage" error if there is less than the required space (~150MB plus buffer).

### Key Entities *(include if feature involves data)*

- **AIModelService**: Manages the Whisper model file state, download progress, cellular overrides, and background lifecycle.
- **CheckInViewModel**: Manages the UI state, alert presentation, storage checks, and pre-flight recording logic.
- **PendingTranscriptionService**: Automatically observes model availability and drains pending recordings.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can successfully initiate and complete a background download of the Whisper model while actively recording.
- **SC-002**: 100% of recordings captured while the model is downloading are automatically transcribed once the download completes, without manual intervention.

## Assumptions

- The existing `PendingTranscriptionService` is fully tested and robust enough to handle the delayed transcription scenarios out of the box.
- The UX decision to use a standard iOS alert (rather than a custom styled overlay) is approved for accessibility and simplicity.
