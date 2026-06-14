# Check-in View Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Record tab with a "Check in" tab: a How-We-Feel-style rotating crescent hub with three actions (Log meds / Speak check-in / Type note), voice flow with live nudges and stop-is-done, and a text composer where user-picked mood/energy/focus/meds/sleep are authoritative over NLP.

**Architecture:** The existing `RecordViewModel` state machine, transcription pipeline, and `ProcessingViewModel` → `applySummary` → `setMedicationEvents` save path are kept and extended — never forked. Two pipeline changes make text check-ins "selectors authoritative": `applySummary(_:fillOnly:)` (fills only nil scalars) and a manual-name dedupe inside `setMedicationEvents`. All UI is new SwiftUI under `Views/CheckIn/`, using only existing design tokens (Theme/Typography/Spacing/Radius/Palette/SignalLevel) — **no new palette, no hand-drawn assets**.

**Tech Stack:** SwiftUI, SwiftData, Swift Concurrency, `@Observable`, Swift Testing (`@Test`/`#expect`). Xcode project uses **synced folders** — new `.swift` files on disk are picked up with no pbxproj edits.

**Design reference (signed off):** `docs/superpowers/plans/2026-06-12-checkin-FINAL-hwf.html`
- Hub: rotating crescent (soft rounded ~295° arc, slow spin), three options stacked in its center — Log meds (purple icon), **Speak check-in** (accent, primary), Type note. Serif headline "How are you, right now?". Med bar stays on top.
- Voice: tap Speak → records immediately → crescent spins faster → **three nudges at a time** (trio 1: "How's your mood?" / "Energy level?" / "Able to focus?"; trio 2: "How did you sleep?" / "Any strong feelings?" / "Side effects?", advancing every 6 s) → **tap stop = done** (no review screen) → saved confirmation; tags appear as background NLP completes.
- Text: single composer — Mood / Energy / Focus 5-step scales → Meds chips → Sleep chips → **optional Note LAST** → Save. Everything optional, but Save disabled when the whole draft is empty. **Picked values always win over NLP**; the note (if any) runs through the existing extractor to fill only what the user left unset.

**Verified ground truth this plan relies on** (re-checked 2026-06-12):
- `RecordViewModel.stopRecording()` sets `.processing` synchronously, then `.done` inside its Task after the file is saved; transcription + NLP continue in background. This already matches "stop = done".
- `pauseRecording()`/`resumeRecording()` have **zero call sites** → deleted (dead code). `RecordingState.paused` enum case stays (the view treats it as recording).
- `Recording.applySummary` currently **unconditionally overwrites** mood/energyLevel/focusLevel/sleepHours/sleepQuality/title/medicationInfo/sleepLevelValue. Its 3 callers: `ProcessingViewModel.swift:98`, `RecordingDetailViewModel.swift:104`, `ExtractionReviewViewModel.swift:195` — the new `fillOnly` parameter defaults to `false` so none of them change behavior.
- `setMedicationEvents` deletes only `.transcript` events; sets `hasMedication = !meds.isEmpty` (manual-only recordings would read false — fixed in Task 2).
- `MedicationEvent.recording` is documented "nil for manual logs" (MedicationEvent.swift:6, :25) — linking manual events from a check-in is **new behavior**; both doc comments must be updated.
- `MedicationBarViewModel.logManualDose(name:dose:takenAt:)` inserts a standalone manual event (recording == nil) and posts `.medicationEventsDidChange`. The hub's "Log meds" uses this (a standalone dose, not tied to an entry). Composer meds, by contrast, are linked to the created Recording.
- Test target does **not** have `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` — every new suite needs explicit `@MainActor`.
- All 6 service mocks exist under `app-twoTests/Mocks/`; `AppServices` has a memberwise init — a mock AppServices is trivial. `RecordViewModelTests.swift` is a fully commented-out stale suite; this plan **replaces** it with a live `CheckInViewModelTests`.
- `Recording`'s init parameter order (labeled args must follow declaration order): `audioFileName, duration, status, fullTranscriptText, title, … energyLevel, focusLevel, mood, sleepHours, sleepQuality, …`.
- MockSummarizationService stub returns `mood: "positive"`, `energyLevel: "high"`, `focusLevel: "high"` — perfect clobber-bait for fill-only tests.
- Build/test commands (SPM cache workaround + erased simulator):
  - Build: `env -u GIT_CONFIG_GLOBAL -u GIT_CONFIG_SYSTEM -u GIT_CONFIG_COUNT xcodebuild build -scheme app-two -destination 'platform=iOS Simulator,id=667B75F8-4C75-4A14-ACE1-D5C46F3CBC0D' 2>&1 | tail -3`
  - Test (filtered): same prefix with `test … -only-testing 'app-twoTests/<SuiteName>'`

## File Structure

**Create:**
- `app-two/Models/CheckInDraft.swift` — value type for the text composer's draft
- `app-two/Views/CheckIn/CrescentRing.swift` — the HWF rotating crescent
- `app-two/Views/CheckIn/TextCheckInComposer.swift` — composer sheet (scales, chips, note, Save)
- `app-two/Views/CheckIn/CheckInView.swift` — the tab view (hub / recording / saved phases; nudges + saved subviews live here)
- `app-two/ViewModels/CheckInViewModel.swift` — renamed + extended RecordViewModel
- `app-twoTests/Mocks/MockAppServices.swift` — bundles the 6 existing mocks
- `app-twoTests/ViewModels/CheckInViewModelTests.swift` — replaces the disabled RecordViewModelTests
- `app-twoTests/Models/RecordingApplySummaryTests.swift` — fillOnly + med-dedupe tests
- `app-twoTests/Store/CheckInNoteStoreTests.swift` — createCheckInNote tests

**Modify:**
- `app-two/Views/RootTabView.swift` — Tab.checkIn, label, instantiation
- `app-two/App/WhisperNotesApp.swift` — deep link `.checkIn`
- `app-two/DesignSystem/Icons.swift` — `checkIn` icon
- `app-two/Models/Recording.swift` — `applySummary(fillOnly:)`, `setMedicationEvents` dedupe
- `app-two/Models/MedicationEvent.swift` — two doc comments
- `app-two/ViewModels/ProcessingViewModel.swift` — thread `fillOnly`
- `app-two/Store/RecordingStore.swift` — `createCheckInNote`, delete `createTextRecording`
- `app-two/DesignSystem/Typography.swift` — display token doc comment
- `app-two/DesignSystem/ScreenContainer.swift` — doc comments (RecordView → CheckInView)
- `app-two/wireframes/SharedWireframes.swift` — tab label string

**Delete:**
- `app-two/Views/RecordView.swift`
- `app-two/ViewModels/RecordViewModel.swift` (content moves to CheckInViewModel.swift)
- `app-two/Views/Components/AudioWaveform.swift`
- `app-two/Views/Components/RecordingStatusPill.swift`
- `app-two/wireframes/RecordWireframes.swift`
- `app-twoTests/ViewModels/RecordViewModelTests.swift` (replaced by CheckInViewModelTests)

---

### Task 1: Rename the tab — Record → Check in

