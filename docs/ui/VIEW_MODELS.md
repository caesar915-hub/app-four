# ViewModel Catalog

_Last updated: 2026-06-28_

This document describes each ViewModel in Squirl: what screen it drives, what state it owns, and how it interacts with Services and the Store.

---

## Table of Contents

- [Conventions](#conventions)
- [Capture Flow](#capture-flow)
- [Library Flow](#library-flow)
- [Insights Flow](#insights-flow)
- [Detail & Review](#detail--review)
- [Medication](#medication)
- [Settings](#settings)
- [Model Types Used by Views](#model-types-used-by-views)
- [Adding a ViewModel](#adding-a-viewmodel)

---

## Conventions

- All ViewModels are `@Observable` and `@MainActor`.
- Dependencies are injected via initializer.
- ViewModels do not access `AppDependencies` directly.
- Heavy work is delegated to services; UI state is updated on the main actor.
- `RecordingStore` is the single access point for recording mutations.
- Shared/global ViewModels (`MedicationBarViewModel`, `MedicationPickerViewModel`) may use a default global `ModelContext` when not injected.

---

## Capture Flow

### `CheckInViewModel`

**File:** `app-four/ViewModels/CheckInViewModel.swift`
**Drives:** `CheckInView`

Owns the entire voice/text capture lifecycle.

| State | Type | Purpose |
|-------|------|---------|
| `state` | `RecordingState` | Current capture phase: `.idle`, `.recording`, `.processing`, `.done`. (`RecordingState.paused` exists in the enum but this ViewModel does not use it.) |
| `elapsedTime` | `TimeInterval` | Recording timer, increments every 0.1s |
| `maxDuration` | `TimeInterval` | 8-minute soft cap |
| `approachWindow` | `TimeInterval` | ~30s window before the cap |
| `isApproachingCap` | `Bool` | Computed: recording is within the approach window |
| `hasShownCapApproach` | `Bool` | One-shot latch for the "wrapping up soon" cue |
| `permissionDenied` | `Bool` | Mic permission alert |
| `lowDiskSpace` | `Bool` | Disk space alert |
| `saveFailed` | `Bool` | Inline save-failure recovery (UI stays in `.processing`) |
| `textSaveFailed` | `Bool` | Text check-in save failure |
| `promptInterval` | `TimeInterval` | Seconds per prompt, loaded from `AppSettings` |
| `pendingSave` | `PendingSave?` | Buffered audio file for retry |
| `lastSavedRecording` | `Recording?` | Recording shown in saved confirmation |
| `isSpeaking` | `Bool` | Active-voice gate for VoiceOver announcements |
| `promptAnnouncementIsPending` | `Bool` | A prompt advance is queued for announcement |

**Computed properties exposed to the view:**

- `timeString`, `maxTimeString` — formatted elapsed/cap times.
- `currentPromptIndex` — computed from `elapsedTime / promptInterval`.
- `currentPrompt` — the active `NudgePrompt`.
- `promptProgress` — progress within the current prompt window.
- `promptAnnouncementIsEligible` — `promptAnnouncementIsPending && !isSpeaking`.

**Key methods:**

- `startRecording()` — permission/disk check, begin recording, start timer and level monitoring, preload transcription model.
- `stopRecording()` — stop recorder, buffer file, attempt save, chain transcription.
- `retrySave()` — re-attempt saving a buffered recording.
- `discardFailedCapture()` — discard buffered audio and return to idle.
- `cancelRecording()` — cancel everything and reset.
- `saveTextCheckIn(_:)` — persist a text check-in draft.
- `markCapApproachShown()` — consume the one-shot cap-approach cue.
- `requestPromptAnnouncement()` / `consumePromptAnnouncement()` — VoiceOver announcement gate.
- `reset()` / `advanceTick()` / `ingestAudioLevel(_:)` — internal lifecycle helpers.

**Dependencies:** `AudioRecordingService`, `AudioFileStorageService`, `TranscriptionService`, `AIModelService`, `RecordingStore`, `ProcessingViewModel`.

### `ProcessingViewModel`

**File:** `app-four/ViewModels/ProcessingViewModel.swift`
**Used by:** `CheckInViewModel`

Runs the **post-transcription** NLP extraction pipeline. It does **not** transcribe; transcription is handled by `CheckInViewModel`.

| State | Purpose |
|-------|---------|
| `activeTask` | Current processing task; cancelled when a new processing request arrives |

**Key methods:**

- `processRawTranscription(_:duration:language:audioFileName:fillOnly:)` — fetch recording → set `.generating` → summarize → `applySummary` → `setMedicationEvents` → save.
- `cancelProcessing()` — cancel the active processing task.

**Dependencies:** `RecordingStore`, `SummarizationService`.

---

## Library Flow

### `MoodLibraryViewModel`

**File:** `app-four/ViewModels/MoodLibraryViewModel.swift`
**Drives:** `CalendarLibraryView`

Prepares month-scoped data for the calendar and timeline.

| State | Type | Purpose |
|-------|------|---------|
| `currentMonth` | `Date` | Month being browsed |
| `medicationEvents` | `[MedicationEvent]` | Private; refreshed via `.medicationEventsDidChange` notification so the timeline recomputes |

**Computed properties:**

- `monthLabel` — "June 2026" style label.
- `isCurrentMonth` — whether `currentMonth` is the current month.
- `hasAnyEntries` — whether any recordings or doses exist.
- `timelineDays` — days in the current month with recordings/doses, newest first. Element type is nested `TimelineDay`.
- `timelineDaysFilteredToSelectedDate(_:)` — timeline capped at selected date.
- `calendarMonth` — input for `CalendarMonthModel` grid generation.
- `availableMonths` — months between earliest entry and today.

**Key methods:**

- `prevMonth()` / `nextMonth()` — month paging.
- `recording(for:)` — resolve a recording by ID for navigation.
- `delete(_:)` — delete a recording via Store.
- `dayLabel(for:)` — "Today, 10 Jun" style label.

**Dependencies:** `RecordingStore`.

---

## Insights Flow

### `InsightsViewModel`

**File:** `app-four/ViewModels/InsightsViewModel.swift`
**Drives:** `InsightsView`

Owns month selection and base queries for the insights dashboard.

| State | Type | Purpose |
|-------|------|---------|
| `currentMonth` | `Date` | Selected month |
| `selectedDay` | `CalendarDay?` | Day tapped for detail sheet (currently reserved; tap-to-drill is not wired) |

**Computed properties:**

- `monthLabel` — "June 2026" style label.
- `isCurrentMonth` — whether `currentMonth` is the current month.
- `monthRecordings` — recordings in selected month.
- `availableMonths` — months with data.
- `hasAnyData` — whether selected month has recordings.

**Key methods:**

- `prevMonth()` / `nextMonth()` — month paging.
- `jumpToToday()` — reset to current month.
- `recording(for:)` — resolve a recording by ID for pushed detail.
- `calendarDay(for:)` — build a `CalendarDay` for a given date.

**Extension:** `InsightsViewModel+Signals` contains mood shares, weekday strips, averages, rhythm matrix, and connections.

---

## Detail & Review

### `RecordingDetailViewModel`

**File:** `app-four/ViewModels/RecordingDetailViewModel.swift`
**Drives:** `RecordingDetailView`

Manages detail screen state including audio playback, edit, delete, and regeneration.

| State | Purpose |
|-------|---------|
| `recording` | The displayed `Recording` (let-bound; mutations route through ViewModel methods or Store) |
| `summaryTask` | Observable active regeneration task |
| `retryTask` | Internal task handle for transcription retry (not observable) |

**Key methods:**

- `toggleFavorite()` — toggle favorite via Store.
- `updateTitle(_:)` / `updateDate(_:)` / `updateMood(_:)` — direct model edits + save.
- `delete()` — delete the recording via Store.
- `generateSummary()` — run NLP extraction on the transcript.
- `regenerateSummary()` — clear old summary and re-run extraction.
- `startRegenerate()` — structured task wrapper for regeneration.
- `retryTranscription()` — re-transcribe a `.failed` recording, then regenerate summary.

**Private helpers:** `performSummarization()`, `consumeTranscription(_:timeoutSeconds:)`, `finishFailed(_:)`.

**Dependencies:** `RecordingStore`, `SummarizationService`, `TranscriptionService`.

### `ExtractionReviewViewModel`

**File:** `app-four/ViewModels/ExtractionReviewViewModel.swift`
**Drives:** `ExtractionReviewView`

Presents and edits extracted signals. Changes are applied on save, and corrected fields write `RecordingTag(source: .userCorrected)` entries where applicable.

| State | Purpose |
|-------|---------|
| `name` | Editable title |
| `date` | Editable check-in date/time |
| `mood` | Editable mood |
| `energy` | Editable energy level |
| `focus` | Editable focus level |
| `sleepLevel` | Editable sleep level |
| `sleepHours` | Editable sleep duration |
| `medications` | Editable medication list |
| `emotions` | Editable emotion set |
| `sideEffects` | Editable side-effect set |
| `userDidSetTitle` | `private(set)` — whether the user manually edited the title |
| `editedFields` | `private` — tracks which fields were corrected for tag creation |

**Initializer inputs/dependencies:** `originalResult`, `recording`, `originalTitle`, `onComplete` closure, `RecordingStore`.

**Key methods:**

- `setMood(_:)`, `setEnergy(_:)`, `setFocus(_:)`, `setSleepLevel(_:)`, `setSleepHours(_:)` — scalar setters.
- `toggleEmotion(_:)`, `toggleSideEffect(_:)` — tag toggles.
- `toggleMedTaken(_:)`, `setMedDose(_:)`, `setMedDuration(_:hours:)`, `addMedication(_:)`, `removeMedication(id:)`, `removeMedication(_:)` — medication row edits.
- `confirm()` / `cancel()` — save or discard corrections.

**Note:** `toggleSideEffect(_:)` currently does not mark `.sideEffects` as edited because `TagCategory` has no `.sideEffects` case, so side-effect corrections are not tagged.

### `AudioPlaybackViewModel`

**File:** `app-four/ViewModels/AudioPlaybackViewModel.swift`
**Drives:** `AudioPlayerView`

Controls audio playback.

| State | Purpose |
|-------|---------|
| `state` | `PlaybackState`: `.idle`, `.loading`, `.playing(currentTime:)`, `.paused(currentTime:)`, `.finished`, `.error(String)` |
| `duration` | Total audio duration |
| `currentTime` | Current playback position |

**Key methods:**

- `play()` / `pause()` / `seek(to:)` / `cleanup()`

**Dependencies:** `Recording`, `AudioFileStorageService`.

---

## Medication

### `MedicationBarViewModel`

**File:** `app-four/ViewModels/MedicationBarViewModel.swift`
**Drives:** `MedicationBarView` (via `MedicationBarOverlay` / `ScreenContainer`)

Shared app-level ViewModel that tracks active medication windows and logs manual doses.

| State | Purpose |
|-------|---------|
| `activeDoses` | `[DoseDisplay]` — doses currently inside their effect window |

**Key methods:**

- `logManualDose(name:dose:takenAt:durationHours:)` — add a standalone dose.
- `refresh(now:)` — recompute active doses.
- `deleteEvent(id:)` — delete a dose.

**Dependencies:** `ModelContext` (defaults to `AppModelContainer.container.mainContext`).

**Lifecycle note:** This is a shared singleton held in `AppDependencies.medicationBarViewModel`, not tied to a single screen.

### `MedicationPickerViewModel`

**File:** `app-four/ViewModels/MedicationPickerViewModel.swift`
**Drives:** Medication picker sheets

Manages medication catalog and selection state.

| State | Purpose |
|-------|---------|
| `pickableNames` | `[String]` — merged list of catalog + history medication names |

**Key methods:**

- `refresh()` — reload names from catalog and history.
- `catalogEntry(for:)` — look up catalog metadata for a name.

**Dependencies:** `ModelContext` (defaults to global container).

---

## Settings

### `SettingsViewModel`

**File:** `app-four/ViewModels/SettingsViewModel.swift`
**Drives:** `SettingsView`

Manages model download, storage metrics, preferences, data clearing, and export.

| State | Purpose |
|-------|---------|
| `whisperModelInstalled` | Whether Whisper is on disk |
| `isDownloadingWhisper` | Download in progress |
| `whisperDownloadProgress` | Download progress fraction |
| `downloadError` | Last download failure |
| `downloadOverCellular` | Cellular preference |
| `promptPace` | Voice prompt cadence |
| `medicalPromptEnabled` | Whether medical-prompt hint is enabled |
| `canAllowCellular` | Computed: whether cellular download can be offered |
| `recordingCount` | Computed: `store.recordings.count` |
| `storageUsedMB` | Storage used in megabytes |

**Key methods:**

- `downloadModel(_:)` / `cancelDownload()` / `deleteModel(_:)` — model lifecycle.
- `syncDownloadOverCellular()` — persist cellular preference to SwiftData.
- `syncPromptPace()` — persist prompt pace to SwiftData.
- `updateStorage()` — recompute storage summary.
- `checkModels()` — refresh model installation status.
- `message(for:)` — human-readable message for a `ModelDownloadFailure`.
- `clearAllData()` — delete all recordings and check-ins.
- `exportJournal()` — prepare encrypted journal export.

**Dependencies:** `RecordingStore`, `AppServices` bundle (model, storage, export), `ExportService`, `ModelContext`.

---

## Model Types Used by Views

These types are not ViewModels but are frequently referenced in Views and ViewModels:

| Type | File | Purpose |
|------|------|---------|
| `CalendarMonthModel` | `ViewModels/CalendarMonthModel.swift` | Value-type calendar grid description |
| `DayMarker` | `ViewModels/CalendarMonthModel.swift` | Day-cell marker enum (none/mood/neutral) |
| `DayTimeline` | `ViewModels/DayTimeline.swift` | Namespace for timeline node types |
| `DayTimeline.Node` / `.Ring` | `ViewModels/DayTimeline.swift` | Timeline node and medication ring structs |
| `DayTimelineBuilder` | `ViewModels/DayTimeline.swift` | Pure `@MainActor` builder for a day's timeline nodes |

---

## Adding a ViewModel

1. Create a new file in `app-four/ViewModels/`.
2. Mark the class `@Observable @MainActor`.
3. Inject `RecordingStore` and required services via initializer.
4. Own only screen-level state; delegate persistence to the Store.
5. Add a unit test in `app-fourTests/ViewModels/`.
6. Update this catalog and the relevant screen doc.
