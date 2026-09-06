<!-- Created: 2026-09-06 03:14 (WEST) · Updated: 2026-09-06 03:14 (WEST) -->
# Apple SpeechAnalyzer / SpeechTranscriber — Adoption Guide & Generic Implementation Plan

> Scope: on-device speech-to-text with Apple's `SpeechAnalyzer` stack (iOS/iPadOS/macOS/Mac Catalyst/tvOS/visionOS **26.0+**), with `DictationTranscriber` as the compatibility fallback, wired into a generic Swift 6 / SwiftUI app. Signatures are quoted from Apple's documentation JSON and the WWDC25 sample; anything reconstructed, beta-flagged, or community-sourced is called out explicitly.

---

## 1. Executive summary

`SpeechAnalyzer` is Apple's iOS 26 on-device speech-to-text framework, introduced at WWDC25 session 277 as the modern successor to iOS 10's `SFSpeechRecognizer` [1][25]. It is a **session actor** that hosts pluggable **modules**; the general-purpose transcription module is `SpeechTranscriber` [1][2]. You feed it audio as an `AsyncSequence` of `AnalyzerInput` and read results off `transcriber.results`, another `AsyncSequence` — input and output are decoupled and buffered by Swift concurrency [1][4].

**The model.** Transcription is powered by a new Apple speech model that is **downloaded and system-managed**, not bundled. It lives in system storage, is shared across all apps, auto-updates with the OS, and adds **zero bytes** to your app's download size, disk footprint, or runtime memory [5][25]. You request installation through `AssetInventory`; you never ship or manage model files [5].

**Why adopt.** It is engineered for long-form, conversational, distant-mic, and low-latency live transcription — the cases where `SFSpeechRecognizer` degrades (it defaults to a server path and struggles past ~1 minute) [1][4]. It is already the engine behind several of Apple's own first-party experiences — Notes, Voice Memos, the **Journal** app, and Call transcription/summarization [25] — strong adoption evidence for long-form dictation and personal-capture use cases. Independent benchmarks put it in the mid-tier speed/accuracy band: competitive with a small Whisper model on English while running ~2–3× faster, and roughly interchangeable-to-better depending on the corpus [33][34][35]. For an app currently bundling or downloading a large third-party model (e.g. WhisperKit small ~500 MB), the biggest structural win is eliminating that failure-prone download path in favor of a system-managed asset [5][33].

**The fallback story.** `SpeechTranscriber` is hardware-gated: `static var isAvailable: Bool` is **false** on A13/8-core-Neural-Engine devices (iPhone 11 family, SE 2nd gen, older iPads) and in the Simulator, and `supportedLocales` returns an **empty array** on unsupported devices [14][13][26][27]. The documented fallback is `DictationTranscriber` — same on-device model reach as legacy `SFSpeechRecognizer`, no `isAvailable` gate, broader language coverage — which plugs into the same `SpeechAnalyzer` [3][4]. Below iOS 26 there is no back-deployment, so you keep `SFSpeechRecognizer` or a bundled Whisper as the floor [4][37].

**Verdict.** Adopt `SpeechAnalyzer` as the primary engine for any iOS-26-capable device and supported locale; it is faster, private, natively integrated, and removes the model-download burden. Wrap it behind an app-owned protocol with a `SpeechTranscriber → DictationTranscriber → (legacy) SFSpeechRecognizer/Whisper` ladder so unsupported hardware, unsupported locales, and older OSes degrade gracefully rather than failing the feature. The two hard, real-world traps are **audio-format conversion** (mismatched buffers silently produce zero output) and **task cancellation/finalization** on teardown [4][39].

---

## 2. Framework architecture

### 2.1 The session-plus-modules model

Apple's mental model, verbatim: *"The `SpeechAnalyzer` class manages an analysis session. You can add a module class to the session to perform a specific type of analysis. Adding a transcriber module to the session makes it a transcription session that performs speech-to-text processing."* [25]

- **`SpeechAnalyzer`** — `final actor` that owns the session: it holds modules, accepts one audio input sequence at a time, and controls the lifecycle (start, finalize, finish, cancel) [1].
- **`SpeechModule`** — the base protocol every module conforms to. Modules expose their own `results` async sequence and their compatible audio formats [16].
- **Modules that ship:** `SpeechTranscriber` (general conversation/dictation), `DictationTranscriber` (older-device / broader-language fallback), and `SpeechDetector` (voice-activity detection — see §4.6) [4][16][42].

Results come from **each module**, not the analyzer — `for try await result in transcriber.results` — a common first-timer mistake is looking for results on the analyzer [4].

### 2.2 SpeechTranscriber vs DictationTranscriber

| | `SpeechTranscriber` | `DictationTranscriber` |
|---|---|---|
| Purpose | Long-form, conversational, far-field, live captioning [1] | System-dictation parity, older-device compat [3] |
| Model | New Apple speech model [25] | Same model as on-device `SFSpeechRecognizer` [3] |
| `isAvailable` gate | **Yes** — `static var isAvailable: Bool` [14] | **No such API** (doc page 404s) [3][27] |
| Locale reach | ~limited set (~10–25+, device/OS-dependent) [4][13] | Broader — the `SFSpeechRecognizer` on-device set [3] |
| Platforms | iOS/iPadOS/macOS/Mac Catalyst/**tvOS**/visionOS 26 [1] | iOS/iPadOS/macOS/Mac Catalyst/visionOS 26 (**no tvOS listed**) [3] |
| Extra tuning | — | `contentHints` (`.farField`, `.customizedLanguage`, `.atypicalSpeech`, `.shortForm`) [3] |

Both conform to `LocaleDependentSpeechModule` and share the locale/asset APIs; both plug into the same `SpeechAnalyzer` [3][17].

### 2.3 The downloaded model

Assets are ML models downloaded from Apple's servers and managed by the system; once installed, the system retains, updates, and shares them across apps [5]. You configure modules; the system infers which assets are needed. You never touch asset files directly [5].

### 2.4 How the pieces fit

```
                     ┌──────────────────────────────────────────┐
   AVAudioEngine     │              SpeechAnalyzer (actor)        │
   input tap         │                                           │
      │  AVAudioPCMBuffer (hw fmt, e.g. 48kHz)                    │
      ▼                                                           │
 AVAudioConverter ──► AnalyzerInput ──► AsyncStream<AnalyzerInput>│──► [ SpeechTranscriber ]
 (to bestAvailable-   (Sendable)         (you build & yield)      │            │
  AudioFormat)                                                    │            ▼
                                                                  │     transcriber.results
                                                                  │     (AsyncSequence<Result, Error>)
      AssetInventory ──► AssetInstallationRequest.downloadAndInstall()          │
      (system-managed, shared model assets)                       │             ▼
                                                                  │   volatile / final AttributedString
                                                                  └──────────────────────────────────────────┘
```

The analyzer coordinates a **shared CMTime timeline** so that audio, results (`result.range: CMTimeRange`), and control operations (`finalize(through:)`) all correlate against the same clock [1][4].

---

## 3. Requirements & device/OS gating

### 3.1 Platform availability

The entire new stack (`SpeechAnalyzer`, `SpeechTranscriber`, `DictationTranscriber`, `SpeechDetector`, `AnalyzerInput`, `AssetInventory`) is **iOS 26.0+, iPadOS 26.0+, Mac Catalyst 26.0+, macOS 26.0+, tvOS 26.0+, visionOS 26.0+** [1][4]. **watchOS is unsupported** on any version — fall back to system dictation (`TextFieldLink`) there [4][39]. `DictationTranscriber`'s docs omit tvOS, so check availability per module [3].

There is **no back-deployment**: below iOS 26 the API does not exist. Gate with `if #available(iOS 26.0, *)` and keep a legacy engine as the floor [4][37].

### 3.2 The hardware gate (Neural Engine)

`SpeechTranscriber.isAvailable` *"indicates whether this module is available given the device's hardware and capabilities"* [14]. Reverse-engineered by developers (Apple does **not** document the hardware requirement) [26][27]:

- **`isAvailable == false`** on A13 / 8-core-Neural-Engine devices that can still run iOS 26: iPhone 11 / 11 Pro / 11 Pro Max, iPhone SE 2nd gen, and A12/A13 iPads (iPad 8th/9th gen, iPad Air 3, iPad mini 5) [27].
- **`isAvailable == true`** on iPhone 12 (A14) and later, iPhone SE 3rd gen, M1+ Macs [27].
- **`isAvailable == false` in the Simulator** (no ANE emulation, through Xcode 26.1) — device code silently disables in the Simulator [26][39].

> ⚠️ "Runs iOS 26 ⇒ SpeechTranscriber works" is **wrong**. Always probe `isAvailable` at runtime.

On unsupported devices, `SpeechTranscriber.supportedLocales` returns an **empty array**, not nil and without throwing [13]. An empty result is itself the "unsupported" signal — easy to misread as "no languages downloaded yet."

### 3.3 isAvailable-first design

The safe order of checks before doing any work:

```swift
// 1. Microphone permission (see §9.5)
guard await AVAudioApplication.requestRecordPermission() else { return .denied }

// 2. Hardware/OS gate for the preferred engine
guard SpeechTranscriber.isAvailable else {
    return .fallbackToDictation   // A13, Simulator, or unsupported hardware
}

// 3. Locale resolution (see §6)
guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: .current) else {
    return .fallbackToDictation   // language not supported by this module
}

// 4. Asset install state (see §7)
// 5. Best audio format (see §8)
```