**Files:**
- Modify: `app-two/Views/RootTabView.swift`
- Modify: `app-two/App/WhisperNotesApp.swift:37`
- Modify: `app-two/DesignSystem/Icons.swift:8`

- [ ] **Step 1: Rename the enum case, label, and icon**

In `app-two/Views/RootTabView.swift`, change the enum (also fixing the stale "five-tab" comment):

```swift
/// The app's four-tab root navigation.
/// Keyed by `Tab` enum — no magic integers anywhere.
enum Tab: Hashable {
    case calendar
    case checkIn
    case insights
    case settings
}
```

and the tab item (RecordView reference stays for now — it is replaced in Task 8):

```swift
RecordView(store: store, services: services, shouldAutoStart: $shouldAutoStartRecording)
    .tabItem { Label("Check in", systemImage: Icons.checkIn) }
    .tag(Tab.checkIn)
```

In `app-two/DesignSystem/Icons.swift` replace line 8:

```swift
    static let checkIn = "checkmark.circle"
```

In `app-two/App/WhisperNotesApp.swift` line 37, change `selectedTab = .record` to:

```swift
        selectedTab = .checkIn
```

- [ ] **Step 2: Fix remaining `Tab.record`/`.record` tab references**

Run: `grep -rn "Tab\.record\|\.record\b" app-two/ --include="*.swift" | grep -v "\.recording\|recorder\|diagnosticsStore\.record\|Issue\.record"`
Expected: no remaining tab-context hits. (`InsightsView.swift` and `CalendarLibraryView.swift` reference only `.insights`/`.calendar` — but verify nothing switches over `Tab` exhaustively elsewhere; if a `switch` breaks the build the compiler will name it.)

- [ ] **Step 3: Build**

Run: `env -u GIT_CONFIG_GLOBAL -u GIT_CONFIG_SYSTEM -u GIT_CONFIG_COUNT xcodebuild build -scheme app-two -destination 'platform=iOS Simulator,id=667B75F8-4C75-4A14-ACE1-D5C46F3CBC0D' 2>&1 | tail -3`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "rename(tab): Record -> Check in (Tab.checkIn, checkmark.circle icon)"
```

---

### Task 2: Pipeline — `applySummary(fillOnly:)` + medication dedupe (TDD)

User-picked values must survive NLP reprocessing, and a med the user logged manually must not be duplicated by the extractor finding the same name in the note.

**Files:**
- Test: `app-twoTests/Models/RecordingApplySummaryTests.swift` (create)
- Modify: `app-two/Models/Recording.swift:189-296`
- Modify: `app-two/Models/MedicationEvent.swift:6,25` (doc comments)

- [ ] **Step 1: Write the failing tests**

Create `app-twoTests/Models/RecordingApplySummaryTests.swift`:

```swift
import Foundation
import Testing
import SwiftData
@testable import app_two

