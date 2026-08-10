# Feature Specification: Update PR37 (Model Interception & Settings Integration)

**Feature Branch**: `041-update-pr37`

**Created**: 2026-08-10

**Status**: Draft

**Input**: User description: "run speckit-specify to append Settings Integration Phase 3"

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

### User Story 2 (Phase 3) - Manual Model Management in Settings (Priority: P2)

As a user, I want to manage the Whisper AI model from the app Settings, so that I can manually trigger the download over Wi-Fi when I have time, check its current installation status, or delete it if I need to free up storage space.

**Why this priority**: Empowers users to control their device storage and provides a non-interruptive way to download the model outside of the core check-in flow.

**Independent Test**: Navigate to Settings, observe the model status row. Tap to download, observe progress, then tap to delete and observe the model is removed.

**Acceptance Scenarios**:

1. **Given** the user navigates to the Settings tab, **Then** there is a row displaying the Whisper model status (e.g., "Not Installed", "Downloading X%", "Installed").
2. **Given** the model is not installed, **When** the user taps the row, **Then** the download starts, showing real-time progress.
3. **Given** the model is installed, **When** the user taps the row (or a delete action), **Then** a confirmation dialog appears warning them about deleting the model. Upon confirming, the model is deleted and the status reverts to "Not Installed".
4. **Given** a download is in progress, **When** the user taps the row, **Then** the download is cancelled.

---

### Edge Cases

- What happens when the app is backgrounded or the screen locks during the 150MB model download while recording? (The download is wrapped in a background task assertion so it completes successfully).
- How does the system handle recording stops before the download completes? (Saves audio with `.pendingTranscription` status; the existing `PendingTranscriptionService` drains it once the model lands).
- What happens if the background download fails due to network issues? (A retry prompt is presented to the user).
- What happens if there is not enough free storage space for the 150MB model? (An explicit "Not enough space in storage" error is shown).
- **Phase 3:** What happens if the user deletes the model while a pending transcription exists? (The transcription remains pending until the model is re-downloaded).
- **Phase 3:** What happens to the Settings UI if the download fails? (It shows an error state and allows tapping to retry).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST intercept manual recording via the UI if `AIModelService.localPath` is nil and `isDownloading` is false.
- **FR-002**: System MUST present a system-native alert (`.alert`) to prompt the download.
- **FR-003**: System MUST NOT block the user from recording while the model downloads (i.e. start recording immediately upon "Download & Record").
- **FR-004**: System MUST ensure background download tasks are preserved using `UIApplication.shared.beginBackgroundTask` to survive app backgrounding.
- **FR-005**: System MUST allow the background download to proceed even if the user is not on a Wi-Fi network (bypass cellular restrictions for this specific prompt).
- **FR-006**: System MUST show a retry prompt if the model download fails.
- **FR-007**: System MUST check for available storage before starting the download and show a "Not enough space in storage" error if there is less than the required space (~150MB plus buffer).
- **FR-008 (Phase 3)**: System MUST provide a UI in Settings to display the current installation status and progress of the Whisper model.
- **FR-009 (Phase 3)**: System MUST allow the user to initiate the model download manually from Settings.
- **FR-010 (Phase 3)**: System MUST allow the user to delete the downloaded model from Settings to free up local storage, preceded by a confirmation dialog.
- **FR-011 (Phase 3)**: System MUST allow the user to cancel an in-progress download from Settings.

### Key Entities *(include if feature involves data)*

- **AIModelService**: Manages the Whisper model file state, download progress, cancellation, deletion, cellular overrides, and background lifecycle.
- **CheckInViewModel**: Manages the UI state, alert presentation, storage checks, and pre-flight recording logic.
- **PendingTranscriptionService**: Automatically observes model availability and drains pending recordings.
- **SettingsViewModel**: Manages the UI state for the model download status and actions in the Settings tab.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can successfully initiate and complete a background download of the Whisper model while actively recording.
- **SC-002**: 100% of recordings captured while the model is downloading are automatically transcribed once the download completes, without manual intervention.
- **SC-003**: Users can successfully download, cancel, and delete the Whisper model manually via the Settings UI.

## Assumptions

- The existing `PendingTranscriptionService` is fully tested and robust enough to handle the delayed transcription scenarios out of the box.
- The UX decision to use a standard iOS alert (rather than a custom styled overlay) is approved for accessibility and simplicity.
- The existing design tokens and settings list patterns will be used for the new Settings row.