`DictationTranscriber` has **no `isAvailable`** — gate it only on `supportedLocales` / `installedLocales` / `supportedLocale(equivalentTo:)` [3][27].

---

## 4. Core API reference

> Availability for every symbol below: iOS 26.0+ (and the platform family in §3.1) unless noted. Beta/Deprecated members are flagged.

### 4.1 SpeechAnalyzer

```swift
final actor SpeechAnalyzer   // Conforms to: Actor, Sendable, SendableMetatype  [1]

// Creating
convenience init(modules: [any SpeechModule], options: SpeechAnalyzer.Options? = nil)  // non-throwing, non-async
convenience init<InputSequence>(inputSequence: InputSequence,
                                modules: [any SpeechModule],
                                options: SpeechAnalyzer.Options?,
                                analysisContext: AnalysisContext,
                                volatileRangeChangedHandler: sending ((CMTimeRange, Bool, Bool) -> Void)?)
convenience init(inputAudioFile: AVAudioFile,
                 modules: [any SpeechModule],
                 options: SpeechAnalyzer.Options?,
                 analysisContext: AnalysisContext,
                 finishAfterFile: Bool,
                 volatileRangeChangedHandler: sending ((CMTimeRange, Bool, Bool) -> Void)?) async throws

// Modules
func setModules(_ modules: [any SpeechModule]) async throws
var modules: [any SpeechModule] { get }

// Driven analysis (returns when the input/file is consumed)
func analyzeSequence<InputSequence>(_ inputSequence: InputSequence) async throws -> CMTime?
    where InputSequence: Sendable, InputSequence: AsyncSequence, InputSequence.Element == AnalyzerInput
func analyzeSequence(from audioFile: AVAudioFile) async throws -> CMTime?

// Autonomous analysis (returns immediately)
func start<InputSequence>(inputSequence: InputSequence) async throws
    where InputSequence: Sendable, InputSequence: AsyncSequence, InputSequence.Element == AnalyzerInput
func start(inputAudioFile audioFile: AVAudioFile, finishAfterFile: Bool = false) async throws

// Finalizing / finishing
func finalize(through: CMTime?) async throws
func finalizeAndFinish(through: CMTime) async throws
func finalizeAndFinishThroughEndOfInput() async throws
func finish(after: CMTime) async throws
func cancelAnalysis(before: CMTime)
func cancelAndFinishNow() async     // no throws

// Formats & warmup (static/instance)
static func bestAvailableAudioFormat(compatibleWith: [any SpeechModule]) async -> AVAudioFormat?
static func bestAvailableAudioFormat(compatibleWith: [any SpeechModule], considering: AVAudioFormat?) async -> AVAudioFormat?
func prepareToAnalyze(in: AVAudioFormat?) async throws
func prepareToAnalyze(in: AVAudioFormat?, withProgressReadyHandler: sending ((Progress) -> Void)?) async throws

// Volatile range & context
var volatileRange: CMTimeRange? { get }
func setVolatileRangeChangedHandler(_ handler: sending ((CMTimeRange, Bool, Bool) -> Void)?)
func setContext(_ context: AnalysisContext) async throws
var context: AnalysisContext { get }
```

All quoted from Apple's docs JSON [1][4]. Note the **basic `init(modules:options:)` is non-throwing and non-async** — several blog posts incorrectly write `try SpeechAnalyzer(...)`; only the `inputSequence:`/`inputAudioFile:` convenience inits are `async throws` [39].

`SpeechAnalyzer.Options` [22]:

```swift
struct SpeechAnalyzer.Options: Equatable, Sendable {
    init(priority: TaskPriority, modelRetention: SpeechAnalyzer.Options.ModelRetention)
    init(priority: TaskPriority, modelRetention: ModelRetention, ignoresResourceLimits: Bool)  // Beta
    let priority: TaskPriority
    let modelRetention: ModelRetention           // nested enum: model caching strategy (see §7.6)
    let ignoresResourceLimits: Bool              // Beta — overrides the system cap on simultaneous analyses; see §7.6
}
```

### 4.2 SpeechTranscriber

```swift
final class SpeechTranscriber   // Conforms to: LocaleDependentSpeechModule, SpeechModule, Sendable  [2]

convenience init(locale: Locale, preset: SpeechTranscriber.Preset)
convenience init(locale: Locale,
                 transcriptionOptions: Set<SpeechTranscriber.TranscriptionOption>,
                 reportingOptions: Set<SpeechTranscriber.ReportingOption>,
                 attributeOptions: Set<SpeechTranscriber.ResultAttributeOption>)

final var results: some Sendable & AsyncSequence<SpeechTranscriber.Result, any Error> { get }
// Accessing `results` does NOT create a new sequence — iterate the single shared stream once.  [2]

static var isAvailable: Bool { get }
static var installedLocales: [Locale] { get async }         // async — await it
static var supportedLocales: [Locale] { get async }         // async; empty on unsupported devices
static func supportedLocale(equivalentTo: Locale) async -> Locale?
```

> ⚠️ All three of `installedLocales`, `supportedLocales`, and `supportedLocale(equivalentTo:)` are **async** and must be `await`ed. An earlier draft of this guide (and some blog posts) claimed `installedLocales` was synchronous — that is wrong; Apple declares it `static var installedLocales: [Locale] { get async }`, and code that reads it without `await` will not compile [2][3].

### 4.3 Preset and options

```swift
struct SpeechTranscriber.Preset: Equatable, Hashable, Sendable {
    init(transcriptionOptions: Set<TranscriptionOption>,
         reportingOptions: Set<ReportingOption>,
         attributeOptions: Set<ResultAttributeOption>)
    var transcriptionOptions: Set<TranscriptionOption>
    var reportingOptions: Set<ReportingOption>
    var attributeOptions: Set<ResultAttributeOption>

    // The FIVE shipping presets [7]:
    static let transcription                              // basic, accurate finalized
    static let transcriptionWithAlternatives             // + editing suggestions
    static let timeIndexedTranscriptionWithAlternatives  // + audio time codes
    static let progressiveTranscription                  // live: volatile + fast
    static let timeIndexedProgressiveTranscription       // live + audio time codes
}

enum SpeechTranscriber.TranscriptionOption: CaseIterable, Sendable {
    case etiquetteReplacements   // replaces certain words/phrases with a redacted form  [11]
}

enum SpeechTranscriber.ReportingOption: CaseIterable, Sendable {
    case volatileResults          // tentative results for a range, in addition to finalized  [9]
    case alternativeTranscriptions
    case fastResults              // biases toward responsiveness; faster, less accurate
}

enum SpeechTranscriber.ResultAttributeOption: CaseIterable, Sendable {
    case audioTimeRange           // adds CMTimeRange run-attributes to the AttributedString  [10]
    case transcriptionConfidence  // adds confidence (Double 0...1) run-attributes
}
```

> ⚠️ **Preset name trap.** The shipping names are exactly those five. Do **not** assume `liveCaptioning`, `offlineTranscription`, `progressiveLiveTranscription`, or `progressiveLongDictation` — the WWDC video and early betas used `.offlineTranscription` / `.progressiveLiveTranscription`, which were renamed before GM. Use `.transcription` for offline/file work and `.progressiveTranscription` for live [7][25]. `progressive*` presets are the live/streaming ones; `timeIndexed*` presets add audio-time-range attributes.

### 4.4 Results — volatile vs final, timing, confidence, alternatives

```swift
struct SpeechTranscriber.Result: SpeechModuleResult, Sendable, Equatable, Hashable, CustomStringConvertible {  [8]
    var text: AttributedString          // most likely interpretation for this range
    let alternatives: [AttributedString]// descending likelihood (needs .alternativeTranscriptions)
    // Inherited from SpeechModuleResult:
    var isFinal: Bool                   // whether final at production time
    var range: CMTimeRange             // audio input range this result applies to
    var resultsFinalizationTime: CMTime// audio time up to which (exclusive) results are finalized
}
```

- **Volatile vs final.** With `.volatileResults` (or a `progressive*` preset), each phrase is emitted one or more times as the guess improves until `isFinal == true`. Without it, you receive only finalized results that never replace earlier ones [8][9][25].
- **The volatile range.** `SpeechAnalyzer.volatileRange: CMTimeRange?` is the range of results that can still change; anything **outside** it is stable and safe to consolidate. It is nil if no input has been received [1]. Observe changes via `setVolatileRangeChangedHandler(_:)`.
- **Timing & confidence** live as **run attributes inside `result.text`**, only when you opt into `.audioTimeRange` / `.transcriptionConfidence`. A plain `String(result.text.characters)` conversion drops them [8][20].

```swift
// Reading per-run attributes  [10][20]
for run in result.text.runs {
    // Documented convenience accessors on AttributedString.Runs runs:
    let timeRange  = run.audioTimeRange          // CMTimeRange?  (attribute id "audioTimeRange")
    let confidence = run.transcriptionConfidence // confidence when .transcriptionConfidence was requested

    // Equivalent scoped-key form (either works):
    // let tr = run[AttributeScopes.SpeechAttributes.TimeRangeAttribute.self]    // CMTimeRange?
    // let cf = run[AttributeScopes.SpeechAttributes.ConfidenceAttribute.self]
}
```