@MainActor
struct RecordingApplySummaryTests {
    let container: ModelContainer
    let context: ModelContext

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: Recording.self, configurations: config)
        context = container.mainContext
    }

    private func makeResult(
        mood: String? = "great", energy: String? = "charged", focus: String? = "sharp",
        sleepHours: Double? = 8, sleepQuality: String? = "good", meds: [MedEvent] = []
    ) -> SummaryResult {
        SummaryResult(
            bullets: ["a bullet"], medications: meds, generatedTitle: "Generated",
            energyLevel: energy, focusLevel: focus, mood: mood,
            sleepHours: sleepHours, sleepQuality: sleepQuality,
            sleepEvent: nil, sleepLevel: nil, sideEffects: [], feelings: [], noteExtraction: nil
        )
    }

    // MARK: applySummary fillOnly

    @Test func fillOnlyPreservesUserScalars() {
        let r = Recording(audioFileName: "t.m4a", mood: "good")
        context.insert(r)
        r.applySummary(makeResult(), fillOnly: true)
        #expect(r.mood == "good")                 // user value wins
        #expect(r.energyLevel == "charged")       // nil column filled
        #expect(r.focusLevel == "sharp")
        #expect(r.sleepQuality == "good")
    }

    @Test func fillOnlyKeepsTitle() {
        let r = Recording(audioFileName: "t.m4a", title: "Good · Steady", mood: "good")
        context.insert(r)
        r.applySummary(makeResult(), fillOnly: true)
        #expect(r.title == "Good · Steady")
    }

    @Test func defaultApplySummaryStillOverwrites() {
        let r = Recording(audioFileName: "t.m4a", mood: "good")
        context.insert(r)
        r.applySummary(makeResult(mood: "low"))
        #expect(r.mood == "low")
    }

    @Test func fillOnlyStillWritesSummaryMetadata() {
        let r = Recording(audioFileName: "t.m4a", mood: "good")
        context.insert(r)
        r.applySummary(makeResult(), fillOnly: true)
        #expect(r.summaryStatus == SummaryStatus.completed.rawValue)
        #expect(r.summary?.contains("a bullet") == true)
    }

    // MARK: setMedicationEvents dedupe

    @Test func transcriptMedSkippedWhenManualExists() {
        let r = Recording(audioFileName: "t.m4a")
        context.insert(r)
        let manual = MedicationEvent(name: "Concerta", takenAt: r.createdAt, taken: true, source: .manual)
        context.insert(manual); manual.recording = r

        r.setMedicationEvents(
            from: [MedEvent(name: "concerta"), MedEvent(name: "Magnesium")],
            durationHours: nil, context: context
        )
        let names = r.medicationEvents.map(\.name).sorted()
        #expect(names == ["Concerta", "Magnesium"])
        #expect(r.medicationEvents.filter { $0.name == "Concerta" }.count == 1)
    }

    @Test func hasMedicationTrueWithManualOnly() {
        let r = Recording(audioFileName: "t.m4a")
        context.insert(r)
        let manual = MedicationEvent(name: "Concerta", takenAt: r.createdAt, taken: true, source: .manual)
        context.insert(manual); manual.recording = r

        r.setMedicationEvents(from: [], durationHours: nil, context: context)
        #expect(r.hasMedication == true)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `env -u GIT_CONFIG_GLOBAL -u GIT_CONFIG_SYSTEM -u GIT_CONFIG_COUNT xcodebuild test -scheme app-two -destination 'platform=iOS Simulator,id=667B75F8-4C75-4A14-ACE1-D5C46F3CBC0D' -only-testing 'app-twoTests/RecordingApplySummaryTests' 2>&1 | grep -E "error:|passed|failed|TEST"`
Expected: compile error — `extra argument 'fillOnly' in call` (the parameter doesn't exist yet).

- [ ] **Step 3: Implement `fillOnly` in applySummary**

In `app-two/Models/Recording.swift`, change the signature at line 189 and restructure the scalar section. The title build + scalar writes become a guarded branch; everything from the bullets-JSON block down is unchanged and shared:

```swift
@MainActor func applySummary(_ result: SummaryResult, fillOnly: Bool = false) {
    if fillOnly {
        // A check-in composer set these explicitly; extraction only fills gaps.
        if energyLevel == nil { energyLevel = result.energyLevel }
        if focusLevel == nil { focusLevel = result.focusLevel }
        if mood == nil { mood = result.mood }
        if sleepHours == nil { sleepHours = result.sleepHours }
        if sleepQuality == nil { sleepQuality = result.sleepQuality }
        if sleepLevelValue == nil { sleepLevelValue = result.sleepLevel }
        if medicationInfo == nil {
            let medStr = Self.medicationSummary(result.medications)
            medicationInfo = medStr.isEmpty ? nil : medStr
        }
    } else {
        var nameParts: [String] = []
        if let mood = result.mood { nameParts.append(mood.capitalized) }
        if let energy = result.energyLevel { nameParts.append(energy.capitalized) }
        if let focusRaw = result.focusLevel {
            nameParts.append(FocusLevel(rawValue: focusRaw)?.displayLabel ?? focusRaw.capitalized)
        }
        title = nameParts.isEmpty ? result.generatedTitle : nameParts.joined(separator: " · ")
        energyLevel = result.energyLevel
        focusLevel = result.focusLevel
        mood = result.mood
        sleepHours = result.sleepHours
        sleepQuality = result.sleepQuality
        sleepLevelValue = result.sleepLevel
        let medStr = Self.medicationSummary(result.medications)
        medicationInfo = medStr.isEmpty ? nil : medStr
    }

    // …existing bullets/noteExtraction/sideEffects/sleepEvent/feelings JSON blocks,
    // summary, summaryStatus, summaryGeneratedAt, updatedAt — UNCHANGED, but with the
    // old standalone `sleepLevelValue = result.sleepLevel` line (old line 252) REMOVED
    // (it moved into both branches above).
}

private static func medicationSummary(_ meds: [MedEvent]) -> String {
    meds.map { med in
        var parts = [med.name]
        if let change = med.change, change != .regular { parts.append(change.rawValue) }
        if let dose = med.dose { parts.append(dose) }
        if let label = med.timeLabel { parts.append("at \(label)") }
        if !med.taken { parts.append("missed") }
        return parts.joined(separator: " ")
    }.joined(separator: "; ")
}
```

(The old inline `medStr` closure at lines 203-211 is replaced by the shared `medicationSummary` helper; the unconditional `sleepLevelValue = result.sleepLevel` at old line 252 is deleted.)

- [ ] **Step 4: Implement the dedupe + hasMedication fix in setMedicationEvents**

Replace the body at `Recording.swift:263-296` (signature unchanged):

```swift
@MainActor func setMedicationEvents(
    from meds: [MedEvent],
    durationHours: Double?,
    context: ModelContext
) {
    // A manually logged dose on this check-in beats the extractor finding the
    // same name in the note — skip those to avoid duplicates.
    let manualNames = Set(
        medicationEvents.filter { $0.source == .manual }.map { $0.name.lowercased() }
    )

    medicationEvents
        .filter { $0.source == .transcript }
        .forEach { context.delete($0) }

    for med in meds where !manualNames.contains(med.name.lowercased()) {
        let takenAt = MedicationEvent.resolvedTakenAt(
            time: med.time,
            timeLabel: med.timeLabel,
            recordingDate: createdAt
        )
        let event = MedicationEvent(
            name: med.name,
            dose: med.dose,
            takenAt: takenAt,
            taken: med.taken,
            quantity: med.quantity,
            durationHours: durationHours ?? 10.0,
            change: med.change,
            timeLabel: med.timeLabel,
            source: .transcript
        )
        context.insert(event)
        event.recording = self
    }

    hasMedication = !meds.isEmpty || !manualNames.isEmpty
}
```

- [ ] **Step 5: Update the two stale doc comments in MedicationEvent.swift**

Line 6: change ``/// `source == .manual`     → created by tapping the bar; `recording` is nil.`` to:

```swift
/// `source == .manual`     → logged by the user (med bar or a check-in); `recording` is
///                           nil for standalone doses, set when logged inside a check-in.
```

Line 25: change `/// Nil for manual logs; set to the originating recording for transcript-extracted events.` to:

```swift
/// Nil for standalone manual logs; set for transcript-extracted events and
/// for manual doses logged as part of a check-in entry.
```

- [ ] **Step 6: Run tests to verify they pass**

Run: same command as Step 2.
Expected: 6/6 pass. Also run `-only-testing 'app-twoTests/ProcessingViewModelTests'` — Expected: still green (default path unchanged).

- [ ] **Step 7: Commit**

```bash
git add -A && git commit -m "feat(pipeline): applySummary fillOnly + manual-med dedupe in setMedicationEvents"
```

---

### Task 3: `CheckInDraft` + `RecordingStore.createCheckInNote` (TDD)

**Files:**
- Create: `app-two/Models/CheckInDraft.swift`
- Test: `app-twoTests/Store/CheckInNoteStoreTests.swift` (create)
- Modify: `app-two/Store/RecordingStore.swift`

- [ ] **Step 1: Create the draft model**

Create `app-two/Models/CheckInDraft.swift`:

```swift
import Foundation

/// What the user explicitly picked in the text check-in composer.
/// These values are authoritative — extraction may only fill what is nil here.
struct CheckInDraft: Equatable {
    var mood: MoodLevel? = nil
    var energy: EnergyLevel? = nil
    var focus: FocusLevel? = nil
    var sleepQuality: String? = nil
    var meds: [DraftMedication] = []
    var note: String = ""

    struct DraftMedication: Identifiable, Equatable {
        let id = UUID()
        var name: String
        var dose: String?
        var takenAt: Date = .now
    }

    var trimmedNote: String { note.trimmingCharacters(in: .whitespacesAndNewlines) }

    var isEmpty: Bool {
        mood == nil && energy == nil && focus == nil
            && sleepQuality == nil && meds.isEmpty && trimmedNote.isEmpty
    }
}
```

- [ ] **Step 2: Write the failing tests**

Create `app-twoTests/Store/CheckInNoteStoreTests.swift`:

```swift
import Foundation
import Testing
import SwiftData
@testable import app_two

@MainActor
struct CheckInNoteStoreTests {
    var store: RecordingStore
    var container: ModelContainer

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: Recording.self, configurations: config)
        store = RecordingStore(context: container.mainContext)
    }

    @Test func savesSelectedSignalsAsScalars() {
        var draft = CheckInDraft()
        draft.mood = .good; draft.energy = .steady; draft.focus = .sharp
        draft.sleepQuality = "okay"

        let r = store.createCheckInNote(draft)
        #expect(r.mood == "good")
        #expect(r.energyLevel == "steady")
        #expect(r.focusLevel == "sharp")
        #expect(r.sleepQuality == "okay")
        #expect(r.title == "Good · Steady · Sharp")
        #expect(r.status == .completed)
        #expect(store.recordings.contains { $0.id == r.id })
    }

    @Test func linksManualMedEvents() {
        var draft = CheckInDraft()
        draft.meds = [CheckInDraft.DraftMedication(name: "Concerta", dose: "50mg")]

        let r = store.createCheckInNote(draft)
        #expect(r.medicationEvents.count == 1)
        #expect(r.medicationEvents.first?.source == .manual)
        #expect(r.medicationEvents.first?.recording?.id == r.id)
        #expect(r.hasMedication == true)
    }

    @Test func titleFallsBackToNoteThenDefault() {
        var draft = CheckInDraft()
        draft.note = "rough start but better after lunch today honestly"
        #expect(store.createCheckInNote(draft).title == "rough start but better after")

        let r2 = store.createCheckInNote(CheckInDraft(sleepQuality: "good"))
        #expect(r2.title == "Check-in")
    }

    @Test func noteBecomesTranscript() {
        var draft = CheckInDraft()
        draft.note = "settled in after meds"
        let r = store.createCheckInNote(draft)
        #expect(r.fullTranscriptText == "settled in after meds")
    }
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `…xcodebuild test … -only-testing 'app-twoTests/CheckInNoteStoreTests' 2>&1 | grep -E "error:|passed|failed|TEST"`
Expected: compile error — `value of type 'RecordingStore' has no member 'createCheckInNote'`.

- [ ] **Step 4: Implement createCheckInNote**

In `app-two/Store/RecordingStore.swift`, add below `addCorrectionTags` (keep `createTextRecording` for now — it is deleted with its caller in Task 5):

```swift
/// Creates a Recording from the text check-in composer. User-picked values are
/// written directly as the authoritative scalars; the optional note becomes the
/// transcript for gap-filling extraction (`applySummary(fillOnly: true)`).
@discardableResult
func createCheckInNote(_ draft: CheckInDraft) -> Recording {
    let signalParts = [
        draft.mood?.displayLabel, draft.energy?.displayLabel, draft.focus?.displayLabel,
    ].compactMap { $0 }
    let noteWords = draft.trimmedNote.split(separator: " ").prefix(5)
    let title = !signalParts.isEmpty ? signalParts.joined(separator: " · ")
        : !noteWords.isEmpty ? noteWords.joined(separator: " ")
        : "Check-in"

    let recording = Recording(
        audioFileName: "text-\(UUID().uuidString)",
        duration: 0,
        status: .completed,
        fullTranscriptText: draft.trimmedNote,
        title: title,
        hasMedication: !draft.meds.isEmpty,
        energyLevel: draft.energy?.rawValue,
        focusLevel: draft.focus?.rawValue,
        mood: draft.mood?.rawValue,
        sleepQuality: draft.sleepQuality
    )
    modelContext.insert(recording)

    for med in draft.meds {
        let event = MedicationEvent(
            name: med.name,
            dose: med.dose,
            takenAt: med.takenAt,
            taken: true,
            durationHours: 10.0,
            source: .manual
        )
        modelContext.insert(event)
        event.recording = recording
    }

    save()
    loadRecordings()
    return recording
}
```

(Note `save()` not `try? modelContext.save()` — `save()` also posts `.medicationEventsDidChange`, which refreshes the med bar after composer-logged doses.)

- [ ] **Step 5: Run tests to verify they pass**

Run: same as Step 3. Expected: 4/4 pass. The title test expects 5 words ("rough start but better after") — matching the `prefix(5)` above.

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "feat(store): CheckInDraft + createCheckInNote with linked manual med events"
```

---

### Task 4: Thread `fillOnly` through ProcessingViewModel (TDD)

**Files:**
- Test: append to `app-twoTests/ViewModels/ProcessingViewModelTests.swift`
- Modify: `app-two/ViewModels/ProcessingViewModel.swift:36-49, 69-107`

- [ ] **Step 1: Write the failing test**

Append inside `ProcessingViewModelTests`:

```swift
    @Test func fillOnlyPreservesUserValuesThroughPipeline() async throws {
        let recording = Recording(audioFileName: "checkin.txt", title: "Good", mood: "good")
        store.addRecording(recording)

        let task = viewModel.processRawTranscription(
            "Felt amazing and full of energy.",
            duration: 0,
            language: nil,
            audioFileName: "checkin.txt",
            fillOnly: true
        )
        await task.value

        // Stub result carries mood "positive" / energy "high" — mood must NOT be clobbered.
        #expect(recording.mood == "good")
        #expect(recording.energyLevel == "high")
        #expect(recording.title == "Good")
    }
```

- [ ] **Step 2: Run to verify it fails**

Run: `… -only-testing 'app-twoTests/ProcessingViewModelTests' …`
Expected: compile error — `extra argument 'fillOnly' in call`.

- [ ] **Step 3: Implement**

In `app-two/ViewModels/ProcessingViewModel.swift`:

```swift
@discardableResult
func processRawTranscription(
    _ rawText: String,
    duration: TimeInterval,
    language: String?,
    audioFileName: String,
    fillOnly: Bool = false
) -> Task<Void, Never> {
    activeTask?.cancel()
    let task = Task {
        await run(rawText: rawText, audioFileName: audioFileName, fillOnly: fillOnly)
    }
    activeTask = task
    return task
}
```

and in `run` — signature becomes `private func run(rawText: String, audioFileName: String, fillOnly: Bool) async`, and the apply line becomes:

```swift
recording.applySummary(result, fillOnly: fillOnly)
```

(`retry(...)` calls `processRawTranscription` without the new argument — the default keeps it compiling and behaviorally identical.)

- [ ] **Step 4: Run tests to verify pass**

Run: same as Step 2. Expected: all ProcessingViewModelTests pass, including the new one.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat(processing): fillOnly flag threads user-authoritative saves through the pipeline"
```

---

### Task 5: CheckInViewModel — rename + nudges + text save (TDD)

Rename `RecordViewModel` → `CheckInViewModel` (git mv so history follows), delete dead pause/resume, add the nudge-trio logic, `saveTextCheckIn`, `lastSavedRecording`, and `recentMedicationNames`. The old `RecordView` keeps compiling via 3 small reference edits (it is deleted in Task 8). The disabled `RecordViewModelTests.swift` is **replaced** by a live suite using a new MockAppServices.

**Files:**
- Rename: `app-two/ViewModels/RecordViewModel.swift` → `app-two/ViewModels/CheckInViewModel.swift`
- Modify: `app-two/Views/RecordView.swift` (3 references), `app-two/ViewModels/ProcessingViewModel.swift:5,35` + `app-two/Services/WhisperKit/WhisperKitTranscriptionService.swift:150` (doc comments)
- Modify: `app-two/Store/RecordingStore.swift` (delete `createTextRecording`)
- Create: `app-twoTests/Mocks/MockAppServices.swift`
- Delete: `app-twoTests/ViewModels/RecordViewModelTests.swift`
- Create: `app-twoTests/ViewModels/CheckInViewModelTests.swift`

- [ ] **Step 1: Create the mock services bundle**

Create `app-twoTests/Mocks/MockAppServices.swift`:

```swift
import Foundation
@testable import app_two

/// Bundles the six existing service mocks into an AppServices for view-model tests.
@MainActor
struct MockAppServices {
    let audio = MockAudioRecordingService()
    let storage = MockAudioFileStorageService()
    let transcription = MockTestTranscriptionService()
    let liveTranscription = MockLiveTranscriptionService()
    let aiModel = MockAIModelService()
    let summarization = MockSummarizationService()

    var services: AppServices {
        AppServices(
            audioService: audio,
            storageService: storage,
            transcriptionService: transcription,
            liveTranscriptionService: liveTranscription,
            aiModelService: aiModel,
            summarizationService: summarization
        )
    }
}
```

- [ ] **Step 2: Write the failing tests**

Delete `app-twoTests/ViewModels/RecordViewModelTests.swift`. Create `app-twoTests/ViewModels/CheckInViewModelTests.swift`:

```swift
import Foundation
import Testing
import SwiftData
@testable import app_two

@MainActor
struct CheckInViewModelTests {
    var viewModel: CheckInViewModel
    var mocks: MockAppServices
    var store: RecordingStore
    var container: ModelContainer

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: Recording.self, configurations: config)
        store = RecordingStore(context: container.mainContext)
        mocks = MockAppServices()
        viewModel = CheckInViewModel(store: store, services: mocks.services)
    }

    // MARK: Nudges

    @Test func nudgeTriosAlternateEverySixSeconds() {
        #expect(CheckInViewModel.nudgeTrio(forElapsed: 0) == CheckInViewModel.nudgeTrios[0])
        #expect(CheckInViewModel.nudgeTrio(forElapsed: 5.9) == CheckInViewModel.nudgeTrios[0])
        #expect(CheckInViewModel.nudgeTrio(forElapsed: 6.0) == CheckInViewModel.nudgeTrios[1])
        #expect(CheckInViewModel.nudgeTrio(forElapsed: 11.9) == CheckInViewModel.nudgeTrios[1])
        #expect(CheckInViewModel.nudgeTrio(forElapsed: 12.0) == CheckInViewModel.nudgeTrios[0])
    }

    @Test func nudgeTrioContents() {
        #expect(CheckInViewModel.nudgeTrios[0] == ["How's your mood?", "Energy level?", "Able to focus?"])
        #expect(CheckInViewModel.nudgeTrios[1] == ["How did you sleep?", "Any strong feelings?", "Side effects?"])
    }

    // MARK: Text check-in

    @Test func saveTextCheckInWithSelectorsOnlySkipsProcessing() {
        var draft = CheckInDraft()
        draft.mood = .good; draft.sleepQuality = "good"

        viewModel.saveTextCheckIn(draft)

        #expect(viewModel.state == .done)
        let saved = viewModel.lastSavedRecording
        #expect(saved?.mood == "good")
        #expect(saved?.summaryStatus == nil)  // no note -> no NLP pass
    }

    @Test func saveTextCheckInWithNoteRunsFillOnlyProcessing() async throws {
        var draft = CheckInDraft()
        draft.mood = .good
        draft.note = "Took meds late, energy spiked after."

        viewModel.saveTextCheckIn(draft)
        if let task = viewModel.processingViewModel.activeTask { await task.value }

        let saved = try #require(viewModel.lastSavedRecording)
        #expect(saved.mood == "good")            // user value survived the stub's "positive"
        #expect(saved.energyLevel == "high")     // nil column filled from stub
        #expect(saved.summaryStatus == SummaryStatus.completed.rawValue)
    }

    @Test func saveEmptyDraftDoesNothing() {
        viewModel.saveTextCheckIn(CheckInDraft())
        #expect(viewModel.state == .idle)
        #expect(viewModel.lastSavedRecording == nil)
        #expect(store.recordings.isEmpty)
    }

    // MARK: Recent meds

    @Test func recentMedicationNamesAreDistinctNewestFirst() throws {
        let ctx = container.mainContext
        let now = Date()
        let seed: [(offset: TimeInterval, name: String)] = [
            (0, "Concerta"), (60, "Magnesium"), (120, "concerta"), (180, "Omega 3"),
        ]
        for entry in seed {
            let e = MedicationEvent(name: entry.name, takenAt: now.addingTimeInterval(-entry.offset),
                                    taken: true, source: .manual)
            ctx.insert(e)
        }
        try ctx.save()
        #expect(viewModel.recentMedicationNames == ["Concerta", "Magnesium", "Omega 3"])
    }
}
```

- [ ] **Step 3: Run to verify failure**

Run: `… -only-testing 'app-twoTests/CheckInViewModelTests' …`
Expected: compile error — `cannot find 'CheckInViewModel' in scope`.

- [ ] **Step 4: Rename the view model and extend it**

```bash
git mv app-two/ViewModels/RecordViewModel.swift app-two/ViewModels/CheckInViewModel.swift
```

In the renamed file:
1. `final class RecordViewModel` → `final class CheckInViewModel`.
2. **Delete** `pauseRecording()` (old lines 192-199) and `resumeRecording()` (old lines 201-213) — zero call sites.
3. **Delete** `analyzeTextNote(_:)` (old lines 236-245).
4. Add after `reset()`:

```swift
// MARK: - Nudges (voice)

