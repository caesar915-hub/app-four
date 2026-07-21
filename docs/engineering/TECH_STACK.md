<!-- Created: 2026-07-11 00:00 (WEST) · Updated: 2026-07-18 17:53 (WEST) -->
# Squirl — Technical Stack

> **Current-state truth**, reconstructed from the codebase on branch `feat/038-icloud-sync` (v0.8.0, build 2).
> Every claim is cited to `file:line`, `project.pbxproj`, or `Package.resolved`, verified against source.
> Status legend: ✅ Shipped · 🔶 Interim (deliberately downgraded) · 🧪 Prototype (out-of-target) · 🔭 Planned.

---

## 0. Discrepancy ledger (older PRD draft vs. verified code)

These corrections are why this document exists; the prior PRD draft described a target the code has since moved away from.

| Prior draft said | Verified reality | Source |
|---|---|---|
| UI: "iOS 26 Liquid Glass" | **iOS 26.0** deployment target (raised back from 17.0 in `003acf20`, "restore modern APIs"); Liquid Glass still referenced in comments only, never called — the med bar uses `.newLookCard()`. | `IPHONEOS_DEPLOYMENT_TARGET = 26.0`; [MedicationBarView.swift:19](../../app-four/Views/Components/MedicationBarView.swift#L19) |
| Language: "Swift 6+ (strict concurrency)" | **Swift 5 language mode** with Approachable Concurrency + MainActor-by-default isolation. Strict `complete` is **not** set. | `SWIFT_VERSION = 5.0`, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `SWIFT_APPROACHABLE_CONCURRENCY = YES` |
| Typography: "Fraunces + DM Sans" | Migrated to **SF Pro + SF Mono**; custom fonts removed from target (no `UIAppFonts`, no bundled `.ttf`). | [Typography.swift:4-8](../../Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/Typography.swift#L4-L8) |
| Schema: "no `@Attribute(.unique)` … violation: `Recording.id`" | Spec 038 split the store: the four **synced** models (`Recording`, `TranscriptionSegment`, `RecordingTag`, `MedicationEvent`) are now `.unique`-free; only `AppSettings` + `ModelMetadata` keep `.unique`, and they live in the never-synced **Local** store (so CloudKit is unaffected). | grep `app-four/Models/*` (2 hits); [AppModelContainer.swift:18-23](../../app-four/App/AppModelContainer.swift#L18-L23) |
| "MVVM with `@MainActor @Observable` view models" | ✅ Accurate — 13 view models, all `@Observable @MainActor`, zero `ObservableObject`. | [ViewModels/](../../app-four/ViewModels/) |
| WhisperKit "Whisper Small" | ✅ `openai_whisper-small` wired. (`ModelMetadata` defaults still say `"base"`/74 MB — stale, overwritten at runtime.) | [WhisperKitTranscriptionService.swift:11](../../app-four/Services/WhisperKit/WhisperKitTranscriptionService.swift#L11) |

> **Note on the concurrency label.** Swift-5 language mode ≠ "no concurrency safety." `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (Xcode 26 / Swift 6.2 "Approachable Concurrency") makes unannotated code implicitly `@MainActor`, so the app is data-race-safe *by default construction* and opts **out** with `actor`/`nonisolated` for background work. The PRD's intent ("modern, safe concurrency") is correct; the label ("Swift 6 strict") is not.

---

## 1. Platform & Build

| Concern | Value | Source |
|---|---|---|
| Min OS | **iOS 26.0** (iPhone + iPad; `TARGETED_DEVICE_FAMILY` 1,2) | pbxproj (`IPHONEOS_DEPLOYMENT_TARGET = 26.0`) |
| Toolchain language mode | App: **Swift 5**; SPM packages: tools-6.0, `swiftLanguageModes: [.v5]` | pbxproj; [Package.swift](../../Packages/SquirlDesignSystem/Package.swift#L19) |
| Concurrency profile | MainActor default isolation + Approachable Concurrency; `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES` | pbxproj |
| App version | `MARKETING_VERSION 0.8.0`, build `2` | pbxproj |
| Bundle ID / Team | `squirl-app.app-four` / `SWFNK3KULQ` | pbxproj |
| Display name / category | **Squirl** / `productivity` | `INFOPLIST_KEY_*` |
| URL scheme | `whispernotes` (legacy `com.rythmapp.whispernotes`) | `INFOPLIST_KEY_CFBundleURLTypes` |
| Background mode | `audio` | [Info.plist:7-10](../../app-four/Info.plist#L7-L10) |
| Privacy strings | Microphone, Speech Recognition | `INFOPLIST_KEY_NS*UsageDescription` |
| File exposure | `UIFileSharingEnabled`, `LSSupportsOpeningDocumentsInPlace` = YES | `INFOPLIST_KEY_*` |
| Encryption declaration | `ITSAppUsesNonExemptEncryption = false` | [Info.plist:5-6](../../app-four/Info.plist#L5-L6) |
| Entitlements | **None wired** into shipping target (still no `CODE_SIGN_ENTITLEMENTS`). Spec 038 code references iCloud container `iCloud.Rythm-App.app-four` + the `com.apple.developer.icloud-container-identifiers` entitlement, but it is **not yet added to the build**. HealthKit/iCloud entitlements also live in `.claude/worktrees/*` prototypes. | grep pbxproj (0 `CODE_SIGN_ENTITLEMENTS`/iCloud hits); [AppModelContainer.swift:25-27](../../app-four/App/AppModelContainer.swift#L25-L27) |
| Script sandboxing | `ENABLE_USER_SCRIPT_SANDBOXING = YES` | pbxproj |
| CI/CD, lint, format | **None** — no `.github/workflows`, fastlane, SwiftLint/SwiftFormat | repo-root scan |

## 2. Dependencies (SPM only — no CocoaPods/Carthage)

**Direct (app target):**

- **WhisperKit** `1.0.0` — argmaxinc; on-device Whisper via CoreML/Metal — [Package.resolved:104-111](../../app-four.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved#L104-L111)
- **swift-transformers** `1.3.3` — Hugging Face tokenizers (surfaced as `Tokenizers`)

**Local packages (`Packages/`):**

- **SquirlSignals** — pure domain enums: `MoodLevel`, `EnergyLevel`, `FocusLevel`, `SleepLevel` (5-point signal ramps). No dependencies. [Levels.swift](../../Packages/SquirlSignals/Sources/SquirlSignals/Levels.swift)
- **SquirlDesignSystem** — depends on SquirlSignals; owns typography, palette, spacing, radius, motion, haptics, and the signal-glyph shapes (Sprout/Bolt/Aperture/Bed/Capsule as SwiftUI `Shape`s). Re-exported app-wide via `@_exported import` in [SignalsReexport.swift](../../app-four/App/SignalsReexport.swift).

**Transitive (pinned, via WhisperKit/transformers):** swift-nio 2.100.0, swift-crypto 4.5.0, swift-collections 1.5.1, swift-argument-parser 1.8.2, swift-system 1.7.2, swift-atomics 1.3.1, swift-asn1 1.7.0, swift-huggingface 0.9.0, swift-jinja 2.3.6, EventSource 1.4.1, yyjson 0.12.0 — [Package.resolved](../../app-four.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved)

## 3. Architecture

- **Pattern:** MVVM + a thin Store/repository layer. Entry [SquirlApp.swift:4](../../app-four/App/SquirlApp.swift#L4) (`WindowGroup` → `RootContainerView` → `RootTabView`).
- **DI:** `@MainActor enum AppDependencies` composes all singletons at launch ([AppDependencies.swift](../../app-four/Store/AppDependencies.swift)); injected via SwiftUI `.environment(...)`. Service bundle: `@Observable @MainActor final class AppServices` ([AppServices.swift](../../app-four/Store/AppServices.swift)).
- **Navigation:** root `TabView`, 4 tabs — `calendar`, `checkIn`, `insights`, `settings` ([RootTabView.swift:5-19](../../app-four/Views/RootTabView.swift#L5-L19)); each tab embeds its own `NavigationStack`. Onboarding is a `.fullScreenCover` gated on `AppSettings.hasCompletedOnboarding`.
- **View models:** 13, all `@Observable @MainActor final class` (CheckIn, Insights, Settings, AudioPlayback, MoodLibrary, Processing, ExtractionReview, RecordingDetail, MedicationBar, MedicationPicker, Welcome, + Calendar/DayTimeline helpers).
- **State management:** dominant `@State` (local) + `@Environment` (services); `@AppStorage` for prefs (`debugMockMode`, card-expand flags, med-bar config); `@Bindable` for VM binding; `@Query` used only in a test view.
- **Store layer:** `@Observable @MainActor class RecordingStore` wraps `ModelContext`, owns the `[Recording]` array, recovers orphaned transcriptions on init ([RecordingStore.swift:4-36](../../app-four/Store/RecordingStore.swift#L4-L36)).

## 4. Persistence (SwiftData)

- **Container:** `@MainActor enum AppModelContainer` — **two on-disk configurations** in one container (spec 038): **Synced** (`Recording`/`TranscriptionSegment`/`RecordingTag`/`MedicationEvent`, mirrored to the user's private CloudKit DB when opted in) + **Local** (`AppSettings`/`ModelMetadata`, never synced). Store dir excluded from iCloud device backup; wipe-and-rebuild on schema mismatch. Preview config is `isStoredInMemoryOnly: true`. [AppModelContainer.swift:16-99](../../app-four/App/AppModelContainer.swift#L16-L99)
- **6 `@Model` types:** `Recording` (aggregate root) → cascade to `TranscriptionSegment`, `RecordingTag` (correction tags), `MedicationEvent`; plus `ModelMetadata`, `AppSettings`.
- **Mock/prod split:** `isMockData: Bool` on `Recording` + `MedicationEvent`, partitioned by `debugMockMode` via `#Predicate` ([RecordingStore.swift:40-45](../../app-four/Store/RecordingStore.swift#L40-L45)).
- **Migrations:** `SquirlSchemaV1: VersionedSchema` + `SquirlMigrationPlan` now wired (spec 038) so the next change is a clean V1→V2; pre-release schema mismatch is still recovered by wipe-and-rebuild. [SquirlSchema.swift:15-26](../../app-four/App/SquirlSchema.swift#L15-L26)
- **CloudKit:** `cloudKitDatabase: .private("iCloud.Rythm-App.app-four")` on the Synced config **when `SyncFlags.iCloudSyncEnabled`**, else `.none` — **off by default** (spec 038). Synced models are now `.unique`-free; the two remaining `.unique` ids sit in the never-synced Local store (§3.3). [AppModelContainer.swift:35-42](../../app-four/App/AppModelContainer.swift#L35-L42)
- **Rich-value encoding:** signal enums persist as raw `String`/`Int`; complex value types (`NoteExtraction`, `SleepEvent`, topic tags, emotions, bullets) stored as **JSON strings** on `Recording`.

### 3.3 Persistence Schema (corrected, paste-ready for the PRD)

Production `ModelContainer` holds **6 `@Model` types**: `Recording`, `TranscriptionSegment`, `ModelMetadata`, `AppSettings`, `RecordingTag`, `MedicationEvent`. `Recording` is the aggregate root, owning cascade-delete relationships to `segments` (`TranscriptionSegment`), `correctionTags` (`RecordingTag`), and `medicationEvents` (`MedicationEvent`).

- **Two** named on-disk `ModelConfiguration`s in one container (spec 038): **Synced** (journal models, CloudKit-mirrored when opted in) and **Local** (`AppSettings`/`ModelMetadata`, never synced). Store dir excluded from iCloud device backup. A separate in-memory configuration backs SwiftUI previews.
- **Versioned schema now wired** (`SquirlSchemaV1: VersionedSchema` + `SquirlMigrationPlan`) so the next schema change is a clean V1→V2 migration; pre-release, a schema mismatch is still recovered by wipe-and-rebuild at launch.
- Mock vs. real data is partitioned by an `isMockData` boolean (on `Recording` and `MedicationEvent`), filtered via `#Predicate` against the `debugMockMode` flag.
- Rich value types are denormalized to **JSON strings** on `Recording` (`noteExtractionJSON`, `sleepEventJSON`, `emotionsJSON`, `topicTagsJSON`, `summaryBulletsJSON`); signal enums persist as raw `String`/`Int`.
- Schema is CloudKit-compatible on the Synced store (attributes optional/defaulted). **Resolved (spec 038):** `@Attribute(.unique)` was removed from the four synced models (`Recording`, `TranscriptionSegment`, `RecordingTag`, `MedicationEvent`); only `AppSettings` + `ModelMetadata` still carry `.unique`, and they live in the never-synced **Local** store, so CloudKit's no-unique-constraint rule is satisfied.

## 5. On-device intelligence pipeline

**Flow: record → file → batch transcribe → NL extract → persist.** No live-mic streaming transcription.

- **Audio capture:** `AVAudioRecorder`, **MPEG-4 AAC @ 16 kHz**, metered (0–1 level `AsyncStream` every 50 ms), interruption-resilient. Temp dir → `~/Documents/Recordings/recording_<UUID>.m4a`. [AudioRecordingServiceImpl.swift:5-74](../../app-four/Services/Audio/AudioRecordingServiceImpl.swift#L5-L74)
- **Transcription:** `protocol TranscriptionService` → `transcribe(audioURL:) async throws -> AsyncStream<TranscriptionSegmentDTO>`. Conformers:
  - `actor WhisperKitTranscriptionService` — `openai_whisper-small`, CoreML, optional ADHD/medication context prompt (`UserDefaults.medicalPromptEnabled`), unloads model after stream to reclaim RAM. *(Wired default.)*
  - `actor SpeechTranscriptionService` — `SFSpeechRecognizer`, `requiresOnDeviceRecognition = true`. *(Standby.)*
  - `final class MockTranscriptionService` — test/placeholder.
- **Model management:** `@MainActor final class AIModelServiceImpl` — downloads `openai_whisper-small` via `WhisperKit.download`, progress as `AsyncThrowingStream<Double>`, to `~/Library/whisperkit/`; filesystem is source of truth, mirrored into `ModelMetadata`. `enum AIModelType { case whisper }` — single case (no Gemma anywhere). [AIModelServiceImpl.swift](../../app-four/Services/AIModelServiceImpl.swift)
- **Pending queue:** `actor PendingTranscriptionService` drains `.pendingTranscription` recordings once the model is ready (single shared engine).
- **Extraction:** `struct NLSummarizationService` runs `nonisolated struct NLNoteExtractor` off-main via `Task.detached(.userInitiated)`. Uses Apple **NaturalLanguage** (`NLTokenizer` sentence/word, `NLTagger` `.lexicalClass`/`.lemma`) over a bundled `lexicon.json` + `TenseClassifier` — deterministic, instant, **no model load**. Extracts mood/energy/focus/sleep/emotions/medications (dose, time, negation, change)/activities/highlights/title. NL sentiment deliberately **not** used (biased on neutral text). **English-only.** [NLNoteExtractor.swift:11](../../app-four/Services/NoteExtraction/NLNoteExtractor.swift#L11)
- **Not present:** Gemma, direct MLModel/CoreML use (only via WhisperKit), FoundationModels / Apple Intelligence.

## 6. Supporting services

- `actor NetworkConnectivity` — `NWPathMonitor`, streams interface/satisfaction changes. [NetworkConnectivity.swift:7](../../app-four/Services/Connectivity/NetworkConnectivity.swift#L7)
- `struct ExportServiceImpl` — **AES-GCM encrypted** journal export, fresh 256-bit `SymmetricKey` per export (CryptoKit). [ExportService.swift:123](../../app-four/Services/ExportService.swift#L123)
- **iCloud sync seam (spec 038 — in progress, uncommitted on `feat/038-icloud-sync`):** `protocol CloudSyncService` + `CloudSyncServiceImpl` (CloudKit) + `MockCloudSyncService`, injected via `AppDependencies`. **Off by default** via `SyncFlags` (`UserDefaults`-backed, never synced). Content-free status types (`SyncAccountStatus`/`SyncFailure`/`SyncPhase`/`SyncState`) map `CKAccountStatus`/`CKError` so Settings can show an honest status and never a false "synced". [CloudSyncService.swift](../../app-four/Services/Sync/CloudSyncService.swift); [SyncFlags.swift](../../app-four/App/SyncFlags.swift)

## 7. Observability & privacy

- **Diagnostics:** `actor DiagnosticsStore` keeps a rolling **50-snapshot** JSON buffer in-sandbox. `SessionSnapshot` records *only* thermal state, available memory, Whisper duration ms, token-count estimates, iOS/build, screen name — and **explicitly excludes** transcript/summary text and audio paths. [SessionSnapshot.swift:3-18](../../app-four/Diagnostics/SessionSnapshot.swift#L3-L18)
- **MetricKit:** `MetricManager` consumes jetsam/CPU/disk/hang/launch payloads; console-logged, **no auto-upload**. Feedback is user-initiated email only.
- **Logging:** lightweight `AppLogger.log` (stdout with file:function) — **not** `os.Logger`/OSLog.

## 8. Testing

- **Framework:** **Swift Testing** exclusively (`import Testing`, `@Test`, `#expect`) — **zero XCTest**.
- **Scale:** **49 test files**, ~340 `@Test` cases. Heaviest coverage: NLP extraction, AI-model lifecycle, view models, persistence/recovery, diagnostics.
- **Mocks:** 7 actor-based service mocks with state/error/cancellation injection; in-memory `ModelContainer` for data tests; `TestSupport.useRealData()` prevents mock-mode pollution.
- **UI:** verified by build + device QA (no automated UI tests; simulator not used per project workflow).

## 9. Roadmap / deferred (verified absent from the shipping target today)

| Item | Status in code | Where it lives | Decision needed |
|---|---|---|---|
| iOS 26 **Liquid Glass** | 🔭 Available now (min-OS is iOS 26.0) but still not adopted; `.glassEffect` never called; med bar uses `.newLookCard()` | — | Adopt in the med bar / cards when the New Look pass reaches it |
| **Swift 6** mode + strict-`complete` | 🔶 Swift 5 mode + MainActor-default isolation | — | Flip when ready; isolation groundwork done |
| **CloudKit** sync | 🔶 Seam built on `feat/038-icloud-sync` (uncommitted): two-store container, `cloudKitDatabase` gated by `SyncFlags` (off by default), synced models `.unique`-free, `CloudSyncService` protocol+impl+mock | `app-four/Services/Sync/`, `App/SyncFlags.swift` | Wire the iCloud entitlement + container into the target; land US1 real impl |
| **HealthKit** | 🧪 No entitlement in target | `.claude/worktrees/feat+healthkit-signals` | Promote prototype → target when planned |
| **Weather / check-in** signals | 🧪 No entitlement in target | `.claude/worktrees/feat+weather-checkin` | Same |
| Higher-precision Whisper (Medium/Large) | 🔭 `AIModelType` has only `.whisper` (small) | — | Evaluate vs A14 device floor (iPhone 12) |
| Multilingual extraction | 🔭 English lexicon only | PR #14 (multilingual rewrite) | Pick `NLNoteExtractor` lineage before re-porting |
| **Fraunces + DM Sans** typography | 🔶 Replaced by SF Pro/SF Mono; fonts removed | historical `.ttf` only in a worktree | DESIGN.md still claims Fraunces — reconcile |

---

## 10. Core Technology Stack — table for the PRD (with Status column)

Status legend: ✅ Shipped · 🔶 Interim · 🧪 Prototype (out-of-target) · 🔭 Planned.

| Concern | Current Choice (shipped) | Status / Roadmap |
|---|---|---|
| Language | Swift 5 language mode | 🔶 ✅ Strict-concurrency groundwork in place (MainActor-default + Approachable Concurrency). 🔭 Flip to Swift 6 mode + `complete` when ready. |
| UI | SwiftUI, **iOS 26.0** min target | ✅ Raised back to iOS 26.0 (`003acf20`, "restore modern APIs"). 🔭 Liquid Glass available now but not yet adopted; med bar uses `.newLookCard()`. |
| Architecture | MVVM — 13 `@Observable @MainActor` view models + `RecordingStore` + `AppDependencies` DI | ✅ |
| Persistence | SwiftData, **two on-disk configs** (Synced + Local) in one container, versioned schema (V1) | ✅ Local. 🔶 CloudKit opt-in seam built (spec 038, off by default); synced models now `.unique`-free (§3.3). |
| Concurrency | Swift Concurrency — actors, `async`/`await`, `Sendable`, `AsyncStream` | ✅ |
| Transcription | WhisperKit 1.0.0, `openai_whisper-small`, on-device, file-based batch | ✅ Wired. Standby: `SFSpeechRecognizer`. 🔭 Higher-precision Whisper pending A14 eval. |
| Extraction | Apple `NaturalLanguage` (`NLTokenizer`/`NLTagger` + lexicon + tense), off-main, deterministic, English-only | ✅ 🔭 Multilingual rewrite (PR #14) pending lineage decision. |
| Audio capture | `AVAudioRecorder`, MPEG-4 AAC @ 16 kHz, metered, interruption-resilient | ✅ |
| Export | AES-GCM encrypted journal export (CryptoKit, per-export 256-bit key) | ✅ |
| Typography | **SF Pro + SF Mono** (Dynamic Type via `UIFontMetrics`) | 🔶 Migrated off Fraunces + DM Sans. ⚠ DESIGN.md still cites Fraunces — reconcile. |
| Design System | `SquirlDesignSystem` SPM package (palette, spacing, signal-glyph `Shape`s) + `SquirlSignals` | ✅ |
| Sync | iCloud/CloudKit — **off by default**, opt-in seam on `feat/038-icloud-sync` (`CloudSyncService` + `SyncFlags`) | 🔶 In progress (uncommitted); iCloud entitlement not yet wired into the target. |
| HealthKit | — | 🧪 Prototype in `feat+healthkit-signals` worktree. |
| Weather / check-in signals | — | 🧪 Prototype in `feat+weather-checkin` worktree. |
| Diagnostics | MetricKit + privacy-safe `SessionSnapshot` (50-item JSON buffer); no auto-upload | ✅ |
| Testing | Swift Testing (`@Test`/`#expect`) — 49 files, ~340 cases; 7 actor mocks; in-memory `ModelContainer` | ✅ No XCTest, no automated UI tests (device QA per workflow). |
| CI/CD · Lint | None | 🔭 No GitHub Actions / fastlane / SwiftLint configured. |