The run-attribute names (`audioTimeRange`, `transcriptionConfidence`) and their backing attribute types (`TimeRangeAttribute` → `CMTimeRange`, `ConfidenceAttribute`) are documented in `AttributeScopes.SpeechAttributes` [20].

### 4.5 The analysis lifecycle

**Driven (file or finite sequence):** `analyzeSequence(_:)` / `analyzeSequence(from:)` **block until the input is consumed** and return the last-consumed `CMTime?`. The *tail may still be processing*, so you must finalize afterward or you drop the end of the audio [1][12].

```swift
let last = try await analyzer.analyzeSequence(from: audioFile)   // returns when file consumed
if let last { try await analyzer.finalizeAndFinish(through: last) }
else        { await analyzer.cancelAndFinishNow() }
```

**Autonomous (live mic):** `start(inputSequence:)` / `start(inputAudioFile:finishAfterFile:)` return immediately; analysis proceeds in the background while you consume results in a separate task. On stop: finish the input stream, then `finalizeAndFinishThroughEndOfInput()` [1][4].

> ⚠️ `finalize(through:)` with a **specific** `CMTime` **waits** until the analyzer has consumed that audio — pass a time beyond what will ever be consumed and you hang. Pass `nil` to finalize only through already-consumed audio [1]. `cancelAndFinishNow()` is `async` (no throws) and discards pending work (volatile results are lost); the other finish methods are `async throws` [1].

### 4.6 SpeechDetector (voice-activity detection)

`SpeechDetector` is a low-cost module that reports whether **speech is present** in the audio, independent of transcription. Added to the same analyzer alongside a transcriber, it lets the system suppress transcription work during silence — a real battery/power optimization for long-form or always-listening capture (the exact case a journaling app hits during pauses) [42].

```swift
final class SpeechDetector   // Conforms to: SpeechModule, Sendable  [42]

convenience init(detectionOptions: SpeechDetector.DetectionOptions, reportResults: Bool)
final var results: some Sendable & AsyncSequence<SpeechDetector.Result, any Error> { get }

struct SpeechDetector.DetectionOptions {   // shape per docs; verify against your SDK
    init(sensitivityLevel: SpeechDetector.SensitivityLevel)
}
enum SpeechDetector.SensitivityLevel { case low, medium, high }   // Apple recommends .medium
```