static let nudgeTrios: [[String]] = [
    ["How's your mood?", "Energy level?", "Able to focus?"],
    ["How did you sleep?", "Any strong feelings?", "Side effects?"],
]

static func nudgeTrio(forElapsed elapsed: TimeInterval) -> [String] {
    nudgeTrios[Int(elapsed / 6) % nudgeTrios.count]
}

var currentNudges: [String] { Self.nudgeTrio(forElapsed: elapsedTime) }

// MARK: - Text check-in

private(set) var lastSavedRecording: Recording?

func saveTextCheckIn(_ draft: CheckInDraft) {
    guard !draft.isEmpty else { return }
    let recording = store.createCheckInNote(draft)
    if !draft.trimmedNote.isEmpty {
        processingViewModel.processRawTranscription(
            draft.trimmedNote,
            duration: 0,
            language: nil,
            audioFileName: recording.audioFileName,
            fillOnly: true
        )
    }
    lastSavedRecording = recording
    state = .done
}

// MARK: - Composer support

var recentMedicationNames: [String] {
    var descriptor = FetchDescriptor<MedicationEvent>(
        sortBy: [SortDescriptor(\.takenAt, order: .reverse)]
    )
    descriptor.fetchLimit = 50
    let events = (try? store.context.fetch(descriptor)) ?? []
    var seen = Set<String>()
    var names: [String] = []
    for event in events where seen.insert(event.name.lowercased()).inserted {
        names.append(event.name)
    }
    return Array(names.prefix(4))
}
```

5. Add `import SwiftData` at the top (for `FetchDescriptor`).
6. In `stopRecording()`'s Task, after `self.store.addRecording(recording)` add `self.lastSavedRecording = recording`; in `reset()` and `cancelRecording()`'s Task add `lastSavedRecording = nil`.

- [ ] **Step 5: Patch remaining references so the build stays green**

- `app-two/Views/RecordView.swift:4` → `@State private var viewModel: CheckInViewModel`; `:16` → `CheckInViewModel(store: store, services: services)`; replace the `analyzeTextNote` call (line ~168) with `viewModel.saveTextCheckIn(CheckInDraft(note: noteText))` — wait, `CheckInDraft`'s memberwise init requires the labeled form: use:

```swift
var draft = CheckInDraft()
draft.note = noteText
viewModel.saveTextCheckIn(draft)
```

- `app-two/Views/RecordView.swift` lines 77-88: delete the `.paused` case from the status-pill switch? **No** — `RecordingState.paused` still exists; the switch must stay exhaustive. Leave RecordView's switch untouched.
- `app-two/Store/RecordingStore.swift`: delete `createTextRecording` (lines 65-80) — its only caller was `analyzeTextNote`.
- Doc comments: `ProcessingViewModel.swift:5,35` and `WhisperKitTranscriptionService.swift:150` — replace "RecordViewModel" with "CheckInViewModel".

- [ ] **Step 6: Run tests**

Run: `… -only-testing 'app-twoTests/CheckInViewModelTests' …` then the full suite.
Expected: 7/7 new tests pass; full suite green.

- [ ] **Step 7: Commit**

```bash
git add -A && git commit -m "feat(checkin): CheckInViewModel — rename, nudge trios, saveTextCheckIn, recent meds; drop dead pause/resume"
```

---

### Task 6: CrescentRing component

**Files:**
- Create: `app-two/Views/CheckIn/CrescentRing.swift`

- [ ] **Step 1: Implement**

```swift
import SwiftUI

/// The How-We-Feel-style check-in ring: a soft, rounded ~295° arc that rotates
/// slowly at rest and faster while recording. Purely decorative.
struct CrescentRing: View {
    var isActive: Bool = false
    var lineWidth: CGFloat = 22

    @State private var spinning = false

    private var revolutionSeconds: Double { isActive ? 7 : 16 }

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.82)
            .stroke(.quaternary, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .padding(lineWidth / 2)
            .rotationEffect(.degrees(spinning ? 360 : 0))
            .animation(
                AccessibilityHelpers.isReduceMotionEnabled
                    ? nil
                    : .linear(duration: revolutionSeconds).repeatForever(autoreverses: false),
                value: spinning
            )
            .onAppear { spinning = true }
            .onChange(of: isActive) {
                // Restart so the new speed takes effect; the phase snap is masked
                // by the hub <-> recording crossfade.
                spinning = false
                Task { @MainActor in spinning = true }
            }
            .accessibilityHidden(true)
    }
}

#Preview {
    VStack(spacing: Spacing.hero) {
        CrescentRing().frame(width: 300, height: 300)
        CrescentRing(isActive: true).frame(width: 200, height: 200)
    }
}
```

- [ ] **Step 2: Build**

Run: build command. Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "feat(checkin): CrescentRing — rotating HWF-style arc"
```