Wire it into the **same** `SpeechAnalyzer` as the transcriber. Set `reportResults: false` when you only want it to gate transcription internally (you don't need the raw VAD events); set `true` to also consume `detector.results` yourself (e.g. to drive a "listening…" UI):

```swift
let detector    = SpeechDetector(detectionOptions: .init(sensitivityLevel: .medium),
                                 reportResults: false)
let transcriber = SpeechTranscriber(locale: locale, preset: .progressiveTranscription)
let analyzer    = SpeechAnalyzer(modules: [detector, transcriber])
// feed audio once; the detector gates the transcriber, saving power during silence.
```

> Exact `DetectionOptions` / `Result` member shapes were not individually re-verified against the SDK for this guide — confirm in Xcode before depending on specific fields [42].

### 4.7 AnalysisContext & custom vocabulary

`AnalysisContext` is how you bias recognition toward domain terms — the on-device analogue of `SFSpeechRecognizer.contextualStrings`. You set it on the analyzer with `setContext(_:)` (or pass it to the context-taking convenience inits) [29][1].

```swift
final class AnalysisContext: Sendable {   // shape per docs; verify against your SDK  [29]
    var contextualStrings: [AnalysisContext.ContextualStringsTag: [String]]  // strings grouped by tag
    var userData:          [AnalysisContext.UserDataTag: any Sendable]
}

let context = AnalysisContext()
context.contextualStrings = [ .general: ["Anthropic", "SwiftUI", "SpeechAnalyzer"] ]  // domain/brand terms; tag names per SDK
try await analyzer.setContext(context)
```

This is the actual lever developers have for proper nouns / brand terms. It helps, but for `SpeechTranscriber` its long-form biasing was still limited at launch relative to what `SFSpeechRecognizer.contextualStrings` gave for short utterances — proper nouns can still mis-split (see §11, §12.3) [4][29][35].

---

## 5. DictationTranscriber & the fallback ladder

### 5.1 What it is

```swift
final class DictationTranscriber   // Conforms to: LocaleDependentSpeechModule, SpeechModule, Sendable  [3]

convenience init(locale: Locale, preset: DictationTranscriber.Preset)
convenience init(locale: Locale,
                 contentHints: Set<DictationTranscriber.ContentHint>,   // NOT on SpeechTranscriber
                 transcriptionOptions: Set<DictationTranscriber.TranscriptionOption>,
                 reportingOptions: Set<DictationTranscriber.ReportingOption>,
                 attributeOptions: Set<DictationTranscriber.ResultAttributeOption>)

final var results: some Sendable & AsyncSequence<DictationTranscriber.Result, any Error> { get }
static var installedLocales: [Locale] { get async }
static var supportedLocales: [Locale] { get async }
static func supportedLocale(equivalentTo: Locale) async -> Locale?
// NO isAvailable — the /dictationtranscriber/isavailable doc page 404s.  [3][27]
```

Apple: it *"uses the same speech-to-text machine learning models as system dictation features do, or as `SFSpeechRecognizer` does when it is configured for on-device operation… does not support languages that `SFSpeechRecognizer` only supports via network."* It is the **compatibility** option, not the quality option [3]. Its improvement over `SFSpeechRecognizer`: users do **not** need to enable Siri or keyboard dictation for a language [25].

Presets (shipping): `.phrase`, `.shortDictation`, `.progressiveShortDictation`, `.longDictation`, `.progressiveLongDictation`, `.timeIndexedLongDictation` [3]. Content hints: `.farField`, `.shortForm`, `.atypicalSpeech`, `.customizedLanguage(modelConfiguration:)` [3].

### 5.2 Differences that drive the decision

- `DictationTranscriber` has **no hardware gate** (`isAvailable`) — it runs everywhere on-device `SFSpeechRecognizer` did [3][27].
- Its **locale reach is broader** than `SpeechTranscriber`'s — a reason to fall back to it for an unsupported language even on capable hardware [4].
- It uniquely accepts **`contentHints`** for accuracy tuning (far-field, custom language model) [3].

### 5.3 Runtime selection logic

```swift
enum TranscriptionError: Error { case localeNotSupported }

func makeTranscriber(locale: Locale) async throws -> any SpeechModule {
    // Prefer the high-quality engine: hardware gate + supported locale.
    if SpeechTranscriber.isAvailable,
       let resolved = await SpeechTranscriber.supportedLocale(equivalentTo: locale) {
        return SpeechTranscriber(locale: resolved, preset: .progressiveTranscription)
    }
    // A13 / 8-core ANE, Simulator, or unsupported language → compatibility engine.
    if let resolved = await DictationTranscriber.supportedLocale(equivalentTo: locale) {
        return DictationTranscriber(locale: resolved, preset: .progressiveLongDictation)
    }
    throw TranscriptionError.localeNotSupported
}
```

The **full ladder** (see §13c): `SpeechTranscriber` → `DictationTranscriber` → (below iOS 26 / watchOS) `SFSpeechRecognizer` with `requiresOnDeviceRecognition = true`, or a bundled Whisper floor [4][37].

---

## 6. Locale handling

### 6.1 The three lists

- `supportedLocales` — supported **plus downloadable** locales (async; empty on unsupported devices) [13].
- `installedLocales` — only locales whose assets are already on device (async) [2].
- `supportedLocale(equivalentTo:)` — resolves an arbitrary locale to a supported one (async, optional) [12].

### 6.2 The `contains(.current)` trap

`supportedLocales.contains(Locale.current)` almost always returns **false** even for supported languages: `Locale.current` carries region/script/calendar/measurement/extension components that break `Locale` value-equality against the canonical bare entries [12][4]. Two correct approaches:

```swift
// (a) Normalize both sides to BCP-47 (Apple's WWDC sample does exactly this)  [25]
func supported(_ locale: Locale) async -> Bool {
    let supported = await SpeechTranscriber.supportedLocales
    return supported.map { $0.identifier(.bcp47) }.contains(locale.identifier(.bcp47))
}
func installed(_ locale: Locale) async -> Bool {
    let installed = await SpeechTranscriber.installedLocales
    return Set(installed.map { $0.identifier(.bcp47) }).contains(locale.identifier(.bcp47))
}

// (b) Ask the framework to resolve it
if let resolved = await SpeechTranscriber.supportedLocale(equivalentTo: .current) { /* use resolved */ }
```

### 6.3 Choosing a locale

`supportedLocale(equivalentTo:)` may return a **same-language, different-region near-equivalent** (e.g. `en_GB` vs `en_US`), which *"may result in an unexpected transcription, such as between 'color' and 'colour'"* [12]. Apple advises still letting users pick explicitly from `supportedLocales`. **Query `supportedLocales` at runtime** — the set is device- and OS-version-dependent (community dumps show ~10–40+, but Apple publishes no fixed count) [4][13]. One `SpeechTranscriber` instance = **one locale**; there is no mid-stream language switching [4].

---

## 7. Model asset lifecycle

### 7.1 AssetInventory & AssetInstallationRequest

```swift
final class AssetInventory   // all members static; never instantiated  [5]

static func assetInstallationRequest(supporting: [any SpeechModule]) async throws -> AssetInstallationRequest?
static func status(forModules: [any SpeechModule]) async -> AssetInventory.Status
@discardableResult static func reserve(locale: Locale) async throws -> Bool
@discardableResult static func release(reservedLocale: Locale) async -> Bool   // async, NOT throwing
static var reservedLocales: [Locale] { get }
static var maximumReservedLocales: Int { get }   // device-dependent; varies with storage

enum AssetInventory.Status: Comparable, Equatable, Hashable {  [18]
    case unsupported   // module won't work with its config
    case supported     // works, but assets must be downloaded
    case downloading   // downloading OR waiting for conditions to improve
    case installed     // ready
}

@objc final class AssetInstallationRequest: NSObject, ProgressReporting, Sendable {  [6]
    func downloadAndInstall() async throws
    var progress: Progress { get }   // Foundation Progress, from ProgressReporting
}
```

### 7.2 The documented flow

1. Create modules in the configurations you want.
2. `reserve(locale:)` the locales for `LocaleDependentSpeechModule`s (keeps their assets from being reclaimed) [5].
3. `assetInstallationRequest(supporting:)` → if non-nil, `downloadAndInstall()`.
4. Await completion (may return immediately if already installed) [5].

```swift
func ensureModel(for module: SpeechTranscriber, locale: Locale) async throws {
    guard await supported(locale) else { throw TranscriptionError.localeNotSupported }
    if await installed(locale) { return }
    if let request = try await AssetInventory.assetInstallationRequest(supporting: [module]) {
        self.downloadProgress = request.progress   // capture BEFORE awaiting, bind to UI
        try await request.downloadAndInstall()
    }
    // nil ⇒ status was already .installed; nothing to do (this is success, not an error)
}
```

### 7.3 Reservation, storage, uninstall

- `assetInstallationRequest(supporting:)` **auto-reserves** required-but-unreserved locales; if that would exceed `maximumReservedLocales` it **throws** [5].
- `reserve(locale:)` returns **false** if already reserved; **throws** if over the cap or no asset supports the locale [5].
- `release(reservedLocale:)` **does not throw**; returns false if not reserved. It *"unsubscribes from any assets that depended on the locale"* but does **not** guarantee immediate disk reclamation [5].
- There is **no per-app "delete asset" API** — you relinquish by releasing the reservation; the system reclaims disk from assets no app reserves, on its own schedule [5].
- `maximumReservedLocales` is **not** a fixed constant — read it at runtime [5][19].

### 7.4 Storage

Models live in **system storage**, are **shared across apps**, add **zero** to your app's size/memory, and auto-update [5][25]. Because they are shared and reclaimable, **another app or an OS reclaim can change what's installed between your launches** — re-check `status(forModules:)` / `installedLocales` each session; don't cache `installed = true` [5]. `.downloading` covers both active transfer **and** "waiting for conditions to improve," so a download can legitimately stall without erroring [18].

> ⚠️ **Naming trap.** The WWDC25 sample used `allocate` / `allocatedLocales` / `deallocate` / `maximumAllocatedLocales`. These were renamed before GM to `reserve` / `reservedLocales` / `release` / `maximumReservedLocales`. Copying the talk verbatim will not compile [5][25].

### 7.5 Error taxonomy

Errors from the framework are **typed** — `SFSpeechError` is a documented struct wrapping `SFSpeechError.Code`, an enum with (among others) [41]:

| Case | Meaning |
|---|---|
| `.timeout` | operation timed out |
| `.insufficientResources` | too many concurrent analyses (see §7.6) |
| `.audioReadFailed` | failed to read the input audio |
| `.internalServiceError` | internal framework failure |
| `.malformedSupplementalModel` | a supplied custom/supplemental model file is malformed |
| `.missingParameter` | a required parameter was absent |
| `.undefinedTemplateClassName` | a referenced template class name isn't defined |

Handle these explicitly around `downloadAndInstall()`, `reserve`, `start*`/`analyzeSequence*`, and while iterating `results`:

```swift
do {
    try await request.downloadAndInstall()
} catch let error as SFSpeechError {
    switch error.code {
    case .timeout:                await retryLater()
    case .insufficientResources:  await backOffOtherMLWork()
    default:                      surface(error)   // out-of-space/network still arrive here as thrown errors
    }
} catch {
    surface(error)  // non-SFSpeechError (e.g. URLError-style transport) — treat as a generic download failure
}
```

Apple's docs do **not** enumerate a dedicated "no network" / "out of space" case; those surface as thrown errors (often not `SFSpeechError`), so keep a `catch`-all after the typed switch [5][41].

**Finished-session propagation contract.** When a result stream throws, the **session becomes finished**: the same error (or a `CancellationError`) is then thrown from *all* waiting methods and result streams on that analyzer. You cannot resume it — recovery means constructing a **new** `SpeechAnalyzer` [1] (tied to teardown in §9.6).

### 7.6 Memory model, model retention & resource limits

Retention and memory are **documented**, not open questions:

- **Lazy load / unload.** The analyzer and its modules load system resources lazily on first use and unload them when deallocated [1].
- **`SpeechAnalyzer.Options.ModelRetention`** controls how aggressively loaded models are kept between sessions [22][43]:
  - `.whileInUse` — release as soon as the analyzer is done (lowest memory, highest re-warm cost).
  - `.lingering` — keep briefly after use so a follow-on session is fast.
  - `.processLifetime` — keep for the life of the process (lowest latency, highest memory).
- **`prepareToAnalyze(in:)`** preheats models/format state ahead of the first buffer to cut cold-start latency — pair it with a retention policy that keeps them warm [1].
- **`SpeechModels.endRetention() async`** frees **in-memory** models held by cached recognizers — a manual counterpart to retention, separate from disk/asset management [40].
- **Concurrency cap (`insufficientResources`).** The system limits how many analyses run at once; exceeding it throws `SFSpeechError.Code.insufficientResources` [1][41]. `Options.ignoresResourceLimits = true` (Beta) removes the cap, but Apple warns that when the real limit is exceeded **"one or more of the analyzers will fail, throwing an unpredictable error."** For an app that may run transcription alongside other on-device ML (e.g. a separate on-device LLM/ML inference pass), treat `insufficientResources` as expected back-pressure — serialize or back off rather than setting `ignoresResourceLimits` [1][22].

---

## 8. Audio pipeline

### 8.1 The mandatory conversion

**The single most important fact:** the analyzer *"does not transparently upsample, downsample, or convert audio input"* (to keep `CMTime` sample-accurate). You must convert every mic buffer to the analyzer's format yourself with `AVAudioConverter`. Feeding the raw hardware buffer (often 48 kHz) **compiles, runs, throws no error, and produces zero transcription** — the #1 silent failure [4][23].

Get the target format **after** the model is installed (it returns nil until then):

```swift
let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])  // AVAudioFormat?
```

### 8.2 The pipeline shape

```
mic → AVAudioEngine.installTap(onBus:0, bufferSize:4096, format: hardwareFormat)
    → BufferConverter.convert(buffer, to: analyzerFormat)
    → AnalyzerInput(buffer:) → inputBuilder.yield(_)
    → analyzer.start(inputSequence:)          ┐ separate task
    → for try await result in transcriber.results  ┘
```

Install the tap with the **native input format** `inputNode.outputFormat(forBus: 0)`; never assume 16 kHz mono at the tap [23][38].

### 8.3 The converter (Apple's sample, copy verbatim)

```swift
final class BufferConverter {
    enum Error: Swift.Error { case failedToCreateConverter, failedToCreateConversionBuffer, conversionFailed(NSError?) }
    private var converter: AVAudioConverter?

    func convertBuffer(_ buffer: AVAudioPCMBuffer, to format: AVAudioFormat) throws -> AVAudioPCMBuffer {
        let inputFormat = buffer.format
        guard inputFormat != format else { return buffer }          // short-circuit if already matching
        if converter == nil || converter?.outputFormat != format {
            converter = AVAudioConverter(from: inputFormat, to: format)
            converter?.primeMethod = .none   // avoid first-sample timestamp drift vs the source clock
        }
        guard let converter else { throw Error.failedToCreateConverter }
        let ratio = converter.outputFormat.sampleRate / converter.inputFormat.sampleRate
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up))
        guard let out = AVAudioPCMBuffer(pcmFormat: converter.outputFormat, frameCapacity: capacity) else {
            throw Error.failedToCreateConversionBuffer
        }
        var nsError: NSError?
        var processed = false
        let status = converter.convert(to: out, error: &nsError) { _, inputStatus in
            defer { processed = true }        // input block is called MULTIPLE times; only one buffer to give
            inputStatus.pointee = processed ? .noDataNow : .haveData
            return processed ? nil : buffer
        }
        guard status != .error else { throw Error.conversionFailed(nsError) }
        return out
    }
}
```

Reuse one converter across buffers; `installTap`'s `bufferSize` (4096) is a **hint** — the delivered `frameLength` varies, so recompute output capacity per buffer [4][24].

### 8.4 Feeding the input stream

```swift
let (inputSequence, inputBuilder) = AsyncStream<AnalyzerInput>.makeStream()
try await analyzer.start(inputSequence: inputSequence)
// per captured/converted buffer:
inputBuilder.yield(AnalyzerInput(buffer: convertedBuffer))
```

`AnalyzerInput` [15]:

```swift
struct AnalyzerInput: Sendable {
    init(buffer: AVAudioPCMBuffer)
    init(buffer: AVAudioPCMBuffer, bufferStartTime: CMTime?)   // for audio discontiguous with previous input
    init(buffer: CMReadySampleBuffer<CMReadOnlyDataBlockBuffer>)   // Beta
    let bufferStartTime: CMTime?
    let bufferDuration: CMTime      // Beta
    let bufferFormat: AVAudioFormat // Beta
    var buffer: AVAudioPCMBuffer    // DEPRECATED — prefer CM-based accessors
}
```

`AnalyzerInput` **is** Sendable but `AVAudioPCMBuffer` is **not** — construct the `AnalyzerInput` at the tap site and yield it immediately; never stash raw buffers to cross the actor boundary later [4].

### 8.5 File transcription (offline)

Much shorter — no engine, tap, or manual conversion:

```swift
let transcriber = SpeechTranscriber(locale: locale, preset: .transcription)   // NOT .offlineTranscription
if let req = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
    try await req.downloadAndInstall()
}
let analyzer = SpeechAnalyzer(modules: [transcriber])
async let collected = transcriber.results.reduce(into: AttributedString("")) { $0 += $1.text }
let file = try AVAudioFile(forReading: url)
if let last = try await analyzer.analyzeSequence(from: file) {
    try await analyzer.finalizeAndFinish(through: last)
} else {
    await analyzer.cancelAndFinishNow()
}
return try await collected
```

### 8.6 AVAudioSession, interruptions, route changes (iOS)

```swift
#if os(iOS)
let session = AVAudioSession.sharedInstance()
try session.setCategory(.playAndRecord, mode: .spokenAudio)          // Apple sample
// or, tuned for cleanest ASR capture:
// try session.setCategory(.record, mode: .measurement, options: .duckOthers)
try session.setActive(true, options: .notifyOthersOnDeactivation)
#endif
```

Use `.record` if you only capture, `.playAndRecord` if you also play back; `.measurement` gives the flattest signal chain for ASR, `.spokenAudio` applies system speech tuning/ducking [23][38]. Observe interruptions and route changes — a tap can go **silent after a route change with no error thrown**, and the session may deactivate on interruption [31][32][23]:

```swift
for await note in NotificationCenter.default.notifications(
        named: AVAudioSession.interruptionNotification,
        object: AVAudioSession.sharedInstance()) {
    guard let info = note.userInfo,
          let raw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
          let type = AVAudioSession.InterruptionType(rawValue: raw) else { continue }
    switch type {
    case .began: /* stop engine, update UI */ break
    case .ended:
        if let optRaw = info[AVAudioSessionInterruptionOptionKey] as? UInt,
           AVAudioSession.InterruptionOptions(rawValue: optRaw).contains(.shouldResume) {
            /* reactivate session, restart engine */
        }
    default: break
    }
}
```

For route changes, key off `AVAudioSessionRouteChangeReasonKey` (`.newDeviceAvailable`, `.oldDeviceUnavailable`, …) [32].

### 8.7 Background execution & lock-screen behavior (verify on device)

Apple's documentation is thin here, so treat the following as **on-device-verify**, not settled fact:

- **Foreground is the safe path.** Live transcription during an active, foregrounded session is what the sample demonstrates [23].
- **To keep capturing while backgrounded or with the screen locked**, the app needs the **`UIBackgroundModes` → `audio`** capability (the same entitlement any long-form recorder needs); without it, `AVAudioEngine` capture is suspended when the app leaves the foreground. Whether the *analyzer* continues consuming buffered input in the background has not been independently verified — assume you must keep the audio session active and the engine running, and test a long lock-screen recording end-to-end [23][31].
- **Interruptions during long sessions** (a phone call, Siri, another app grabbing the mic) deactivate the session; use §8.6's interruption handler to stop and, on `.shouldResume`, restart the engine and — because the prior analyzer is likely finished after an error — build a **new** `SpeechAnalyzer` (§7.5, §9.6).
- **On a route change** (AirPods connect/disconnect), re-query `bestAvailableAudioFormat` is not required, but re-install the tap with the new input format.

For a journaling app that records multi-minute entries, budget explicit device QA for: screen-lock mid-recording, incoming call mid-recording, and AirPods connect mid-recording.

---

## 9. SwiftUI + Swift Concurrency architecture

### 9.1 Split by concurrency domain

Keep three concerns separate, as Apple designed [1][4]:

- A **`@MainActor @Observable`** model owns UI-facing state (finalized text, volatile text, status, download progress).
- **`SpeechAnalyzer`** is already an `actor` — **do not wrap it in `@MainActor`**; that serializes speech work onto the UI thread and was a documented cause of ~14 s first-result latency in Apple's own sample under "approachable concurrency" [28][1].
- **`SpeechTranscriber`** is `Sendable` — shareable across tasks.

### 9.2 The @Observable service

```swift
import Speech
import AVFoundation

@MainActor @Observable
final class LiveTranscriber {
    enum Status: Equatable { case idle, preparing, downloading(Double), recording, unavailable, denied }
    private(set) var status: Status = .idle
    private(set) var finalizedText = AttributedString("")
    private(set) var volatileText  = AttributedString("")
    var displayText: AttributedString { finalizedText + volatileText }

    private let engine = AVAudioEngine()
    private let converter = BufferConverter()
    private var analyzer: SpeechAnalyzer?
    private var transcriber: SpeechTranscriber?
    private var inputBuilder: AsyncStream<AnalyzerInput>.Continuation?
    private var recognizerTask: Task<Void, Never>?   // STORED so we can cancel on teardown
    private var analyzerFormat: AVAudioFormat?
}
```

### 9.3 Consuming results live

```swift
recognizerTask = Task { [weak self] in
    guard let self, let transcriber = self.transcriber else { return }
    do {
        for try await result in transcriber.results {   // typed-throws ⇒ `for try await`
            if result.isFinal {
                self.finalizedText += result.text
                self.volatileText = AttributedString("")   // MUST clear, or you duplicate text
            } else {
                self.volatileText = result.text            // tentative: replace, never append
            }
        }
    } catch is CancellationError {
    } catch let error as SFSpeechError {
        self.status = .unavailable   // session is now finished — recover with a NEW analyzer (§7.5)
    } catch { self.status = .unavailable }
}
```

Render `volatileText` dimmed (style the `AttributedString`); persist only `isFinal` text [4][25].

### 9.4 The tap closure

```swift
private func startAudioEngine() throws {
    let input = engine.inputNode
    let micFormat = input.outputFormat(forBus: 0)
    guard let target = analyzerFormat else { return }
    let builder = inputBuilder                     // capture LOCALS only — no self, no @MainActor
    let converter = self.converter

    input.removeTap(onBus: 0)                       // remove any prior tap first
    input.installTap(onBus: 0, bufferSize: 4096, format: micFormat) { buffer, _ in
        // real-time audio thread — touching self here is a data race under Swift 6 strict concurrency
        guard let converted = try? converter.convertBuffer(buffer, to: target) else { return }
        builder?.yield(AnalyzerInput(buffer: converted))
    }
    engine.prepare()
    try engine.start()
}
```

### 9.5 Permissions & Info.plist

`SpeechAnalyzer` is **fully on-device and needs only microphone permission** — `NSMicrophoneUsageDescription` + `AVAudioApplication.requestRecordPermission() async -> Bool`. It does **not** call `SFSpeechRecognizer.requestAuthorization` [4][37][30].

> ⚠️ Add `NSSpeechRecognitionUsageDescription` and the speech-auth call **only** if you also ship a legacy `SFSpeechRecognizer` fallback — otherwise you show a needless second privacy prompt. (Community sources disagree; the on-device API itself has no authorization entry point.) Missing `NSMicrophoneUsageDescription` **hard-crashes** the app on first mic access [4][30].

### 9.6 Cancellation / teardown — in order

```swift
func stop() async {
    engine.inputNode.removeTap(onBus: 0)
    engine.stop()
    inputBuilder?.finish()                                       // 1. no more audio
    try? await analyzer?.finalizeAndFinishThroughEndOfInput()    // 2. drain + finalize pending
    recognizerTask?.cancel(); recognizerTask = nil               // 3. end the results loop
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    status = .idle
}
```

An orphaned `for try await` over `results` keeps the session and audio engine alive — bind teardown to `.onDisappear { Task { await model.stop() } }` [4]. On a stream error the session becomes **finished** and every awaiting method rethrows the same error (or a `CancellationError`); you **cannot resume the same analyzer** — discard it and build a **new** `SpeechAnalyzer` to recover (§7.5) [1][4].

### 9.7 Live-UI / progress / fallback states

```swift
struct TranscribeView: View {
    @State private var model = LiveTranscriber()
    var body: some View {
        VStack {
            switch model.status {
            case .downloading(let p): ProgressView("Downloading language model", value: p)
            case .denied:      ContentUnavailableView("Microphone Off", systemImage: "mic.slash")
            case .unavailable: ContentUnavailableView("Unavailable here", systemImage: "waveform.slash")
            default: ScrollView { Text(model.displayText).textSelection(.enabled) }
            }
            Button(model.status == .recording ? "Stop" : "Record") {
                Task { model.status == .recording ? await model.stop() : await model.start() }
            }
        }
        .onDisappear { Task { await model.stop() } }
    }
}
```

### 9.8 App Store privacy compliance

On-device transcription still has **two declared privacy surfaces**, and both are release gates:

- **Info.plist usage strings** (§9.5): `NSMicrophoneUsageDescription` always; `NSSpeechRecognitionUsageDescription` **only** if a legacy `SFSpeechRecognizer` fallback ships.
- **`PrivacyInfo.xcprivacy` (privacy manifest).** Declare any **required-reason APIs** the app uses; the audio/speech path itself is on-device, but supporting APIs (file timestamps, user defaults, etc.) may trip required-reason rules. Ship the manifest before the build that adds this feature.
- **App Store privacy nutrition label.** Because transcription is on-device, you can truthfully declare **no data collection and no linking** for the speech content itself. You still surface the **microphone** and, if the legacy fallback ships, the **speech-recognition** capability. Adding an `SFSpeechRecognizer` fallback therefore *expands* your declared privacy surface — a reason to keep the fallback narrowly scoped.
- **Sequencing.** Per the project's privacy rule, the published privacy policy, `PrivacyInfo.xcprivacy`, and the nutrition-label change must land **before** the build that introduces the new recognition path is submitted — not after.

---

## 10. Best practices & design principles

- **Pick the input style deliberately.** `analyzeSequence*` blocks until input is consumed (finite files); `start*` returns immediately (live mic + concurrent result consumption) [1].
- **Always finalize after driven analysis** — the tail is still processing when `analyzeSequence` returns; feed its `CMTime` into `finalizeAndFinish(through:)` [1][12].
- **Reconcile by `CMTimeRange`, not by appending blindly.** Use `result.isFinal` + `volatileRange`; consolidate anything outside the volatile range [1][8].
- **Only request the options you use.** `.volatileResults` / `.alternativeTranscriptions` / `.audioTimeRange` / `.transcriptionConfidence` each cost work and change the stream's shape [2][7].
- **Convert audio to `bestAvailableAudioFormat`** — get it once after the model is installed, cache it, reuse one `AVAudioConverter`, set `primeMethod = .none` [4][23].
- **Treat the model as environmental state**, re-checked each launch — gate on `installedLocales`/`supportedLocales`, `reserve` only what you need and `release` when done [5].
- **Tune retention to your usage.** `prepareToAnalyze(in:)` + a `.lingering`/`.processLifetime` `ModelRetention` for a record-often app; `.whileInUse` + `SpeechModels.endRetention()` when memory is tight (§7.6) [1][22][40].
- **Gate transcription on voice activity** with `SpeechDetector` for long/always-listening capture to save power (§4.6) [42].
- **Expect and back off on `insufficientResources`** if you run other on-device ML concurrently, rather than reaching for `ignoresResourceLimits` (§7.6) [1][41].
- **Normalize locales** through `supportedLocale(equivalentTo:)` or BCP-47; never pass `Locale.current` straight in [12].
- **Keep the analyzer off `@MainActor`**; run capture and result consumption as separate tasks; store and cancel the results task on teardown [4][28].
- **Capture `.audioTimeRange` up front** if you might ever sync transcript to playback — retrofitting is painful [25].

---

## 11. Gotchas & pitfalls

- **Silent zero-transcription** from feeding un-converted hardware audio — no error thrown [4][23].
- **iOS 26.0+ only, no back-deployment; not on watchOS** [1][4].
- **`SpeechTranscriber.isAvailable == false`** on A13/8-core-ANE devices and in the Simulator — undocumented hardware gate [14][26][27].
- **`supportedLocales.contains(Locale.current)`** is almost always false — compare BCP-47 or use `supportedLocale(equivalentTo:)` [12].
- **`installedLocales`, `supportedLocales`, and `supportedLocale(equivalentTo:)` are all async** — `await` every one of them (an earlier draft wrongly called `installedLocales` synchronous) [2][3].
- **Empty `supportedLocales`** = unsupported device, not "nothing downloaded yet" [13].
- **Stale preset names** — `.offlineTranscription`, `.progressiveLiveTranscription`, `.progressiveLongDictation` (for `SpeechTranscriber`) don't exist in the shipping SDK [7][25].
- **`AssetInventory` naming** — `reserve`/`release`/`reservedLocales`/`maximumReservedLocales`, not the WWDC `allocate*` names [5][25].
- **`assetInstallationRequest` returns nil = success** (already installed), not failure [5].
- **`init(modules:options:)` is non-throwing/non-async** — don't `try` it [39].
- **Results come from the module** (`transcriber.results`), not the analyzer [4].
- **Ending the input stream does NOT end the session** — you must finalize/finish or the tail never finalizes [4][25].
- **Forgetting to clear volatile on `isFinal`** duplicates text [4][25].
- **`AVAudioConverter` input block is called multiple times** — flip a flag and return `.noDataNow`/nil, or it misbehaves [4].
- **Two taps on one bus throws** — `removeTap(onBus:)` first [23].
- **The tap closure is a real-time thread** — capture locals only, no `self`/`@MainActor` access [4].
- **`AnalyzerInput.buffer` is deprecated**; some members (`bufferDuration`, `bufferFormat`, the `CMReadySampleBuffer` init, `Options.ignoresResourceLimits`) are Beta — pin to the SDK you build with, expect churn [1][15].
- **A thrown result stream finishes the whole session** — the same error propagates to every waiting call; recover only by building a new `SpeechAnalyzer` (§7.5) [1].
- **`insufficientResources` under concurrency** — the system caps simultaneous analyses; don't paper over it with `ignoresResourceLimits` (§7.6) [1][41].
- **Weak custom vocabulary** — `AnalysisContext.contextualStrings` (grouped by tag, set via `setContext(_:)`, §4.7) is the lever you have, but long-form biasing was still limited at launch; proper nouns/brand terms mis-split [4][29][35].
- **No server path** — great for privacy, but no cloud fallback for hard audio [37].
- **Latency landmine** — Swift "approachable concurrency" serializing on the main actor caused ~14 s to first result in Apple's sample; test first-result latency explicitly, mark hot methods `@concurrent` or disable that setting [28].
- **Docs were thin at launch and the framework was missing in early Xcode 26 betas** — verify against the shipping SDK, not memory or blog posts [25][4].

---

## 12. Industry usage & comparison

Apple ships `SpeechAnalyzer` in its own first-party apps — **Notes, Voice Memos, the Journal app, and Call transcription/summarization** [25]. The **Journal** app is a particularly strong precedent for long-form, personal-capture use cases: Apple built that exact experience on this stack.

### 12.1 Comparison table

| Dimension | SpeechAnalyzer / SpeechTranscriber | SFSpeechRecognizer (legacy) | WhisperKit / on-device Whisper |
|---|---|---|---|
| OS floor | iOS 26+ (no watchOS) [1] | iOS 10+ [4] | Your deployment target |
| Model delivery | System-managed, shared, **0 MB** app cost [5] | System | **Bundled/downloaded** (~500 MB small, ~1.6 GB v3-turbo) [33] |
| On-device | Always [1] | Optional (`requiresOnDeviceRecognition`); defaults to server [4] | Always |
| Long-form | Designed for it [1] | Degrades past ~1 min [4] | Strong |
| Languages | ~10–40, device/OS-dependent [4][13] | Broad (on-device subset) [3] | ~99 [33] |
| English WER (LibriSpeech clean) | 2.12% [34] | 9.02% [34] | Small 3.74%, Base 5.42% [34] |
| Harder corpus (earnings22) | 14.0% (speed 70) [33] | — | small.en 12.8% (speed 35) [33] |
| Speed | ~2–3× faster than Whisper Small; 45 s for a 34-min file vs 1m41s MacWhisper Large V3 Turbo [34][35] | — | Baseline |
| Custom vocabulary | Limited (`AnalysisContext.contextualStrings`) [29] | `contextualStrings` | Developer-controlled |
| Permissions | Mic only [37] | Mic + speech-recognition auth [37] | Mic only |
| Timestamps | `.audioTimeRange` run attributes [10] | Segment timestamps | Yes |

### 12.2 Adoption lessons

- **Apple's own apps validate the stack** — Notes/Voice Memos/Journal/Call all run on it, which is the best available evidence of production readiness for long-form dictation [25].
- **Abstract behind a protocol before migrating** so views/services never import `Speech` or `WhisperKit` directly — the engine becomes a swappable, testable dependency [37].
- **Select by availability AND locale at runtime**, not just OS version [4].
- **Migrate long-form/dictation first**; keep custom-vocabulary-critical or rare-language paths on Whisper, which retains value for 99-language coverage and developer-controlled updates [33][36].
- **Validate on real-device betas** — behavior (latency, concurrency) shifted between betas [28][4].

### 12.3 When NOT to use it

- Deployment target below iOS 26 as your **only** engine, or any watchOS need [4].
- Users in the long tail of languages Whisper covers but `SpeechTranscriber`/`DictationTranscriber` do not [4].
- Heavy domain jargon / proper nouns where you need strong custom-vocabulary biasing today — `AnalysisContext.contextualStrings` (§4.7) helps but was limited for long-form at launch [29][35].
- Web/hybrid contexts — Safari's `webkitSpeechRecognition` still uses the old engine; no JS binding [36].
- Where a **cloud fallback** for very hard audio is a hard requirement [37].

### 12.4 Adjacent on-device AI: FoundationModels

WWDC 277 explicitly demonstrates feeding `SpeechAnalyzer` output into the on-device **FoundationModels** API for post-transcription work — generating a title, a summary, or structured signals from the transcript [25][44]. If your app runs a **separate on-device LLM** to post-process transcripts (titling, summarization, structured extraction), this raises a **consolidation question**: FoundationModels could fold transcription + downstream language work into one Apple-managed, 0-MB-download stack.

Tradeoffs to weigh before switching:

- **For FoundationModels:** no bundled/downloaded model, system-managed and auto-updated, tight integration with the same OS floor already required by `SpeechAnalyzer`, less code to own.
- **Against (keep a dedicated LLM):** you lose control over the exact model and prompt behavior; if your extraction is tuned to a specific model and validated against a fixed schema, FoundationModels' structured-output guarantees and quality on *your* schema are unverified; and it raises the same iOS-26 floor for the language-processing path, not just transcription.

Recommendation: surface it as a real option, but **spike it against the existing extraction eval set** before committing — do not swap a tuned pipeline for an untested one on WWDC framing alone.

---

## 13. Generic implementation plan

A phased, app-agnostic plan. It assumes a DI chain where services are injected into SwiftUI via `@Environment` and are protocol-typed (so no view touches a concrete engine).

### 13a. A `TranscriptionService` protocol abstraction

Use associated types for config/results so backends can carry engine-specific detail while callers stay generic.

```swift
import AVFoundation

// Engine-neutral result the app consumes.
struct TranscriptSegment: Sendable, Hashable {
    var text: AttributedString
    var isFinal: Bool
    var range: CMTimeRange?          // nil when the backend can't provide timing
    var confidence: Double?          // 0...1 when available
}

enum TranscriptionCapability: Sendable {
    case unavailable          // no engine can serve this locale/device
    case ready                // ready to record now
    case needsDownload        // supported, model not yet installed
}

protocol TranscriptionService: Sendable {
    associatedtype Config: Sendable
    associatedtype DownloadProgress: Sendable   // e.g. Foundation.Progress or a Double stream

    static var identifier: String { get }        // for logging/telemetry

    func capability(for locale: Locale) async -> TranscriptionCapability
    func ensureModel(for locale: Locale, config: Config) async throws -> DownloadProgress?

    /// Live streaming: caller feeds converted audio; service emits segments.
    func liveSession(locale: Locale, config: Config) async throws -> LiveTranscriptionSession

    /// Finite file transcription.
    func transcribe(file: URL, locale: Locale, config: Config) async throws -> AttributedString
}

// A live session decouples audio-in from results-out.
protocol LiveTranscriptionSession: Sendable {
    var segments: AsyncThrowingStream<TranscriptSegment, Error> { get }
    func feed(_ buffer: AVAudioPCMBuffer) async          // service converts internally
    func finish() async throws                            // drain + finalize
    func cancel() async                                   // abort, discard pending
}
```

### 13b. Concrete backends

**`SpeechTranscriberService`** wraps `SpeechAnalyzer` + `SpeechTranscriber`:

```swift
struct SpeechTranscriberService: TranscriptionService {
    struct Config: Sendable { var preset: SpeechTranscriber.Preset = .progressiveTranscription }
    typealias DownloadProgress = Progress
    static let identifier = "apple.speechtranscriber"

    func capability(for locale: Locale) async -> TranscriptionCapability {
        guard SpeechTranscriber.isAvailable else { return .unavailable }
        guard let resolved = await SpeechTranscriber.supportedLocale(equivalentTo: locale)
        else { return .unavailable }
        let installed = Set(await SpeechTranscriber.installedLocales.map { $0.identifier(.bcp47) })
        return installed.contains(resolved.identifier(.bcp47)) ? .ready : .needsDownload
    }
    // ensureModel → AssetInventory.assetInstallationRequest + downloadAndInstall (§7.2)
    // liveSession → wires AsyncStream<AnalyzerInput>, converter, analyzer.start (§8, §9)
    // transcribe(file:) → analyzeSequence(from:) + finalizeAndFinish (§8.5)
}
```

**`DictationTranscriberService`** is structurally identical but uses `DictationTranscriber`, has **no `isAvailable`** check (gate on `supportedLocale(equivalentTo:)` only), a `contentHints` field in `Config`, and `.progressiveLongDictation` as its default live preset [3].

### 13c. Capability-based selector (the fallback ladder)

```swift
struct TranscriptionSelector: Sendable {
    let speech: SpeechTranscriberService
    let dictation: DictationTranscriberService
    // let legacy: LegacyRecognizerService   // SFSpeechRecognizer / Whisper floor, see 13e

    func resolve(for locale: Locale) async -> any TranscriptionService {
        if #available(iOS 26.0, *) {
            if await speech.capability(for: locale) != .unavailable { return speech }
            if await dictation.capability(for: locale) != .unavailable { return dictation }
        }
        // return legacy   // below iOS 26, watchOS, or both modern engines unavailable
        fatalError("wire a legacy floor here")
    }
}
```

Ladder: `SpeechTranscriber` (best quality, gated on `isAvailable` + supported locale) → `DictationTranscriber` (older hardware / broader languages) → legacy floor (pre-iOS 26 / watchOS) [4][37].

### 13d. Audio + asset + permission wiring

- **Permission:** `AVAudioApplication.requestRecordPermission()`, `NSMicrophoneUsageDescription` in Info.plist; add speech-auth keys only if a legacy `SFSpeechRecognizer` floor ships [30][37]. See §9.8 for the full privacy-manifest / nutrition-label gate.
- **Audio:** one `AVAudioEngine` tap at native format → shared `BufferConverter` → `bestAvailableAudioFormat` → `AnalyzerInput` (§8). Keep conversion inside the backend so the protocol stays engine-neutral.
- **Assets:** each backend implements `ensureModel` via `AssetInventory`; surface `Progress` as a `.downloading(Double)` UI state (§7). Catch `SFSpeechError` explicitly plus a generic fallback for network/disk (§7.5).

### 13e. Removing/replacing a pre-existing third-party on-device ASR engine

Generic case: the app currently bundles or downloads a Whisper/WhisperKit-style dependency and wants to move to `SpeechAnalyzer`.

1. **Introduce the protocol first (13a) and make the existing engine one conforming backend** (`LegacyWhisperService`). No behavior change; this is the seam.
2. **Add `SpeechTranscriberService` + `DictationTranscriberService` behind the selector (13b/13c).** Now both stacks coexist.
3. **Deployment-target decision — three strategies:**
   - **iOS-26-only:** delete the Whisper dependency; smallest binary, but raises the OS floor and cuts addressable installs.
   - **Both (recommended for a broad install base):** `SpeechAnalyzer` on iOS 26+, Whisper as the **legacy floor** below 26 and on watchOS. Doubles the code you maintain and QA on device.
   - **Interim:** ship the selector with Whisper still the default, flip to `SpeechAnalyzer` per-locale as you gain device-QA confidence.
4. **Keep an optional legacy floor** when min OS < 26: the selector's final rung returns `LegacyWhisperService`. Guard all `Speech` new-API use with `if #available(iOS 26.0, *)` so the app links and runs on older OSes.
5. **Migration wins & costs:** removing the bundled model kills the failure-prone ~500 MB download path and app-size cost (system-managed, 0 MB) [5][33]; the cost is the iOS-26 floor **or** a dual-engine burden, plus narrower language coverage and weaker custom vocabulary [4][33].
6. **Remove the old dependency only after** the selector proves out on device QA across your target hardware matrix — never before device QA on the exact fallback devices.

### 13f. Testing strategy

- **Unit-test through the protocol**, never the live SDK. `xcodebuild` CLI runs don't apply StoreKit-style config and shouldn't hit `Speech` either — no test may construct a real `SpeechAnalyzer`.
- **Fakes:** a `FakeTranscriptionService` returning scripted `AsyncThrowingStream<TranscriptSegment,…>` — exercise volatile→final reconciliation, `isFinal` clearing, `SFSpeechError` propagation + the finished-session contract, and cancellation.
- **File-based fixtures:** ship short WAV/CAF fixtures; the *file path* of `transcribe(file:)` is integration-tested on-device/simulator behind an availability + `isAvailable` guard, skipped otherwise (the Simulator returns `isAvailable == false`).
- **Locale-resolution tests** are pure logic — feed BCP-47 identifiers through your normalizer and assert on the `contains(.current)` trap.
- **Capability-selector tests** with fakes reporting each `TranscriptionCapability` — assert the ladder picks the right backend.

```swift
struct FakeTranscriptionService: TranscriptionService {
    struct Config: Sendable {}
    typealias DownloadProgress = Double
    static let identifier = "fake"
    var scripted: [TranscriptSegment]
    var reported: TranscriptionCapability = .ready
    func capability(for _: Locale) async -> TranscriptionCapability { reported }
    func ensureModel(for _: Locale, config _: Config) async throws -> Double? { nil }
    func liveSession(locale _: Locale, config _: Config) async throws -> LiveTranscriptionSession { /* stream `scripted` */ }
    func transcribe(file _: URL, locale _: Locale, config _: Config) async throws -> AttributedString {
        scripted.reduce(into: AttributedString("")) { $0 += $1.text }
    }
}
```

### 13g. Rollout / verification checklist

- [ ] `NSMicrophoneUsageDescription` present; app does **not** crash on first mic access.
- [ ] `PrivacyInfo.xcprivacy` + App Store nutrition label updated **before** submission; privacy policy published first (§9.8).
- [ ] `if #available(iOS 26.0, *)` guards every new-API call; app links and runs below iOS 26.
- [ ] `SpeechTranscriber.isAvailable` probed at runtime; Simulator + A13 devices fall to `DictationTranscriber`.
- [ ] Locale resolved via `supportedLocale(equivalentTo:)`; no `contains(Locale.current)`; all locale reads `await`ed.
- [ ] First-run download path shows `Progress`; `SFSpeechError` + generic network/disk failures handled; no-network first run degrades gracefully (§7.5).
- [ ] Every mic buffer routed through `AVAudioConverter` to `bestAvailableAudioFormat`; verified **non-empty** transcription on device.
- [ ] Teardown order: `finish()` input → `finalizeAndFinishThroughEndOfInput()` → cancel results task → deactivate session; `.onDisappear` calls it; stream error triggers a fresh analyzer, not a resume.
- [ ] Volatile buffer cleared on `isFinal`; no duplicated text.
- [ ] First-result latency measured on device (guard against the main-actor serialization trap).
- [ ] Interruption + route-change handlers restart the engine; background-audio behavior tested on lock-screen + incoming-call if long sessions are supported (§8.7).
- [ ] Reservations `release`d when done; `maximumReservedLocales` respected; retention policy chosen (§7.6).
- [ ] No test constructs a live `SpeechAnalyzer`; fakes + file fixtures only.
- [ ] Device QA across the full hardware matrix **before** removing any legacy engine.

---

## 14. Open questions / things to verify on-device

- **Exact supported-locale set and count** for `SpeechTranscriber` on your target OS build — enumerate `supportedLocales` at runtime; the ~10–40 figures are community/secondary and device-dependent [4][13].
- **`SpeechDetector` member shapes** (`DetectionOptions`, `SensitivityLevel`, `Result` fields) — the module and its `init(detectionOptions:reportResults:)` are documented, but exact nested-type fields were not individually re-verified for this guide; confirm in Xcode [42].
- **`DictationTranscriber` option-enum cases** (`TranscriptionOption`/`ReportingOption`/`ResultAttributeOption`) — not individually fetched; confirm against docs [3].
- **Beta-flagged members** — `AnalyzerInput`'s `CMReadySampleBuffer` init / `bufferDuration` / `bufferFormat`, and `Options.ignoresResourceLimits` — confirm stability before depending on them [1][15][22].
- **Background transcription** — whether the analyzer keeps consuming buffered input while the app is backgrounded / screen-locked, and exactly what `UIBackgroundModes: audio` covers for this path (§8.7); Apple's docs are thin — verify end-to-end on device [23][31].
- **First-result latency** on your device matrix, and whether `@concurrent` / disabling approachable concurrency is needed [28].
- **`maximumReservedLocales`** on your lowest-storage target device [5][19].
- **FoundationModels extraction quality** against your existing extraction eval set before any consolidation (§12.4) [25][44].
- **Device-support specifics** (which A-series chips return `isAvailable == false`, Simulator behavior, locale counts, benchmark numbers) are community/reverse-engineered — treat as indicative, not authoritative, and re-check on your hardware [26][27][33][34][35].

---

## 15. Sources

1. SpeechAnalyzer — Apple Developer Documentation — https://developer.apple.com/documentation/speech/speechanalyzer
2. SpeechTranscriber — Apple Developer Documentation — https://developer.apple.com/documentation/speech/speechtranscriber
3. DictationTranscriber — Apple Developer Documentation — https://developer.apple.com/documentation/speech/dictationtranscriber
4. Speech framework — Apple Developer Documentation — https://developer.apple.com/documentation/speech
5. AssetInventory — Apple Developer Documentation — https://developer.apple.com/documentation/speech/assetinventory
6. AssetInstallationRequest — Apple Developer Documentation — https://developer.apple.com/documentation/speech/assetinstallationrequest
7. SpeechTranscriber.Preset — https://developer.apple.com/documentation/speech/speechtranscriber/preset
8. SpeechTranscriber.Result — https://developer.apple.com/documentation/speech/speechtranscriber/result
9. SpeechTranscriber.ReportingOption — https://developer.apple.com/documentation/speech/speechtranscriber/reportingoption
10. SpeechTranscriber.ResultAttributeOption — https://developer.apple.com/documentation/speech/speechtranscriber/resultattributeoption
11. SpeechTranscriber.TranscriptionOption — https://developer.apple.com/documentation/speech/speechtranscriber/transcriptionoption
12. SpeechTranscriber.supportedLocale(equivalentTo:) — https://developer.apple.com/documentation/speech/speechtranscriber/supportedlocale(equivalentto:)
13. SpeechTranscriber.supportedLocales — https://developer.apple.com/documentation/speech/speechtranscriber/supportedlocales
14. SpeechTranscriber.isAvailable — https://developer.apple.com/documentation/speech/speechtranscriber/isavailable
15. AnalyzerInput — https://developer.apple.com/documentation/speech/analyzerinput
16. SpeechModule — https://developer.apple.com/documentation/speech/speechmodule
17. LocaleDependentSpeechModule — https://developer.apple.com/documentation/speech/localedependentspeechmodule
18. AssetInventory.Status — https://developer.apple.com/documentation/speech/assetinventory/status
19. AssetInventory.maximumReservedLocales — https://developer.apple.com/documentation/speech/assetinventory/maximumreservedlocales
20. AttributeScopes.SpeechAttributes — https://developer.apple.com/documentation/foundation/attributescopes/speechattributes
21. SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith:) — https://developer.apple.com/documentation/speech/speechanalyzer/bestavailableaudioformat(compatiblewith:)
22. SpeechAnalyzer.Options — https://developer.apple.com/documentation/speech/speechanalyzer/options
23. Recognizing speech in live audio — https://developer.apple.com/documentation/speech/recognizing-speech-in-live-audio
24. Bringing advanced speech-to-text capabilities to your app (sample) — https://developer.apple.com/documentation/speech/bringing-advanced-speech-to-text-capabilities-to-your-app
25. WWDC25 Session 277 — Bring advanced speech-to-text to your app with SpeechAnalyzer — https://developer.apple.com/videos/play/wwdc2025/277/
26. Apple Developer Forums — SpeechTranscriber not supported (thread 806765) — https://developer.apple.com/forums/thread/806765
27. Apple Developer Forums — Determining SpeechTranscriber device support (thread 807739) — https://developer.apple.com/forums/thread/807739
28. Apple Developer Forums — SpeechTranscriber extremely slow (thread 795924) — https://developer.apple.com/forums/thread/795924
29. AnalysisContext — https://developer.apple.com/documentation/speech/analysiscontext
30. AVAudioApplication.requestRecordPermission — https://developer.apple.com/documentation/avfaudio/avaudioapplication/requestrecordpermission(completionhandler:)
31. Handling audio interruptions (AVAudioSession) — https://developer.apple.com/documentation/avfaudio/handling-audio-interruptions
32. Responding to audio route changes (AVAudioSession) — https://developer.apple.com/documentation/avfaudio/responding-to-audio-route-changes
33. Apple SpeechAnalyzer and Argmax WhisperKit (earnings22 benchmark) — https://www.argmaxinc.com/blog/apple-and-argmax
34. Apple SpeechAnalyzer vs Whisper: Independent Benchmark (LibriSpeech WER) — https://www.developersdigest.tech/blog/apple-speechanalyzer-vs-whisper-benchmark
35. Hands-On: How Apple's New Speech APIs Outpace Whisper (Yap) — MacStories — https://www.macstories.net/stories/hands-on-how-apples-new-speech-apis-outpace-whisper-for-lightning-fast-transcription/
36. A Quick Look at Apple's SpeechAnalyzer API — addpipe — https://blog.addpipe.com/apple-speechanalyzer-api/
37. Apple's New Speech Framework: SpeechAnalyzer vs SFSpeechRecognizer — Blake Crosley — https://blakecrosley.com/blog/speech-framework-vs-sfspeechrecognizer
38. Implementing advanced speech-to-text in your SwiftUI app — Create with Swift — https://www.createwithswift.com/implementing-advanced-speech-to-text-in-your-swiftui-app/
39. iOS 26's SpeechAnalyzer on a live mic: the 5 things the docs don't tell you — dev.to (SimpleMemo) — https://dev.to/simple_memo/ios-26s-speechanalyzer-on-a-live-mic-the-5-things-the-docs-dont-tell-you-2ng5
40. SpeechModels — https://developer.apple.com/documentation/speech/speechmodels
41. SFSpeechError (typed error codes: timeout, insufficientResources, audioReadFailed, internalServiceError, malformedSupplementalModel, missingParameter, undefinedTemplateClassName) — https://developer.apple.com/documentation/speech/sfspeecherror-swift.struct
42. SpeechDetector (VAD module: init(detectionOptions:reportResults:), SensitivityLevel, DetectionOptions, Result) — https://developer.apple.com/documentation/speech/speechdetector
43. SpeechAnalyzer.Options.ModelRetention (whileInUse, lingering, processLifetime) — https://developer.apple.com/documentation/speech/speechanalyzer/options/modelretention-swift.enum
44. FoundationModels — Apple Developer Documentation (on-device summarization/titling paired with SpeechAnalyzer per WWDC 277) — https://developer.apple.com/documentation/foundationmodels