---

### Task 7: TextCheckInComposer

The composer sheet: Mood/Energy/Focus 5-step scales (SignalLevel gradients), meds chips (recent names + "+ add" via MedicationLogSheet), sleep chips, **note last**, Save.

**Files:**
- Create: `app-two/Views/CheckIn/TextCheckInComposer.swift`

- [ ] **Step 1: Implement**

```swift
import SwiftUI

struct TextCheckInComposer: View {
    let recentMedicationNames: [String]
    let onSave: (CheckInDraft) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft = CheckInDraft()
    @State private var showMedSheet = false

    private let sleepOptions = ["poor", "okay", "good"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    SignalScaleRow(title: "Mood", selection: $draft.mood)
                    SignalScaleRow(title: "Energy", selection: $draft.energy)
                    SignalScaleRow(title: "Focus", selection: $draft.focus)
                    medsRow
                    sleepRow
                    noteRow
                }
                .padding(Spacing.l)
            }
            .navigationTitle("New note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(draft.isEmpty)
                }
            }
            .sheet(isPresented: $showMedSheet) {
                MedicationLogSheet { name, dose, takenAt in
                    draft.meds.append(
                        CheckInDraft.DraftMedication(name: name, dose: dose, takenAt: takenAt)
                    )
                }
            }
        }
    }

    private var medsRow: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            fieldLabel("Meds")
            FlowChips {
                ForEach(recentMedicationNames, id: \.self) { name in
                    let isOn = draft.meds.contains { $0.name.caseInsensitiveCompare(name) == .orderedSame }
                    chip(name + (isOn ? " ✓" : ""), on: isOn, tint: Palette.medication) {
                        if isOn {
                            draft.meds.removeAll { $0.name.caseInsensitiveCompare(name) == .orderedSame }
                        } else {
                            draft.meds.append(CheckInDraft.DraftMedication(name: name, dose: nil))
                        }
                    }
                }
                ForEach(draft.meds.filter { med in
                    !recentMedicationNames.contains { $0.caseInsensitiveCompare(med.name) == .orderedSame }
                }) { med in
                    chip(med.name + " ✓", on: true, tint: Palette.medication) {
                        draft.meds.removeAll { $0.id == med.id }
                    }
                }
                chip("+ add", on: false, tint: nil) { showMedSheet = true }
            }
        }
    }

    private var sleepRow: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            fieldLabel("Sleep")
            FlowChips {
                ForEach(sleepOptions, id: \.self) { option in
                    chip(option.capitalized, on: draft.sleepQuality == option, tint: nil) {
                        draft.sleepQuality = draft.sleepQuality == option ? nil : option
                    }
                }
            }
        }
    }

    private var noteRow: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack {
                fieldLabel("Note")
                Spacer()
                Text("optional")
                    .font(Typography.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            TextEditor(text: $draft.note)
                .font(Typography.body)
                .scrollContentBackground(.hidden)
                .padding(Spacing.m)
                .frame(minHeight: 110)
                .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Radius.card))
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(Typography.label)
            .textCase(.uppercase)
            .foregroundStyle(Theme.textSecondary)
    }

    private func chip(_ label: String, on: Bool, tint: Color?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(Typography.callout)
                .foregroundStyle(on ? (tint ?? Theme.accent) : Theme.textPrimary)
                .padding(.horizontal, Spacing.m)
                .padding(.vertical, Spacing.s)
                .background(Theme.cardBackground, in: Capsule())
                .overlay(
                    Capsule().strokeBorder(on ? (tint ?? Theme.accent) : .clear, lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
    }
}

/// Five equal segments; the selected one fills with the level's gradient.
struct SignalScaleRow<Level: SignalLevel & CaseIterable & Equatable>: View {
    let title: String
    @Binding var selection: Level?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack {
                Text(title)
                    .font(Typography.label)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Text(selection?.displayLabel ?? "—")
                    .font(Typography.callout)
                    .foregroundStyle(selection == nil ? Theme.textSecondary : Theme.textPrimary)
            }
            HStack(spacing: Spacing.xs + 2) {
                ForEach(Array(Level.allCases), id: \.numericValue) { level in
                    Button {
                        selection = selection == level ? nil : level
                    } label: {
                        RoundedRectangle(cornerRadius: Radius.control)
                            .fill(selection == level ? AnyShapeStyle(level.fillGradient) : AnyShapeStyle(Theme.cardBackground))
                            .frame(height: 30)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(title) \(level.displayLabel)")
                    .accessibilityAddTraits(selection == level ? [.isSelected] : [])
                }
            }
        }
    }
}

/// Minimal wrapping chip row.
struct FlowChips<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        // Layout protocol would be ideal; a simple wrapping HStack via
        // LazyVGrid keeps this dependency-free.
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: Spacing.s)], alignment: .leading, spacing: Spacing.s) {
            content
        }
    }
}

#Preview {
    TextCheckInComposer(recentMedicationNames: ["Concerta", "Magnesium"]) { _ in }
}
```

- [ ] **Step 2: Build**

Run: build command. Expected: `** BUILD SUCCEEDED **`. If `ForEach(Array(Level.allCases), id: \.numericValue)` fails to type-check, fall back to `id: \.displayLabel`.

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "feat(checkin): text composer — signal scales, med/sleep chips, optional note last"
```

---

### Task 8: CheckInView — hub, recording, saved; delete the old screen

**Files:**
- Create: `app-two/Views/CheckIn/CheckInView.swift`
- Modify: `app-two/Views/RootTabView.swift:24` (instantiate CheckInView)
- Modify: `app-two/DesignSystem/ScreenContainer.swift:12,21` + `app-two/DesignSystem/Typography.swift:13` (doc comments)
- Modify: `app-two/wireframes/SharedWireframes.swift:49` ("Record" → "Check in")
- Delete: `app-two/Views/RecordView.swift`, `app-two/Views/Components/AudioWaveform.swift`, `app-two/Views/Components/RecordingStatusPill.swift`, `app-two/wireframes/RecordWireframes.swift`

- [ ] **Step 1: Create CheckInView**

```swift
import SwiftUI

struct CheckInView: View {
    @State private var viewModel: CheckInViewModel
    @Environment(\.openURL) private var openURL
    @Environment(MedicationBarViewModel.self) private var medicationBarViewModel
    @Binding var shouldAutoStart: Bool

    @State private var showMedLogSheet = false
    @State private var showComposer = false

    init(store: RecordingStore, services: AppServices, shouldAutoStart: Binding<Bool> = .constant(false)) {
        _viewModel = State(wrappedValue: CheckInViewModel(store: store, services: services))
        _shouldAutoStart = shouldAutoStart
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        ScreenContainer(title: "", showsMedicationBar: true, scrollable: false) {
            VStack(alignment: .leading, spacing: 0) {
                headline
                content
            }
            .animation(.easeInOut(duration: 0.25), value: viewModel.state)
        }
        .trackScreen("CheckInView")
        .onAppear { consumeAutoStart() }
        .onChange(of: shouldAutoStart) { consumeAutoStart() }
        .sheet(isPresented: $showMedLogSheet) {
            MedicationLogSheet { name, dose, takenAt in
                medicationBarViewModel.logManualDose(name: name, dose: dose, takenAt: takenAt)
            }
        }
        .sheet(isPresented: $showComposer) {
            TextCheckInComposer(recentMedicationNames: viewModel.recentMedicationNames) { draft in
                viewModel.saveTextCheckIn(draft)
            }
        }
        .alert("Microphone Access Required", isPresented: $viewModel.permissionDenied) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Whisper Notes needs microphone access to record voice notes. Enable it in Settings.")
        }
        .alert("Not Enough Storage", isPresented: $viewModel.lowDiskSpace) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Whisper Notes needs at least 50 MB of free space to record. Free up some space and try again.")
        }
    }

    private func consumeAutoStart() {
        guard shouldAutoStart else { return }
        shouldAutoStart = false
        if viewModel.state == .done { viewModel.reset() }
        viewModel.startRecording()
    }

    private var headline: some View {
        Text(headlineText)
            .font(Typography.display)
            .foregroundStyle(Theme.textPrimary)
            .padding(.horizontal, Spacing.l)
            .padding(.top, Spacing.l)
            .accessibilityAddTraits(.isHeader)
    }

    private var headlineText: String {
        switch viewModel.state {
        case .idle: "How are you,\nright now?"
        case .recording, .paused: "Listening…"
        case .processing: "Saving…"
        case .done: "Check-in saved"
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle:
            hub
        case .recording, .paused, .processing:
            recordingStage
        case .done:
            CheckInSavedView(recording: viewModel.lastSavedRecording) {
                viewModel.reset()
            }
        }
    }

    // MARK: Hub

    private var hub: some View {
        GeometryReader { geo in
            ZStack {
                CrescentRing()
                    .frame(width: ringSide(in: geo), height: ringSide(in: geo))
                VStack(spacing: Spacing.m) {
                    hubOption("Log meds", icon: Icons.medication, tint: Palette.medication) {
                        showMedLogSheet = true
                    }
                    speakButton
                    hubOption("Type note", icon: "square.and.pencil", tint: nil) {
                        showComposer = true
                    }
                }
                .frame(width: ringSide(in: geo) * 0.62)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func ringSide(in geo: GeometryProxy) -> CGFloat {
        min(geo.size.width - Spacing.l * 2, geo.size.height - Spacing.l, 320)
    }

    private var speakButton: some View {
        Button {
            viewModel.startRecording()
        } label: {
            HStack(spacing: Spacing.s) {
                Image(systemName: "mic.fill")
                Text("Speak check-in").font(Typography.headline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.l)
            .background(Theme.accent, in: RoundedRectangle(cornerRadius: Radius.card + 4))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Start voice check-in")
    }

    private func hubOption(_ label: String, icon: String, tint: Color?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.s) {
                Image(systemName: icon).foregroundStyle(tint ?? Theme.textPrimary)
                Text(label).font(Typography.headline).foregroundStyle(Theme.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.m)
            .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Radius.card + 4))
        }
        .buttonStyle(.plain)
    }

    // MARK: Recording

    private var recordingStage: some View {
        VStack(spacing: Spacing.l) {
            CheckInNudges(nudges: viewModel.currentNudges)
                .padding(.horizontal, Spacing.l)

            ZStack {
                CrescentRing(isActive: true)
                    .frame(width: 280, height: 280)
                VStack(spacing: Spacing.m) {
                    Text(viewModel.timeString)
                        .font(Typography.timer)
                        .foregroundStyle(Theme.textPrimary)
                    RecordingWave()
                    stopButton
                    Button("Cancel") { viewModel.cancelRecording() }
                        .font(Typography.callout)
                        .foregroundStyle(Theme.textSecondary)
                        .accessibilityLabel("Cancel recording")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var stopButton: some View {
        Button {
            viewModel.stopRecording()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: Radius.card + 6)
                    .fill(.red)
                    .frame(width: 64, height: 64)
                if viewModel.state == .processing {
                    ProgressView().tint(.white)
                } else {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(.white)
                        .frame(width: 22, height: 22)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(viewModel.state == .processing)
        .accessibilityLabel("Finish check-in")
    }
}

// MARK: - Nudges

private struct CheckInNudges: View {
    let nudges: [String]

    var body: some View {
        VStack(spacing: Spacing.s) {
            Text("a few things you might mention")
                .font(Typography.label)
                .textCase(.uppercase)
                .foregroundStyle(Theme.textSecondary)
            VStack(spacing: Spacing.xs + 2) {
                ForEach(nudges, id: \.self) { nudge in
                    Text(nudge)
                        .font(Typography.callout)
                        .foregroundStyle(Theme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.s)
                        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Radius.control))
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: nudges)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Suggestions: \(nudges.joined(separator: ", "))")
    }
}

// MARK: - Recording wave (replaces AudioWaveform, compact)

private struct RecordingWave: View {
    private let barCount = 15

    var body: some View {
        TimelineView(.animation) { timeline in
            HStack(spacing: 4) {
                ForEach(0..<barCount, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.primary.opacity(0.6))
                        .frame(width: 4, height: barHeight(for: index, at: timeline.date))
                }
            }
        }
        .frame(height: 44)
        .accessibilityHidden(true)
    }

    private func barHeight(for index: Int, at date: Date) -> CGFloat {
        guard !AccessibilityHelpers.isReduceMotionEnabled else { return 8 }
        let time = date.timeIntervalSince1970
        return CGFloat(sin(time * 5 + Double(index) * 0.5) * 16 + 22)
    }
}

// MARK: - Saved

private struct SavedChip: Identifiable {
    let label: String
    let color: Color
    var id: String { label }
}

private struct CheckInSavedView: View {
    let recording: Recording?
    let onNewCheckIn: () -> Void

    var body: some View {
        VStack(spacing: Spacing.l) {
            Spacer()
            Image(systemName: "checkmark.circle")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(Theme.statusDone)
            if let recording {
                savedDetails(for: recording)
            }
            Spacer()
            Button("New check-in", action: onNewCheckIn)
                .font(Typography.headline)
                .foregroundStyle(Theme.accent)
                .padding(.bottom, Spacing.hero)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Spacing.l)
    }

    @ViewBuilder
    private func savedDetails(for recording: Recording) -> some View {
        let chips = savedChips(for: recording)
        if chips.isEmpty {
            Text("Picking out the details…")
                .font(Typography.callout)
                .foregroundStyle(Theme.textSecondary)
        } else {
            Text("We picked these up — tweak any time on the entry.")
                .font(Typography.callout)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            FlowChips {
                ForEach(chips) { chip in
                    HStack(spacing: Spacing.xs) {
                        Circle().fill(chip.color).frame(width: 8, height: 8)
                        Text(chip.label).font(Typography.caption).foregroundStyle(Theme.textPrimary)
                    }
                    .padding(.horizontal, Spacing.s + 2)
                    .padding(.vertical, Spacing.xs + 2)
                    .background(Theme.cardBackground, in: Capsule())
                }
            }
        }
    }

    private func savedChips(for recording: Recording) -> [SavedChip] {
        var chips: [SavedChip] = []
        if let mood = MoodLevel(name: recording.mood) {
            chips.append(SavedChip(label: mood.displayLabel, color: mood.color))
        }
        if let energy = recording.energyLevel.flatMap({ EnergyLevel(rawValue: $0.lowercased()) }) {
            chips.append(SavedChip(label: energy.displayLabel, color: energy.color))
        }
        if let focus = recording.focusLevel.flatMap({ FocusLevel(rawValue: $0.lowercased()) }) {
            chips.append(SavedChip(label: focus.displayLabel, color: focus.color))
        }
        var seenMeds = Set<String>()
        for event in recording.medicationEvents where seenMeds.insert(event.name.lowercased()).inserted {
            chips.append(SavedChip(label: event.name, color: Palette.medication))
        }
        if let quality = recording.sleepQuality {
            chips.append(SavedChip(label: "\(quality.capitalized) sleep", color: .indigo))
        }
        return chips
    }
}

#Preview {
    CheckInView(store: .preview, services: .preview)
        .withPreviewEnvironment()
}
```

- [ ] **Step 2: Swap the tab + delete the old screen**

In `app-two/Views/RootTabView.swift:24`:

```swift
CheckInView(store: store, services: services, shouldAutoStart: $shouldAutoStartRecording)
```

```bash
git rm app-two/Views/RecordView.swift \
       app-two/Views/Components/AudioWaveform.swift \
       app-two/Views/Components/RecordingStatusPill.swift \
       app-two/wireframes/RecordWireframes.swift
```

In `app-two/wireframes/SharedWireframes.swift:49`, change the tab item title/selection strings `"Record"` → `"Check in"`.
Doc comments: `ScreenContainer.swift:12,21` RecordView → CheckInView; `Typography.swift:13` "Insights section titles only" → "Insights section titles and the Check-in headline".

- [ ] **Step 3: Build + full test suite**

Run: build, then full `xcodebuild test` (no `-only-testing`).
Expected: `** BUILD SUCCEEDED **`, `** TEST SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "feat(checkin): CheckInView hub/recording/saved — HWF crescent, nudges, stop-is-done; delete RecordView stack"
```

---

### Task 9: Simulator verification + docs

- [ ] **Step 1: Run on the simulator and capture both modes**

Boot `667B75F8-4C75-4A14-ACE1-D5C46F3CBC0D`, install, launch (`Rythm-App.app-two`). On-device mock data auto-seeds; if onboarding blocks, use the temporary `AppSettings(hasCompletedOnboarding: true)` seed trick from the Insights verification (revert after). Capture light+dark screenshots of: hub, recording (nudges visible), composer, saved-with-chips. Verify: crescent rotates (and is static under Reduce Motion), nudge trio advances at 6 s, stop returns to saved, chips appear after processing.

- [ ] **Step 2: Update UI_REQUIREMENTS.md references**

`app-two/UI_REQUIREMENTS.md:60,75,80,81,87` — Record screen section now describes the Check-in hub (brief edit, not a rewrite).

- [ ] **Step 3: Full suite once more + commit**

```bash
git add -A && git commit -m "docs(checkin): UI requirements + verification pass"
```

---

## Spec coverage checklist (self-review)

| Signed-off decision | Task |
|---|---|
| Tab renamed Record → "Check in" | 1 |
| HWF rotating crescent, native palette, no hand-drawn assets | 6, 8 |
| Three options inside the crescent; Speak = accent primary | 8 |
| Med bar stays on top; hub "Log meds" = standalone dose via existing sheet/VM | 8 |
| Voice records immediately; crescent spins faster as live indicator | 6, 8 |
| Three nudges at a time; trio 1 mood/energy/focus, trio 2 sleep/feelings/side effects; 6 s cadence | 5, 8 |
| Stop = done, no review; tags extracted in background, editable later | 5 (kept pipeline), 8 (saved view) |
| Saved confirmation with picked-up chips | 8 |
| Text composer: Mood/Energy/Focus scales → Meds → Sleep → optional Note LAST → Save | 7 |
| Selectors authoritative; note NLP fills only nils; no med duplication | 2, 3, 4, 5 |
| Everything optional; Save disabled only when draft fully empty | 3 (isEmpty), 7 |
| Deep link whispernotes://checkin still auto-starts voice (incl. already-on-tab fix) | 1, 8 |
| Dead code removed (pause/resume, AudioWaveform, RecordingStatusPill, CaptureMode, wireframes, createTextRecording) | 5, 8 |
| Replaces disabled RecordViewModelTests with live suite + MockAppServices | 5 |

**Known deliberate scope cuts:** sleep hours input (quality chips only — hours still arrive via note/voice extraction); live transcript display during recording (feature-flagged off today, not resurrected); the broken audio-interruption pipeline (pre-existing service-level issue, documented in verification — out of scope).
