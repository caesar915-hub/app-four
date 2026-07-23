<!-- Created: 2026-07-22 01:32 WEST · Updated: 2026-07-22 10:55 WEST -->
# Android Port — Phase 1 (Foundation) → builds on Gate G0

**Scope.** This document expands **Phase 1 (Foundation)** of [ANDROID_PORT_PLAN.md](ANDROID_PORT_PLAN.md) (v1.1) into five execution-ready workstreams for the plan's 3-week Foundation block: shared-core SPM extraction (**P1-A**), the data-flow/bridging seam (**P1-E**), the Android persistence layer (**P1-C**), the audio-capture pipeline (**P1-D**), and the Android scaffold + first CI (**P1-B**). Phase 1 is **conditional on G0 green** ([ANDROID_PHASE0.md](ANDROID_PHASE0.md)) and carries forward the two unresolved forks G0 leaves open: **P0.3** SkipSQL-vs-Room (owner decision — branches P1-C), and **P0.4**'s iOS-tokenizer hatch (if P0.4 was only conditionally green, P1-A inherits a named +2–4 d re-baseline). Nothing here is committed work until all four G0 spikes pass.

**Provenance.** Each of the five workstreams was drafted by a dedicated Opus/MAX engineer-agent (research + repo-grounded, external claims web-cited, verified 2026-07-22), then assembled into this document and reviewed in **two adversarial rounds**. Round 1 (three Opus/MAX lenses: A markdown+externals, B executability/gate-rigor, C repo-grounding/cross-phase) applied the Lens-A structural/externals fixes and the at-a-glance P1-E split, but most Lens-B/C findings were left outstanding. Round 2 (three fresh Opus lenses: cross-doc consistency, leftover-verification, sources audit) applied the remainder in place: the persistence-DTO rename resolving the app-target name collisions, the STT-seam reconciliation, the CI/scaffold executability fixes (package paths, host toolchain, NDK step id, repository layout, Gate G1), and the citation corrections (AGP floor, Room primary sources). Sourcing standard: external claims carry an inline cited URL; repo claims carry `file:line` (internal repo links are relative to `docs/` — repo sources as `../app-four/…` / `../Packages/…`, engineering docs as `engineering/…`, sibling plan docs as `ANDROID_PORT_PLAN.md` / `ANDROID_PHASE0.md`).

**Standing recommendation (from the plan):** execution should start on a post-1.0 Android demand signal; Phase 1 is the first *committed build-out* and only begins once G0 is scored green with every caveat resolved or owner-acknowledged.

---

## Workstreams at a glance

| Workstream | Goal (one line) | Exit gate (binary) | Budget |
|---|---|---|---|
| **P1-A** — Shared-core SPM extraction | Pull every platform-neutral Swift type into a `SquirlCore` SPM umbrella that iOS + Android consume from one source; cross-compile clean for the Android triple. | 5 products build on iOS host **and** the 4 shared products cross-compile for `aarch64-unknown-linux-android28`; `JournalRecordingDTO` round-trips 29 fields + 3 relations; lexicon byte-parity by construction. | 5–7 eng-days |
| **P1-E-core** — Data-flow & bridging seam (pure-Swift) | Define the DTO/SkipBridge seam + the `JournalRepository` refactor so record→transcribe→extract→persist is written **once** (native Swift). | `JournalRepository` merged on iOS, orchestration VMs reference **no** `@Model`; DTO seam inventory + `bridging:true` module map + reusable `JournalRepository` conformance suite written; iOS suite green (behavior-preserving, lost-update audit done). | 4–5 eng-days |
| **P1-E-smoke** — on-scaffold bridge smoke | One Compose→bridged-Swift round-trip returning a `SummaryResult`-shaped DTO, proving async→suspend + struct marshalling on device. | Runs after **P1-B-scaffold**; renders one bridged field on the Fuse scaffold. | ~1 eng-day |
| **P1-C** — Persistence layer | Android store that byte-mirrors the SwiftData schema (29 + 3); branch **A = SkipSQL** / **B = Room** per the P0.3 fork. | 4 tables, cascade + upsert-preserves-children + ordered reads round-trip byte-identical on device (+ iOS for Path A); enums as rawValue; dates as epoch-millis. | 3–4 d (A, Android-only) / 4–5 d (B) |
| **P1-D** — Audio capture pipeline | Native Android mic → 16 kHz mono → dual output: AAC `.m4a` artifact **and** pre-encode float PCM to STT. | `.m4a` parity (16 kHz/mono/AAC-LC), PCM sink `[-1,1]` with no AAC round-trip, `microphone`-FGS compliance, interruption preserves capture. | 3–4 eng-days |
| **P1-B** — Android scaffold + build + CI | `skip init --native-app` scaffold + the repo's first CI proving cross-compile, APK assemble, 16 KB gate, and fixture parity on every push. | Scaffold committed + `android.yml` green on branch; 16 KB alignment + golden-fixture parity are **hard** CI failures; all pins in-repo. | 4–5 eng-days |

**Sequencing headline:** P1-E's seam contract lands **first** (pure iOS Swift, zero Android risk) → P1-A packages the shared core against it → P1-C/P1-D implement the platform contracts → P1-B's CI wraps every gate. Full run-order, reconciliations, and total effort are in **Consolidated risks & sequencing** at the end.

**DAG:** `P1-E-core → P1-A → {P1-B-scaffold, P1-C, P1-D} → P1-B-CI`; `P1-E-smoke` runs after `P1-B-scaffold`.

---

## P1-A — Shared-core SPM extraction & module architecture

*Phase 1 (Foundation) workstream. Budget: part of Phase 1's 3 weeks (this workstream ≈ 5–7 eng-days). Hard upstream deps: **P0.1 green** (Android triple cross-compiles) and **P0.4 green** (extractor fenced + fixture-parity) — P1-A is where P0.4's spike-grade fence, static inflection table, and lexicon-source fix become a real, reusable SPM package rather than a spike scaffold.*

### Goal

Pull every platform-neutral Swift type out of the iOS app target and into SPM package products that **both** the iOS app and the Skip Fuse Android app consume from a single source of truth. The shared core must cross-compile clean for `aarch64-unknown-linux-android28` on the official Swift 6.3.3 Android SDK ([swift.org/platform-support](https://www.swift.org/platform-support/), triple + API-28 floor verified 2026-07-22). Everything that touches SwiftData (`@Model` classes, `PersonalLexiconBuilder`) or SwiftUI (`SquirlDesignSystem` components) stays iOS-only; the shared layer speaks **DTO value-types**, never `@Model`.

The design contract, stated once: **iOS ⇄ JournalRecordingDTO ⇄ Android**. The shared package defines the DTO; neither persistence engine (SwiftData on iOS, Room-or-SkipSQL on Android per the P0.3 fork) lives inside it.

### Current-state repo grounding (file:line)

**Two packages exist today**, wired by path deps and surfaced app-wide by one re-export file:

- `Packages/SquirlSignals/` — pure `Foundation` leaf. Holds the four level enums `MoodLevel`/`EnergyLevel`/`FocusLevel`/`SleepLevel` ([Levels.swift:8](../Packages/SquirlSignals/Sources/SquirlSignals/Levels.swift#L8) — comment at :1-6 states these were hoisted "so both the app (NoteExtraction service) and `SquirlDesignSystem` … can depend on them without a SwiftUI edge"). `Package.swift` pins `platforms: [.iOS("26.0")]`, `swiftLanguageModes: [.v5]` ([Package.swift:6,13](../Packages/SquirlSignals/Package.swift#L6)).
- `Packages/SquirlDesignSystem/` — SwiftUI-heavy (26 source files: `Palette.swift`, `SignalGlyph.swift`, `Glyphs/*`, `Buttons.swift`, `Card.swift`, `Theme.swift`, …). Depends on `SquirlSignals` ([Package.swift:11,16](../Packages/SquirlDesignSystem/Package.swift#L11)). Same `.iOS("26.0")` pin.
- [SignalsReexport.swift:4-5](../app-four/App/SignalsReexport.swift#L4) — `@_exported import SquirlSignals` + `@_exported import SquirlDesignSystem`, so every app file sees `MoodLevel`/`Theme`/`Palette`/… unqualified with no per-file import churn. **This is load-bearing for the migration**: hoisting more enums into `SquirlSignals` keeps app code compiling without touching call sites.

**The extractor is NOT yet a package** — it is 8 files in the app target at `../app-four/Services/NoteExtraction/`:

| File | Role | Portability blocker |
|---|---|---|
| [NoteExtraction.swift](../app-four/Services/NoteExtraction/NoteExtraction.swift) | Output DTO `struct NoteExtraction: Sendable, Codable, Equatable` (:4) + `MedEvent` (:139) + `MedEventChange` (:133) + `SleepNote`/`SleepEvent` + `protocol NoteExtractor` (:199) | `import Foundation`; references `SquirlSignals` level enums via the app-target `@_exported` reexport — **needs an explicit `import SquirlSignals` added when moved into the package** |
| [Lexicon.swift](../app-four/Services/NoteExtraction/Lexicon.swift) | `struct Lexicon` (:6) + `defaultX` fallback arrays | `import NaturalLanguage` (:2) |
| [LexiconData.swift](../app-four/Services/NoteExtraction/LexiconData.swift) | `Codable` mirror + `LexiconLoader.loadBundled` | `import Foundation` only — **but** loads via `Bundle.main` (blocker, below) |
| [CueMatcher.swift](../app-four/Services/NoteExtraction/CueMatcher.swift) | Tokenize + cue matching; `altForms`/`canonicalInflections` model-independent path (:29, :124 — **table empty today**) | `NLTokenizer`/`NLTagger` at :39,:60,:62,:84 (P0.4 fence sites A–D) |
| [TenseClassifier.swift](../app-four/Services/NoteExtraction/TenseClassifier.swift) | Tense fallback | `NLTagger([.lexicalClass])` :73,:78 (P0.4 site F) |
| [NLNoteExtractor.swift](../app-four/Services/NoteExtraction/NLNoteExtractor.swift) | 54 KB main extractor | `NLTokenizer(.sentence)` :332 (site E) + `NSDataDetector`/`Calendar.current` :701,:709 |
| [PersonalLexiconBuilder.swift](../app-four/Services/NoteExtraction/PersonalLexiconBuilder.swift) | Per-user overlay from corrections | **`import SwiftData` (:2) — iOS-only, stays out of shared core** |

- **Extractor wiring**: `NLSummarizationService.init(personalOverlay:)` → `NLNoteExtractor(lexicon: LexiconLoader.loadBundled(overlay:))` ([NLSummarizationService.swift:16-17](../app-four/Services/NLSummarizationService.swift#L16)); `.extract(from:)` at :27. The pure extractor runs with `personalOverlay = nil` — the SwiftData overlay is a *merge of an already-built overlay*, so it is cleanly separable.
- **Lexicon resource**: `../app-four/Resources/lexicon.json` — **verified 718 list entries across 32 top-level keys** (`python3 json.load` this session). Loaded through `Bundle.main.url(forResource: "lexicon", withExtension: "json")` with a **silent fallback to the smaller hardcoded `defaultX` arrays** on failure ([ANDROID_PHASE0.md:895](ANDROID_PHASE0.md#L895) BLOCKER, verified sizes: `medications` 89 in JSON vs 56 default). Under Skip Fuse / Android SDK, `Bundle.main` resolution is unproven — if it returns `nil`, Android silently runs a *different vocabulary* than iOS. **P1-A must eliminate this fork** (carries P0.4 exit #7).

**The `@Model` classes (all iOS-only, SwiftData):** [Recording.swift](../app-four/Models/Recording.swift) — **29 stored fields (:9–:46) + 3 `@Relationship` collections (:60,:63,:68)**: `segments: [TranscriptionSegment]?`, `correctionTags: [RecordingTag]?`, `medicationEvents: [MedicationEvent]?`, all `deleteRule: .cascade`. Relationship model shapes verified this session:
- `TranscriptionSegment` — 7 stored (`id`,`text`,`startTime`,`endTime`,`isFinal`,`confidence`,`language`) + `recording` backref.
- `RecordingTag` — 6 stored (`id`,`name`,`category`,`source`,`confidence`,`createdAt`) + `recording`; `TagSource`/`TagCategory` enums in-file.
- `MedicationEvent` — 12 stored (`id`,`name`,`dose`,`takenAt`,`taken`,`quantity`,`durationHours`,`change`,`timeLabel`,`source`,`createdAt`,`isMockData`) + `recording`; nested `enum Source` (:36), reuses `MedEventChange` from the extractor module.
- `RecordingStatus` at [AppEnums.swift:5](../app-four/Models/AppEnums.swift#L5).

### Target package graph

**Consolidate into ONE umbrella package** `Packages/SquirlCore/` with four cross-platform library products, and keep `SquirlDesignSystem` as its own iOS-only package. Rationale (tradeoff surfaced): five sibling package dirs each with a `Package.swift` + path-dep = resolution sprawl for a solo dev; one package with multiple targets = atomic versioning, one resolve, and Skip Fuse consumes a single dependency. `SquirlDesignSystem` stays separate because it is SwiftUI and must **never** enter the Android product closure.

```
SquirlSignals ──────────────┐   (leaf: Foundation value types + hoisted pure enums)
   ▲          ▲         ▲    │
   │          │         │    │
SquirlNote   SquirlModel  SquirlDesign
Extraction    DTO          Tokens
   ▲          ▲            ▲    ▲
   │          │            │    │
   └── iOS app-four ───────┘    │   (owns @Model + mappers + PersonalLexiconBuilder)
   └── Android app ────────┘    │   (owns Room/SkipSQL rows + JNI)
                                │
              SquirlDesignSystem (iOS-only, SwiftUI) ── depends on Tokens + Signals
```

| Product | Contents | Deps | iOS | Android |
|---|---|---|---|---|
| **SquirlSignals** | 4 level enums + hoisted pure enums: `RecordingStatus`, `MedEventChange`, `MedicationEventSource` (hoisted flat from nested `MedicationEvent.Source`), `TagSource`, `TagCategory` | Foundation | ✓ | ✓ |
| **SquirlNoteExtraction** | `NoteExtraction`/`MedEvent`/`SleepNote`/`SleepEvent`/`NoteExtractor`, `Lexicon`, `LexiconData`, `CueMatcher`, `TenseClassifier`, `NLNoteExtractor`, **new** `LinguisticProvider.swift` fence, **generated** `InflectionTable.swift` + compiled-in `LexiconConstants.swift` | Signals | ✓ | ✓ |
| **SquirlModelDTO** | `JournalRecordingDTO` (29 fields) + `JournalSegmentDTO`/`JournalTagDTO`/`JournalMedEventDTO` — deliberately **not** named `RecordingDTO`/`MedicationEventDTO`/`TranscriptionSegmentDTO`, which are pre-existing, differently-shaped app-target types (export: [ExportService.swift:20,79](../app-four/Services/ExportService.swift#L20); streaming: [Protocols.swift:48](../app-four/Services/Protocols.swift#L48)) | Signals | ✓ | ✓ |
| **SquirlDesignTokens** | Pure token *values* (hex strings, spacing/radii scalars, signal-ramp stops) extracted from `SquirlDesignSystem` — no SwiftUI | Signals | ✓ | ✓ |
| **SquirlDesignSystem** (separate pkg) | All SwiftUI components/glyphs, refactored to read raw values from Tokens | Signals, Tokens | ✓ | ✗ |

**`Packages/SquirlCore/Package.swift`:**

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SquirlCore",
    // iOS floor for Apple builds ONLY. Per ANDROID_PHASE0 §6 (MAJOR): SPM `platforms:`
    // declares minimum deployment for the listed *Apple* platforms and does NOT restrict
    // building the Android/Linux triples (they take default minimums). Keep the pin;
    // it is not the Android resolution blocker — that is found empirically in P0.4.
    platforms: [.iOS("26.0")],
    products: [
        .library(name: "SquirlSignals",       targets: ["SquirlSignals"]),
        .library(name: "SquirlNoteExtraction", targets: ["SquirlNoteExtraction"]),
        .library(name: "SquirlModelDTO",       targets: ["SquirlModelDTO"]),
        .library(name: "SquirlDesignTokens",   targets: ["SquirlDesignTokens"]),
    ],
    targets: [
        .target(name: "SquirlSignals"),
        .target(
            name: "SquirlNoteExtraction",
            dependencies: ["SquirlSignals"]
            // NOTE: no `resources:` — the lexicon is compiled in (see DTO/§lexicon).
            // If Bundle.module is chosen instead after P0.3/P0.4 verification:
            //   resources: [.process("Resources/lexicon.json")]
        ),
        .target(name: "SquirlModelDTO",     dependencies: ["SquirlSignals"]),
        .target(name: "SquirlDesignTokens", dependencies: ["SquirlSignals"]),
        .executableTarget(
            name: "fixture-runner",
            dependencies: ["SquirlNoteExtraction"],
            resources: [.copy("ExtractorFixtures")]),   // adb-pushed on-device parity runner (P0.4 §5)
        .testTarget(
            name: "SquirlNoteExtractionTests",
            dependencies: ["SquirlNoteExtraction"],
            resources: [.copy("ExtractorFixtures")]   // the 40–60 golden pairs (P0.4 §5)
        ),
    ],
    swiftLanguageModes: [.v5]
)
```

**Revised `Packages/SquirlDesignSystem/Package.swift`** (now consumes the token package instead of hardcoding values):

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SquirlDesignSystem",
    platforms: [.iOS("26.0")],   // SwiftUI — deliberately iOS-only; never in the Android closure
    products: [.library(name: "SquirlDesignSystem", targets: ["SquirlDesignSystem"])],
    dependencies: [.package(path: "../SquirlCore")],
    targets: [
        .target(
            name: "SquirlDesignSystem",
            dependencies: [
                .product(name: "SquirlSignals",     package: "SquirlCore"),
                .product(name: "SquirlDesignTokens", package: "SquirlCore"),
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
```

**Lexicon-source decision (resolves the P0.4 §7 BLOCKER):** compile the vocabulary in as a Swift constant, not a runtime resource. A committed generator reads `lexicon.json` and emits `LexiconConstants.swift` (a `LexiconData` literal); `LexiconLoader.loadBundled` is replaced by `LexiconData.compiledIn` — **no `Bundle.main`/`Bundle.module` lookup on either platform**, so both platforms are byte-identical by construction. Same pattern as the P0.4 static inflection table (generated-and-committed, drift = build failure). `Bundle.module` via `.process` is the fallback *only if* a compiled-in 718-entry literal proves unwieldy AND P0.3 confirms Fuse resolves `Bundle.module` on the Android triple — record that check, don't assume it.

**Generators & drift gates.** Two committed generators live under `Packages/SquirlCore/Tools/`: `gen-lexicon.swift` (`lexicon.json` → `Sources/SquirlNoteExtraction/LexiconConstants.swift`) and `gen-inflection.swift` (inflection source → `InflectionTable.swift`, populating `canonicalInflections` + `cueLemmas`). A SwiftPM build-tool plugin (or `make gen`) runs both; a `swift test` case regenerates each into a temp dir and `diff`s against the committed `.swift` — non-zero diff = drift = red build. **Budget: populating the inflection table is a genuine linguistic deliverable (the table is empty today, [CueMatcher.swift:124](../app-four/Services/NoteExtraction/CueMatcher.swift#L124); est. +1–2 d) unless inherited complete from P0.4 (cite file:line at implementation time).**

### DTO layer (mirroring the 29 fields / 3 relationships)

`SquirlModelDTO` is the cross-platform persistence contract: pure `Sendable, Codable` structs that mirror the SwiftData `@Model` columns 1:1. **iOS** maps `Recording ⇄ JournalRecordingDTO` in the app target (only that side touches `@Model`); **Android** maps `JournalRecordingDTO ⇄ Room/SkipSQL rows`. The DTO holds the persisted JSON columns as `String?` (not decoded structs) so the fixture suite's byte-exact round-trip (P0.4 §5) is preserved end-to-end.

> **Naming — collision guard.** The app target already owns the bare names this family would otherwise take: export `RecordingDTO` (27 scalars + `audioBase64`, `status: String`, omits `cloudSyncStatus`/`isMockData`), `SegmentDTO`, `TagDTO`, `MedicationEventDTO` (11 fields, no `isMockData`) at [ExportService.swift:20-91](../app-four/Services/ExportService.swift#L20), and the streaming `TranscriptionSegmentDTO` (`isError`, no `language`; `Sendable`-only, not `Codable`) at [Protocols.swift:48](../app-four/Services/Protocols.swift#L48). Those are structurally different types that stay app-target-local. The persistence family therefore uses the `Journal*` prefix (`JournalRecordingDTO`/`JournalSegmentDTO`/`JournalTagDTO`/`JournalMedEventDTO`) so importing `SquirlModelDTO` into the app target never shadows them.

```swift
import Foundation
import SquirlSignals   // RecordingStatus, MedEventChange, MedicationEventSource, TagSource, TagCategory

public struct JournalRecordingDTO: Sendable, Codable, Equatable {
    // Identity / lifecycle
    public var id: UUID
    public var createdAt: Date
    public var updatedAt: Date
    // Audio artifact
    public var audioFileName: String
    public var duration: TimeInterval
    public var fileSize: Int64
    public var status: RecordingStatus
    // Transcript / title
    public var fullTranscriptText: String
    public var title: String
    public var isFavorite: Bool
    public var cloudSyncStatus: String?
    // Summarization
    public var summary: String?
    public var summaryStatus: String?
    public var topicTagsJSON: String?
    public var summaryGeneratedAt: Date?
    // ADHD journal (scalars are the source of truth; JSON columns hold the rest)
    public var hasMedication: Bool
    public var medicationInfo: String?
    public var energyLevel: String?
    public var focusLevel: String?
    public var mood: String?
    public var sleepHours: Double?
    public var sleepQuality: String?
    public var summaryBulletsJSON: String?
    public var noteExtractionJSON: String?
    public var sideEffectsJSON: String?
    public var sleepEventJSON: String?
    public var emotionsJSON: String?
    public var sleepLevelValue: String?
    public var isMockData: Bool
    // 3 relationships — sorted, non-optional arrays (CloudKit-optionality is a
    // persistence concern, not a DTO concern; empty == none)
    public var segments: [JournalSegmentDTO]
    public var correctionTags: [JournalTagDTO]
    public var medicationEvents: [JournalMedEventDTO]

    public init(/* 29 stored + 3 arrays, all defaulted to mirror the @Model init */) { /* … */ }
}

public struct JournalSegmentDTO: Sendable, Codable, Equatable {
    // NOT the streaming TranscriptionSegmentDTO (Protocols.swift:48) — that type has
    // `isError` and no `language`, and is Sendable-only. Mapping: isError → dropped
    // (transient stream state, never persisted); language ← default "en" when absent.
    public var id: UUID
    public var text: String
    public var startTime: TimeInterval
    public var endTime: TimeInterval
    public var isFinal: Bool
    public var confidence: Double?
    public var language: String
}

public struct JournalTagDTO: Sendable, Codable, Equatable {
    public var id: UUID
    public var name: String
    public var category: String     // TagCategory rawValue as stored
    public var source: String       // TagSource rawValue as stored
    public var confidence: Double?
    public var createdAt: Date
}

public struct JournalMedEventDTO: Sendable, Codable, Equatable {
    public var id: UUID
    public var name: String
    public var dose: String?
    public var takenAt: Date
    public var taken: Bool
    public var quantity: Double?
    public var durationHours: Double
    public var change: MedEventChange?          // hoisted to SquirlSignals
    public var timeLabel: String?
    public var source: MedicationEventSource    // hoisted to SquirlSignals
    public var createdAt: Date
    public var isMockData: Bool
}
```

**Field-count guard (drift is the top DTO risk):** the 29-field `JournalRecordingDTO` will silently rot if `Recording` gains a column. Add a compile-time-adjacent test asserting `Mirror(reflecting:).children.count` of `JournalRecordingDTO` (minus the 3 arrays) == 29, and a `Recording ⇄ JournalRecordingDTO ⇄ Recording` round-trip test that fails if any of the 29 stored fields or 3 collections is dropped. This makes DTO/model divergence a red build, not a runtime bug.

**Type-mapping note for the P0.3 fork:** DTO field types were chosen to map to *both* persistence engines — `UUID`→TEXT, `Date`→Long (converters), `Int64`/`Double?`→INTEGER/REAL, enums→rawValue TEXT. Whichever engine P0.3 picks (Room or SkipSQL), the DTO is identical; only the mapping/annotation layer differs (Kotlin `@Entity` generated against the DTO shape vs SkipSQL Swift). `@Relation` results sort by `startTime` per the plan — the iOS mapper sorts `segments` on the way into the DTO so both platforms see the same order.

### iOS-only boundary (what does NOT move to the shared core)

- **All SwiftData `@Model` classes** — `Recording`, `TranscriptionSegment`, `RecordingTag`, `MedicationEvent`. SwiftData is unsupported on Android under Skip ([ANDROID_PORT_PLAN.md](ANDROID_PORT_PLAN.md) — Android v1 uses Room/SkipSQL). The shared core sees only their DTO mirrors.
- **`PersonalLexiconBuilder.swift`** — `import SwiftData` (:2); reads `RecordingTag` via `FetchDescriptor`. Stays in the app target. The extractor package takes an *already-built* `PersonalLexicon` overlay (or `nil`), so the pure path is Android-clean.
- **`SquirlDesignSystem`** (whole SwiftUI package) — Palette/Glyph/Card/Button/Theme. Its *token values* are extracted into `SquirlDesignTokens`; its *components* never enter the Android product closure. Android's SkipFuseUI reads `SquirlDesignTokens` and builds its own views (P0.3 already copied `Palette`/`Radius`/`Spacing` source into the spike; P1-A promotes that to a real dep — [ANDROID_PHASE0.md:702](ANDROID_PHASE0.md#L702)).
- **`AppleLinguisticProvider`** — the `#if canImport(NaturalLanguage)` arm of the P0.4 fence. It *ships in the shared package* but compiles only on Apple platforms; Android links `PortableLinguisticProvider` ([ANDROID_PHASE0.md:947-950](ANDROID_PHASE0.md#L947)).

### Migration / move steps

Repo is on **Xcode 16 synchronized folders (objectVersion 77)** — moving files does not touch `pbxproj` ([memory: no-xcodegen-tuist]); moving a file *out* of `app-four/` into a package dir drops it from the app target, which then re-imports it. Order to keep `main` releasable:

1. **Scaffold** `Packages/SquirlCore/` with the four empty targets + the `Package.swift` above. Repoint `SquirlDesignSystem/Package.swift` at `../SquirlCore`.
2. **Hoist pure enums into `SquirlSignals`**: move `RecordingStatus` (from `AppEnums.swift`), `MedEventChange` (from `NoteExtraction.swift`), `MedicationEvent.Source` (hoisted as flat top-level `MedicationEventSource` — nesting cannot survive the hoist), `TagSource`, `TagCategory` into the `SquirlSignals` target as top-level `public` enums. `SignalsReexport.swift`'s `@_exported import SquirlSignals` keeps every app call site compiling unqualified — verify no name collision.
3. **`git mv` the 7 extractor files** (all except `PersonalLexiconBuilder.swift`) into `Packages/SquirlCore/Sources/SquirlNoteExtraction/`. Audit access levels: promote `NLNoteExtractor`, `LexiconLoader`, and any `internal` entry points to `public` (the value types are already `public`). Add `import SquirlSignals` to every moved file that references `MoodLevel`/`EnergyLevel`/`FocusLevel`/`SleepLevel`/hoisted enums — the app-side `@_exported` reexport does not reach inside the package.
4. **Add the P0.4 artifacts** to the extraction target: `LinguisticProvider.swift` (Foundation-only protocol + `#if canImport(NaturalLanguage)` Apple impl + `PortableLinguisticProvider`), the generated `InflectionTable.swift` (`canonicalInflections` + `cueLemmas`, populating the empty [CueMatcher.swift:124](../app-four/Services/NoteExtraction/CueMatcher.swift#L124)), and the generated `LexiconConstants.swift`. Rewrite `CueMatcher`/`TenseClassifier`/`NLNoteExtractor` to call the protocol, never `NL*` directly.
5. **Kill the `Bundle.main` fork**: replace `LexiconLoader.loadBundled` with `LexiconData.compiledIn`; delete `lexicon.json` from `app-four/Resources/` (now a generator input under `SquirlCore/`).
6. **Create `SquirlModelDTO`** structs + write the iOS `Recording ⇄ JournalRecordingDTO` mappers in the app target (they touch `@Model`, so they cannot live in the package). Add the field-count guard + round-trip tests. Note: ExportService's existing `RecordingDTO` is a 27-field export *subset* (omits `cloudSyncStatus`/`isMockData`; adds `audioBase64`); if ExportService is later routed through the 29-field `JournalRecordingDTO`, the `JournalArchive` JSON shape changes → **plan a `formatVersion` bump** ([ExportService.swift:11-18](../app-four/Services/ExportService.swift#L11)).
7. **Extract `SquirlDesignTokens`**: pull raw hex/spacing/radii/ramp values out of `SquirlDesignSystem/Palette.swift`/`Spacing.swift`/`Radius.swift` into pure constants; refactor the SwiftUI components to read them. Add a token-parity test (DS-rendered value == token value).
8. **Wire the app target** to the new products; build iOS; run the full app test suite + extractor fixtures (must stay byte-identical — no behavior change). Then **cross-compile the four shared products** with `swift build --swift-sdk aarch64-unknown-linux-android28 --static-swift-stdlib -c release` (gated on P0.1 toolchain) and run the on-device `fixture-runner` (P0.4 §5).

Each step is independently buildable — commit per step so a regression is bisectable and one PR = one revertable slice.

### Exit criteria (binary)

P1-A is done iff **all** hold:

1. `swift build` green on the iOS host for all five products, **and** `swift build --swift-sdk aarch64-unknown-linux-android28 --static-swift-stdlib` green for `SquirlSignals` + `SquirlNoteExtraction` + `SquirlModelDTO` + `SquirlDesignTokens` (carries P0.4 exit #1). `SquirlDesignSystem` is **absent** from the Android build closure.
2. The `app-four` iOS target builds and the **full existing test suite is green** after the move — zero behavior change; extractor output byte-identical to pre-move goldens (carries P0.4 #4, iOS side).
3. `JournalRecordingDTO` round-trips: `Recording → JournalRecordingDTO → Recording` preserves all **29 stored fields + 3 relationship collections** (unit test); the field-count guard asserts 29.
4. **Lexicon byte-parity by construction** — no `Bundle.main` path remains; the 718-entry vocabulary is compiled in and identical on both triples (carries P0.4 #7).
5. The `LinguisticProvider` fence is in place with a working `PortableLinguisticProvider`, and the generated `InflectionTable`/`cueLemmas` are committed and byte-identical across platforms; no live `NL*` symbol on the Android build (carries P0.4 #2/#3).
6. `SquirlDesignTokens` exists and `SquirlDesignSystem` consumes it; token-parity test green; no Android-needed hex/spacing value is stranded inside the SwiftUI package.
7. Dependency-graph assertion: `PersonalLexiconBuilder`, every `@Model` class, and all of `SquirlDesignSystem` are provably **not** reachable from any Android-consumed product.

### Risks & effort

**Budget ≈ 5–7 eng-days** inside Phase 1's 3 weeks (solo dev + agent). The extraction itself is mechanical once P0.4's fence design is in hand; the effort is in access-level churn, the DTO mappers/tests, and the token extraction.

| Risk | Impact | Mitigation |
|---|---|---|
| **DTO drift** — `Recording` gains a 30th column, DTO silently lags | Cross-platform data loss | Field-count `Mirror` guard + round-trip test = red build (exit #3) |
| **`Bundle.module`/`Bundle.main` under Fuse unproven** | Android runs different vocabulary (invisible) | Compile the lexicon in as a Swift constant — no runtime lookup on either side (exit #4) |
| **`@_exported` semantics under Skip transpile/Fuse** | App-wide unqualified names may not survive | Fuse compiles the Swift core *natively* (not transpiled) so `@_exported` is standard SPM; verify in P0.3 scaffold, keep re-export iOS-side only |
| **Access-level churn** on `git mv` into a package | Build breaks on `internal` symbols crossing the module edge | Step 3 audit; promote entry points to `public` before wiring the app target |
| **Enum-placement coupling** (`MedEventChange` shared by extractor DTO + `MedicationEvent` @Model + `JournalMedEventDTO`) | Circular dep or duplicate type | Hoist all shared value enums to the `SquirlSignals` leaf (step 2) so DTO depends on Signals only |
| **`SquirlDesignSystem` value drift** after token extraction | iOS DS and Android tokens disagree | Token-parity test (exit #6); tokens are the single source, DS reads them |
| **Skip Fuse consuming a multi-product package** | Resolution/config friction | One umbrella package = one dep for Fuse; validate the four-product resolve in the P0.3 scaffold before committing the layout |

### Cross-phase dependencies & assumptions

*(Intra-Phase-1 couplings — DTO/token ownership, the P0.3-fork engine-agnosticism, upstream P0.1/P0.4 gating — are consolidated in the final section. Retained here: what Phase 2 consumes.)*

- Phase 2's STT bridge (P0.2 winner, JNI) produces a **`String` transcript** fed to `SquirlNoteExtraction.NLNoteExtractor.extract(from:)` → `NoteExtraction` → mapped into `JournalRecordingDTO` → persisted. The shared core exposes exactly this call chain; Phase 2 adds no new extractor API. ([ANDROID_PORT_PLAN.md](ANDROID_PORT_PLAN.md) Phase 2 step 6: "transcript → shared Swift extractor (native, via Fuse) → DTO → Room".)
- Phase 2's UI (SkipFuseUI) reads **`SquirlDesignTokens`** for Paper & Pollen values and builds Compose-mapped views; it does **not** import `SquirlDesignSystem`. P1-A's token extraction is the precondition that makes this a real package dep rather than P0.3's copied-source hack.
- The **transcript-style normalization** flagged at [ANDROID_PHASE0.md:605](ANDROID_PHASE0.md#L605) (transducer casing/punctuation ≠ Whisper) is a *Phase 1/2 normalization task feeding the extractor input* — it sits upstream of `SquirlNoteExtraction` and does not change the package boundary; assumed handled before the DTO is populated.
- The `JournalArchive` export `formatVersion` ([ExportService.swift:11-18](../app-four/Services/ExportService.swift#L11)) remains the cross-platform interchange hedge if sync is ever revived; the DTO carries no version field itself.

---

## P1-E — Data-flow & bridging architecture

*Phase 1 (Foundation) workstream — the **integration blueprint** the other four plug into: **P1-A** (shared Swift core / SPM extraction), **P1-B** (Android scaffold + CI), **P1-C** (Kotlin/Room or SkipSQL persistence), **P1-D** (Kotlin audio capture). Grounded in the live iOS code on `feat/038-icloud-sync` (file:line below) and the two Phase-planning docs ([ANDROID_PORT_PLAN.md](ANDROID_PORT_PLAN.md), [ANDROID_PHASE0.md](ANDROID_PHASE0.md)). External claims about Skip Fuse / SkipBridge carry cited URLs, verified 2026-07-22.*

### 1. Goal

Define the **seam** between the shared Swift core and the Android platform layers so that the record → transcribe → extract → persist state machine is written **once** (native Swift under Skip Fuse) and the four platform-specific layers (audio-in, STT engine, persistence, UI) plug into it through typed, `Sendable` DTO contracts. Concretely, P1-E delivers:

1. The **DTO boundary contracts** — which value types cross the seam, in which direction.
2. The **SkipBridge interop pattern** — what stays Swift-native (zero JNI cost) vs. what is bridged across JNI, and the annotation/`skip.yml` posture that governs it.
3. The **threading/concurrency model** — how Swift concurrency (`async/await`, `@MainActor`, `actor`) maps onto the Android main thread and Kotlin coroutines across the JNI boundary.
4. The **repository refactor** that decouples the shared orchestration from SwiftData `@Model`, without which nothing above ViewModels can be shared.

The non-goal: re-implementing the orchestration state machine in Kotlin. The fragile parts of this app — single-engine serialization, back-to-back check-in chaining, the pending-transcription drain, the 90 s timeout race — are exactly what we refuse to write twice.

### 2. iOS architecture to mirror (repo grounding)

The iOS app is **MVVM + a centralized Store + a DI composition root** ([ARCHITECTURE.md §1](engineering/ARCHITECTURE.md)). Four layers, three of which port to shared Swift and one (Views) to SkipFuseUI.

**Composition root & the 8-service bundle.** `AppDependencies` is the only place that constructs concrete services ([AppDependencies.swift:7-55](../app-four/Store/AppDependencies.swift#L7)). They are packed into an `@Observable @MainActor` bundle, `AppServices`, whose stored surface is exactly eight protocols ([AppServices.swift:10-17](../app-four/Store/AppServices.swift#L10)):

```
audioService · storageService · transcriptionService · aiModelService
summarizationService · connectivity · pendingTranscriptionService · exportService
```

The bundle is injected once at the view root via `.environment(AppDependencies.services)` ([SERVICES.md §Dependency Wiring](engineering/SERVICES.md)); ViewModels read it with `@Environment(AppServices.self)`. Two services are deliberately *outside* the bundle (`doseLogService`, `cloudSyncService`) — both are v1-out-of-scope for Android, so P1-E ignores them.

**The live write path (the thing being ported).** The primary loop is `CheckInViewModel` → its **composed** `ProcessingViewModel`, with `PendingTranscriptionServiceImpl` as the recovery drain:

- `CheckInViewModel` (`@Observable @MainActor`) owns recording state and composes a `ProcessingViewModel` at init ([CheckInViewModel.swift:73, 94-97](../app-four/ViewModels/CheckInViewModel.swift#L73)).
- `startRecording()` gates on disk + permission, starts `audioService.startRecording()`, and **preloads the STT model on a detached utility task** while the user speaks ([CheckInViewModel.swift:101-155](../app-four/ViewModels/CheckInViewModel.swift#L101), preload at L144).
- `stopRecording()` captures the prior in-flight transcription task and **chains** the new one after it so the single engine never runs two inferences at once ([CheckInViewModel.swift:158-182](../app-four/ViewModels/CheckInViewModel.swift#L158), chaining at L167 + L209-214).
- `attemptSave()` persists the audio, and **branches on model readiness**: if the model is absent it writes `status = .pendingTranscription` and stops; otherwise it kicks background transcription ([CheckInViewModel.swift:188-222](../app-four/ViewModels/CheckInViewModel.swift#L188), branch at L203-207).
- `transcribeInBackground()` consumes the transcription `AsyncStream` under a **90 s timeout race** (`withThrowingTaskGroup`), writing each segment onto the `@Model` on the MainActor, then hands off to `processingViewModel.processRawTranscription()` ([CheckInViewModel.swift:247-330](../app-four/ViewModels/CheckInViewModel.swift#L247), timeout race at L299-330, handoff at L261).
- `ProcessingViewModel.run()` fetches the `Recording` by `audioFileName`, calls `summarizationService.summarize()` → `SummaryResult`, then applies it via `recording.applySummary()` + `recording.setMedicationEvents()` ([ProcessingViewModel.swift:49-92](../app-four/ViewModels/ProcessingViewModel.swift#L49)).
- `PendingTranscriptionServiceImpl` is an `actor` that drains `.pendingTranscription` rows oldest-first through **the exact same transcribe → summarize → apply path**, coalescing re-entrant drains with an `isDraining` flag and re-resolving each row by `UUID` across the actor hop ([PendingTranscriptionServiceImpl.swift:17-145](../app-four/Services/PendingTranscriptionServiceImpl.swift#L17); id-across-hop at L57-63).

**Store & persistence.** `RecordingStore` is a `@MainActor` class wrapping a `ModelContext`, holding `recordings: [Recording]` and exposing `addRecording`/`save` ([RecordingStore.swift:5-65](../app-four/Store/RecordingStore.swift#L5)). The schema is six SwiftData `@Model` types in a two-configuration container (`Synced` vs `Local`) ([DATA_MODEL.md §Schema Overview](engineering/DATA_MODEL.md)); `Recording` carries **29 stored fields + 3 cascade relationships** ([DATA_MODEL.md §Entity Reference], reconciled in [ANDROID_PORT_PLAN.md Phase 1 step 3](ANDROID_PORT_PLAN.md)). The single writer for extraction output is `Recording.applySummary(_:fillOnly:)` + `setMedicationEvents(from:durationHours:context:)`.

**Concurrency posture.** ViewModels/Store are `@MainActor`; all SwiftData mutation is forced onto MainActor. Heavy work runs off it: `WhisperKitTranscriptionService`, `NetworkConnectivity`, `PendingTranscriptionServiceImpl`, `CloudSyncServiceImpl` are `actor`s; `NLNoteExtractor` is a `nonisolated` value type run via `Task.detached` ([ARCHITECTURE.md §5](engineering/ARCHITECTURE.md); [SERVICES.md §Design Principles pt.5](engineering/SERVICES.md)). Services return `AsyncStream<T>` for incremental work (`audioLevelStream`, transcription segments).

**The load-bearing observation.** Because the app was built for Swift 6 strict concurrency, **the service layer is already a clean `Sendable` DTO boundary.** Every protocol in [Protocols.swift](../app-four/Services/Protocols.swift) is `Sendable`; every value crossing it is a `Sendable` value type (`TranscriptionSegmentDTO`, `SummaryResult`, `NoteExtraction`, `MedEvent`, …). The `@Model` classes never cross a protocol boundary — they live behind `RecordingStore` and are mutated only on the MainActor. **This is the seam.** The Android port does not invent a boundary; it re-homes the far side of the boundary that already exists.

### 3. The shared-core ↔ platform seam (DTO contracts)

Under Skip Fuse the shared Swift compiles natively for Android via the official Swift Android SDK — *"Your Swift is compiled natively for Android using the official Swift SDK for Android"* (https://skip.dev/docs/modes/, verified 2026-07-22). So the seam is **not** a rewrite line; it is the set of protocol contracts where native Swift calls Android-platform code (and vice-versa). Everything on the Swift side of a contract is one native binary; only the contract's arguments/returns marshal across JNI.

#### 3.1 What lands on each side

| Piece | Side | Rationale |
|---|---|---|
| `NoteExtraction` package + `SquirlSignals` + lexicon + inflection table | **Shared Swift (native)** | Pure logic; P0.4 proves byte-parity. Zero JNI. |
| `NLSummarizationService` / `NLNoteExtractor` | **Shared Swift (native)** | CPU-bound value type; `NL*` deps fenced per P0.4. Zero JNI. |
| All DTOs (`TranscriptionSegmentDTO`, `SummaryResult`, `NoteExtraction`, `MedEvent`, `SleepEvent`, `SleepNote`, `MedEventChange`, `NetworkInterface`, `ModelDownloadFailure`) | **Shared Swift (native)** | Already `Sendable`; the extractor value types are also `Codable` ([NoteExtraction.swift:4,133,139,161,173](../app-four/Services/NoteExtraction/NoteExtraction.swift#L4)). The streaming `TranscriptionSegmentDTO` is `Sendable`-only, **not** `Codable` — persistence uses P1-A's distinct `JournalSegmentDTO` (`isError` → dropped; `language` ← default `"en"`). These are the values that marshal. |
| `CheckInViewModel`, `ProcessingViewModel`, `PendingTranscriptionServiceImpl` (orchestration state machine) | **Shared Swift (native)** *(after §3.3 refactor)* | The whole point: written once. Requires decoupling from `@Model`. |
| `RecordingStore` → a new `JournalRepository` protocol | **Contract (seam)** | Swift-side protocol; iOS impl wraps SwiftData, Android impl wraps Room-or-SkipSQL (P1-C). |
| `AudioRecordingService`, `AudioFileStorageService` | **Contract (seam)** | Swift protocol; Android impl is Kotlin `AudioRecord`/`MediaCodec` (P1-D), bridged in. |
| `TranscriptionService` | **Contract (seam)** | Swift protocol; Android impl is a **Swift wrapper over the C STT lib** (see §6), not Kotlin. |
| SwiftData `@Model` types (`Recording`, `TranscriptionSegment`, `MedicationEvent`, `RecordingTag`, `AppSettings`, `ModelMetadata`) | **iOS-only** | Replaced on Android by Room entities / SkipSQL rows (P1-C). Never cross the seam. |
| SwiftUI Views | **SkipFuseUI** (per-screen) | P0.3 / plan Phase 2 step 7. Out of P1-E scope except as the top JNI caller. |

#### 3.2 The DTO contracts, precisely

The contracts are the existing service protocols, unchanged. Their crossing types (all `Sendable`) are what SkipBridge marshals:

- **Transcription in:** `func transcribe(audioURL:) async throws -> AsyncStream<TranscriptionSegmentDTO>` — segment DTO is a 7-field `Sendable`-only struct (field 7 is `isError`, not `language`; [Protocols.swift:48-81](../app-four/Services/Protocols.swift#L48)). It is the *streaming* type, distinct from the persisted `JournalSegmentDTO`.
- **Extraction out:** `func summarize(rawTranscription:) async throws -> SummaryResult` — flat 14-field `Sendable` struct embedding `[MedEvent]` and an optional `NoteExtraction` ([Protocols.swift:168-189](../app-four/Services/Protocols.swift#L168)).
- **Audio level:** `var audioLevelStream: AsyncStream<Float>` and `stopRecording() async throws -> (fileURL: URL, duration: TimeInterval)` ([Protocols.swift:90-113](../app-four/Services/Protocols.swift#L90)).
- **Model lifecycle:** `download(_:) -> AsyncThrowingStream<Double, Error>`, `nonisolated func localPath(for:) -> URL?`, `status(for:) async -> ModelMetadata?` ([Protocols.swift:149-164](../app-four/Services/Protocols.swift#L149)).

**New contract to add (P1-E's own deliverable): `JournalRepository`.** `RecordingStore` today speaks `@Model` (`addRecording(_ recording: Recording)`, `recordings: [Recording]`). That cannot cross to Android. Introduce a `Sendable` `@MainActor` protocol that speaks **DTOs**:

```swift
@MainActor protocol JournalRepository: Sendable {
    func insert(_ dto: JournalRecordingDTO) throws -> RecordingID
    func update(_ id: RecordingID, _ mutate: (inout JournalRecordingDTO) -> Void) throws
    func recording(_ id: RecordingID) -> JournalRecordingDTO?
    func pendingTranscriptionIDsOldestFirst() -> [RecordingID]
    // …day/calendar queries as DTO reads…
}
```

The `JournalRecordingDTO` / `JournalSegmentDTO` / `JournalTagDTO` / `JournalMedEventDTO` value types are **owned by P1-A** (`SquirlModelDTO`) and are **new work that must respect pre-existing collisions**: [ExportService.swift:20,79](../app-four/Services/ExportService.swift#L20) already declares a `RecordingDTO` (27-field export subset, `status: String`, adds `audioBase64`, omits `cloudSyncStatus`/`isMockData`) and a `MedicationEventDTO` (11-field, no `isMockData`, String-typed `change`/`source`), and [Protocols.swift:48](../app-four/Services/Protocols.swift#L48) declares a *different* `TranscriptionSegmentDTO` (has `isError`, no `language`). Those export DTOs are proof the `@Model`→value-type mapping is *tractable* — a related-but-different shape, **not** the persistence contract itself; they stay app-target-local under their existing names. The iOS `JournalRepository` impl wraps `RecordingStore`/SwiftData; the Android impl wraps Room-or-SkipSQL (P1-C). The extraction writer (`applySummary`/`setMedicationEvents`) moves into repository-level DTO mutations so both platforms share it.

#### 3.3 The one required refactor (blocking, iOS-side, pre-extraction)

The orchestration VMs and the drain actor currently mutate `@Model` `Recording` directly on the MainActor (e.g. [CheckInViewModel.swift:314-316](../app-four/ViewModels/CheckInViewModel.swift#L314), [PendingTranscriptionServiceImpl.swift:107-133](../app-four/Services/PendingTranscriptionServiceImpl.swift#L107), [ProcessingViewModel.swift:84-90](../app-four/ViewModels/ProcessingViewModel.swift#L84)). To share them, **swap every `@Model` touch for a `JournalRepository` DTO write, keyed by `RecordingID`.** This is a mechanical but wide edit (the id-across-actor-hop pattern in the drain actor already models it — it deliberately passes `UUID`, not the `@Model`, across the hop). Done first on iOS behind the new protocol with the SwiftData impl, it is behavior-preserving **iff every mutation site is serialized on the MainActor and no two live `@Model` aliases coexist** — reference semantics (live `@Model` alias) become value semantics (DTO copy-in/out), so a concurrent writer between a DTO read and its write-back is a lost update. Two required steps before relying on the existing suite: (1) **audit the CheckIn/drain overlap window** for coexisting mutators of the same `RecordingID`; (2) add a **targeted lost-update test** (two interleaved `update` closures on one id; both mutations must land).

### 4. SkipBridge interop pattern

**SkipBridge is the JNI Swift↔Kotlin interop layer, not the UI mapper** (SkipFuseUI→SkipUI does UI; https://skip.dev/docs/modules/skip-bridge/, https://skip.dev/docs/modes/, verified 2026-07-22). Two facts govern our design:

1. **Bridging is opt-in per module and generates the JNI glue.** *"When `bridging: true` is set in a module's `skip.yml`, the Skip build plugin automatically generates the JNI glue code that calls into SkipBridge — no manual integration is required"* (https://skip.dev/docs/modules/skip-bridge/). We hand-write no JNI; we annotate the seam.
2. **The marshalling is typed and structural.** *"automatic marshalling between Swift and Kotlin/Java types (e.g. `Array` ↔ `List`, `Dictionary` ↔ `Map`, `Date` ↔ `java.util.Date`)"*; Swift structs conforming to `BridgedToKotlin` are projected to Kotlin, object identity carried by an opaque `Int64` `SwiftObjectPointer` with reference-counted lifecycle; `AnyDynamicObject` gives Swift `@dynamicMemberLookup` access to arbitrary Kotlin objects (https://skip.dev/docs/modules/skip-bridge/).

**Native-vs-bridged split for our seam:**

| Category | Bridged across JNI? | Why |
|---|---|---|
| DTO structs (`TranscriptionSegmentDTO`, `SummaryResult`, `MedEvent`, …) | **Marshalled by value** when they cross a bridged contract | `Sendable` value types → `BridgedToKotlin` projection; collections auto-convert (`[MedEvent]` ↔ `List`). |
| Extractor + summarizer + orchestration VMs | **No** — pure Swift-to-Swift | Entirely inside the native Swift binary; the extractor never touches Kotlin, so its `transcript → NoteExtraction` path has **zero** bridge hops. |
| `JournalRepository` (Android=Room, if Path B) | **Yes** — Swift calls Kotlin | Room is Kotlin; the impl is bridged in and marshals DTOs in/out (P1-C). Path A (SkipSQL) makes this impl Swift-side — no JNI at the persist leaf. |
| `AudioRecordingService` (Android=`AudioRecord`) | **Yes** — Swift calls Kotlin | Platform capture is Kotlin; PCM crosses as a direct `ByteBuffer` per the plan's JNI standard (P1-D). |
| `TranscriptionService` (Android STT) | **No JNI to Kotlin** — Swift↔C | whisper.cpp / sherpa-onnx expose a **C API**; drive it from Swift via **C interop** (as WhisperKit is driven today, minus CoreML), keeping the transcript in Swift as `TranscriptionSegmentDTO`. See §6. |
| Compose UI → VMs | **Yes** — Kotlin calls Swift | SkipFuseUI is the top caller; the bridged VM API is what Compose invokes. |

**Rule of thumb for P1-E:** annotate a module `bridging: true` **only** where a real Kotlin/C-platform boundary exists (repository under Path B, audio). The core logic modules stay bridging-free so the extractor/summarizer/orchestration compile as one native island with no marshalling tax.

### 5. Threading / concurrency across the JNI boundary

Swift concurrency runs **natively** on Android under Fuse (the Swift runtime is in the cross-compiled `.so`), so `async/await`, actors, and structured concurrency behave as on iOS *within* the Swift island. The bridge maps the boundary crossings:

- **`async` ↔ `suspend`.** *"Swift async functions and properties bridge to Kotlin suspend functions"* (https://skip.dev/docs/modules/skip-bridge/). So `summarize(...) async` and `transcribe(...) async` present to Kotlin/Compose as suspend functions — no callback shims.
- **`AsyncStream`/`AsyncThrowingStream` ↔ `Flow`.** *"`AsyncStream`/`AsyncThrowingStream` bridge to `kotlinx.coroutines.flow.Flow`"* (ibid.). This is why the design keeps `audioLevelStream`, the transcription segment stream, and `download(_:)` progress as streams: each maps to a `Flow` for a Kotlin producer (audio, download) or consumer (a Compose progress view) at no extra cost.
- **`@MainActor` ↔ Android main thread.** SkipFuseUI runs the `@Observable @MainActor` VMs on the Android UI thread, so `CheckInViewModel`/`ProcessingViewModel` MainActor isolation is preserved; the DTO writes that were "MainActor SwiftData mutations" become "MainActor `JournalRepository` calls" on the same thread contract.
- **`actor` isolation across the drain.** `PendingTranscriptionServiceImpl`'s `actor` + `isDraining` coalescing runs natively; it re-resolves rows by `RecordingID` on the MainActor exactly as today ([PendingTranscriptionServiceImpl.swift:57-63](../app-four/Services/PendingTranscriptionServiceImpl.swift#L57)) — no bridge is involved because the repository call is Swift→Swift(→Kotlin-Room only at the leaf, and only under Path B).
- **Off-main heavy work.** `Task.detached(priority: .utility)` model preload ([CheckInViewModel.swift:144](../app-four/ViewModels/CheckInViewModel.swift#L144)) and the detached extractor run stay off the UI thread on Android too. The single-engine serialization (chaining prior transcription, actor drain) is a Swift-concurrency invariant that survives untouched — **this is the payoff of sharing the state machine rather than reimplementing it in coroutines.**

**Threading hazards to hold (for P1-C / P1-D):**
- A Kotlin producer feeding a Swift `AsyncStream` (audio level, PCM) crosses JNI on every emit — batch/`ByteBuffer` PCM (plan's standard), don't marshal per-sample structs.
- JNI-attached threads: any Kotlin thread that calls into Swift must be JVM-attached; SkipBridge's generated glue handles the standard cases, but a self-spawned native STT thread returning into Kotlin must attach/detach — a P2 review item, flagged here.
- The bring-up shim's `NewStringUTF` is ASCII-only and must **not** carry into the real transcript path — transcripts return as UTF-8 `jbyteArray` (plan Phase 2 step 5; [ANDROID_PHASE0.md §3.6a note](ANDROID_PHASE0.md)) *only if* the STT lib is Kotlin-driven; the §6 Swift-C-interop route sidesteps it.

### 6. End-to-end data-flow (record → persist) across the seam

Legend: `[S]` native Swift · `[K]` Kotlin/Compose/Android platform · `[C]` C library · `‖` JNI marshalling hop. (Persist leaf shown as Room = Path B; under Path A/SkipSQL the persist call is Swift→Swift with no `‖` at that leaf.)

```
[K] Compose check-in screen
      │  user taps Record   ‖ (Kotlin→Swift, suspend)
      ▼
[S] CheckInViewModel.startRecording()            @MainActor, native
      │  disk+permission gate; spawn detached model-preload
      │  audioService.startRecording()   ‖ (Swift→Kotlin)
      ▼
[K] AudioRecord/MediaCodec (P1-D): 16kHz mono PCM → AAC/.m4a
      │  audioLevelStream  ── Flow<Float> ‖──►  [S] level gate (VoiceOver/UI)
      │  user taps Stop     ‖
      ▼
[S] CheckInViewModel.stopRecording() → attemptSave()   @MainActor, native
      │  storageService.saveRecording(...)  ‖ (Swift→Kotlin file store, P1-D)
      │  repo.insert(JournalRecordingDTO)    ‖ (Swift→Kotlin Room, P1-C — Path B)
      │
      ├─ model NOT ready → repo.update(id){ $0.status = .pendingTranscription }; STOP
      │        (later: PendingTranscriptionService.drainIfModelReady() replays this exact path)
      │
      └─ model ready → transcriptionTask (chained after prior, single-engine serialize)
             ▼
[S] transcribeInBackground(id)  — 90s withThrowingTaskGroup timeout race, native
      │  transcriptionService.transcribe(audioURL)  →  AsyncStream<TranscriptionSegmentDTO>
      │        │
      │        ▼
[S] AndroidWhisperService (Swift wrapper)   ── C interop, NO JNI-to-Kotlin ──►
[C]      whisper.cpp / sherpa-onnx  (PCM in ‖ from [K] capture as direct ByteBuffer)
      │        ◄── segments back into Swift as TranscriptionSegmentDTO (stays in-Swift)
      │  per segment: repo.update(id){ $0.transcript = seg.text; $0.status = .transcribing }  ‖ Room
      ▼
[S] ProcessingViewModel.processRawTranscription(text) → run()    @MainActor, native
      │  summarizationService.summarize(text)  →  SummaryResult      (Swift→Swift)
      │        ▼
[S]      NLSummarizationService → NLNoteExtractor  (Task.detached, off-main, native)
      │        transcript(String) ──► NoteExtraction / [MedEvent]     ZERO JNI hops
      │  ◄── SummaryResult
      │  apply: repo.update(id){ applySummary + setMedicationEvents }  ‖ Room; status=.completed
      ▼
[K] Compose day-card / calendar observes repo (Flow) → renders entry
```

**Reading of the diagram.** Exactly three JNI boundary classes exist: (A) Compose↔VM at the top (suspend/Flow), (B) VM/services↔Android platform for audio + Room persistence (Path B), and (C) audio PCM into the STT lib. The **entire transcribe→extract→apply core is one native Swift island** — the transcript reaches the extractor and the extractor's output reaches the repository DTO without a single Swift↔Kotlin marshalling hop. The only bytes that must cross efficiently are PCM (in, `ByteBuffer`) and the final DTO writes (out, to persistence). This is the design's central efficiency claim.

### 7. Exit criteria (binary)

P1-E is **done** when all hold:

1. **`JournalRepository` protocol merged on iOS**, `RecordingStore`/SwiftData is its sole impl, and `CheckInViewModel` + `ProcessingViewModel` + `PendingTranscriptionServiceImpl` reference **no `@Model` type directly** — verified by grep for `Recording`/`MedicationEvent` `@Model` usage in `ViewModels/` + the drain actor returning empty for the mutation sites.
2. **Existing iOS test suite green** after the refactor with zero behavior change (the refactor is proven pure before Android exists).
3. **The DTO seam inventory is written**: every type crossing the seam is listed as (a) `Sendable`, and (b) either `Codable` value or a bridged protocol — no `@Model`, `ModelContext`, or SwiftUI type appears in any seam signature.
4. **A `bridging:true` map exists**: the exact module list that must be JNI-bridged (audio; repository under Path B) vs. the native-only core (extractor, summarizer, orchestration VMs, DTOs), consistent with §4.
5. **One round-trip smoke on the Fuse scaffold**: Compose calls a bridged shared-Swift function that returns a `SummaryResult`-shaped DTO and renders one field — proving async→suspend and struct marshalling on-device. **Required; gates on P1-B-scaffold** (runs after the scaffold lands, before G1 — this is the `P1-E-smoke` row in the at-a-glance table).
6. **A reusable `JournalRepository` conformance test suite exists** (black-box, protocol-level: insert / update-mutate / pending-oldest-first / cascade) and passes against the SwiftData impl — P1-C must pass the same suite unmodified against the Path-A/B impl.

### 8. Risks & effort

| Risk | Impact | Mitigation |
|---|---|---|
| **@Model decoupling is wider than it looks.** VMs mutate `Recording` at many sites; `setMedicationEvents` also passes a `ModelContext`. | The refactor sprawls; a missed site keeps an iOS-only type in the shared core, breaking the Android compile. | Do it **iOS-first behind the protocol**, SwiftData impl unchanged in behavior; the existing suite is the gate. The drain actor's id-across-hop pattern is the template. |
| **SkipBridge struct-projection limits.** Deeply nested/optional-heavy DTOs (`SummaryResult` embeds `NoteExtraction` with ~25 fields) may hit marshalling edge cases. | A DTO won't project cleanly; ad-hoc flattening needed. | Keep bridged DTOs flat + `Codable`; if a type resists projection, marshal it as a JSON `String`/`jbyteArray` at the seam (the app already JSON-encodes `NoteExtraction` for storage — [DATA_MODEL.md §JSON-Encoded Fields](engineering/DATA_MODEL.md)). |
| **Per-emit JNI cost on streams.** `audioLevelStream` and PCM emits crossing JNI frequently. | UI jank / thermal. | Level stream stays low-rate; PCM crosses as batched direct `ByteBuffer`, never per-sample DTOs. |
| **STT driven from Kotlin instead of Swift-C.** Would force transcript back across JNI as `jbyteArray` and split the core island. | Loses the "one native island" property; re-introduces the `NewStringUTF` UTF-8 footgun. | **Decide in P1-E: drive the C STT lib from Swift via C interop** (mirrors WhisperKit today). Keep TranscriptionService's impl Swift-side. |
| **`JournalRepository` semantics drift between SwiftData and Room/SkipSQL.** Cascade deletes, sort-by-`startTime`, upsert vs replace. | Subtle data bugs Android-only. | P1-C implements to the same contract tests; the repository protocol is the shared spec, exercised by the golden-fixture suite (P0.4) at the persist boundary. |

**Effort (solo dev + agent):** the iOS `@Model`→`JournalRepository` refactor + DTO seam inventory is the bulk — **~4–5 days** including re-greening the suite. The `bridging:true` map + on-scaffold round-trip smoke is **~1 day** (gated on P0.3). Total **~5–6 eng-days**, front-loaded on the pure-Swift refactor that carries **zero Android risk** (it ships value to iOS immediately as cleaner MVVM/testability).

### Cross-phase dependencies & assumptions

*(Upstream G0 gating and the intra-Phase-1 contract couplings — P1-A/C/D/B plug into this seam — are consolidated in the final section. Retained here: how Phase 2 wires STT + extractor into the seam.)*

- **STT (Phase 2 step 5):** the P0.2-winning engine is integrated **as a Swift `TranscriptionService` impl wrapping the engine's C API via Swift C interop** — *not* a Kotlin service. This keeps the transcript in-Swift as `TranscriptionSegmentDTO`, preserves the single-engine serialization/`unloadModel` invariants the shared VMs already enforce ([CheckInViewModel.swift:158-214](../app-four/ViewModels/CheckInViewModel.swift#L158)), and confines JNI to PCM-in only. Model delivery (asset pack) and the `localPath(for:)`/model-readiness branch ([CheckInViewModel.swift:203](../app-four/ViewModels/CheckInViewModel.swift#L203)) map straight onto the existing `AIModelService` contract — the pending-transcription drain works on Android unchanged because it is shared native Swift. Phase 2 P2-A implements exactly this split: the **whisper.cpp branch is Swift-C-interop** (transcript stays in-Swift, JNI = PCM-in only), while the **sherpa-onnx branches may adopt the official Kotlin AAR as a pragmatic adapter — a recorded deviation crossing the SkipBridge seam** (the audited JNI rules still govern the PCM-in seam).
- **Extractor (Phase 2 step 6):** wired transcript → shared Swift extractor (native, via Fuse) → DTO → repository. **This path has no new bridge**: it is Swift→Swift end to end, and the golden-fixture suite (P0.4) runs at the DTO output in Android CI as the parity guarantee. Phase 2's only integration work here is confirming the DTO write lands in persistence identically to SwiftData — i.e. exercising the `JournalRepository` contract P1-E defined.
- **Standing assumption:** the whole blueprint presumes the orchestration state machine is worth sharing rather than re-coding in Kotlin. If a future finding forces those VMs iOS-only (e.g. an unbridgeable `@Observable`/SkipFuseUI limit), the fallback is a Kotlin re-implementation of the state machine against the same `JournalRepository`/`TranscriptionService`/`SummarizationService` contracts — the DTO seam still holds; only the orchestrator is duplicated.

---

## P1-C — Persistence layer

### Goal

Stand up the Android persistence layer that stores the app's core loop (record → transcribe → extract → journal → calendar/detail). The schema must be a **faithful, byte-compatible mirror of the real SwiftData model** — `Recording` (29 stored fields) plus its 3 cascade child tables (`TranscriptionSegment`, `RecordingTag`, `MedicationEvent`) — so a note logged on either platform is representable on the other and any future interchange (`JournalArchive` export, [ANDROID_PORT_PLAN.md:7](ANDROID_PORT_PLAN.md#L7)) round-trips losslessly. Greenfield: no migration to author, but the schema is **versioned from 1** so a v2 migration path exists. This layer implements the `JournalRepository` contract **owned by P1-E** over the DTO value-types **owned by P1-A**.

This section carries the one unresolved fork from Phase 0. It branches on the G0 outcome and does not pre-decide it.

### The G0 fork (how this section branches)

P0.3 §5 ([ANDROID_PHASE0.md:801-822](ANDROID_PHASE0.md#L801)) leaves persistence as an **owner decision at G0**, delivered by the spike as a *recommendation + cost sheet*, not a settled choice:

- **G0 picks SkipSQL** (Candidate A, recommended) → build **Path A** below. One Swift persistence core for both platforms; iOS migrates SwiftData → SkipSQL, which **abandons the SwiftData+CloudKit path feature-038 iCloud-sync is built on** (cost sheet below).
- **G0 picks Room** (Candidate B, fallback) → build **Path B** below. iOS keeps SwiftData; Android gets a Kotlin Room store; DTOs mediate the SkipBridge seam. Doubled persistence surface, but zero disturbance to 038.

The binary that forces Path B: **SkipSQL fails to link or round-trip a row under `mode: 'native'`** in the P0.3 spike ([ANDROID_PHASE0.md:857](ANDROID_PHASE0.md#L857)). Per the C-interop guarantee it should not — SkipSQL talks to SQLite3's C API directly on both Darwin and Android/Fuse ([skip-sql README](https://github.com/skiptools/skip-sql), quoted at [ANDROID_PHASE0.md:805](ANDROID_PHASE0.md#L805)) — but the fork is kept honest until the round-trip is observed on device.

**Framing fact (not opinion):** SwiftData is **unsupported on Android** under Skip ([ANDROID_PHASE0.md:820](ANDROID_PHASE0.md#L820)). Skip's own grain is a shared Swift persistence layer (SkipSQL), *not* a SwiftData(iOS)+Room(Android) split. Path A swims with the grain; Path B swims against it. Everything downstream of the store (extractor DTOs, insights, day-view) is schema-shape-agnostic and identical on both paths.

### Real model inventory — 29 fields + 3 relationships

Counted from source this session. Field count reconciles to the plan's "29 stored / 3 relationships" ([ANDROID_PORT_PLAN.md:32](ANDROID_PORT_PLAN.md#L32)).

**`Recording` — 29 stored properties** ([Recording.swift:9-46](../app-four/Models/Recording.swift#L9)). SwiftData stores enums by `rawValue` (String); all `String?`/`Date?`/`Double?` are true nullable columns. `TimeInterval` = `Double`, `Int64` = 64-bit int.

| # | Field | Swift type | Line | SQLite affinity | Nullable |
|---|-------|-----------|------|-----------------|----------|
| 1 | `id` | `UUID` | [L9](../app-four/Models/Recording.swift#L9) | TEXT (uuid string) | no · **merge key** |
| 2 | `createdAt` | `Date` | [L10](../app-four/Models/Recording.swift#L10) | INTEGER (epoch ms) | no |
| 3 | `updatedAt` | `Date` | [L11](../app-four/Models/Recording.swift#L11) | INTEGER | no |
| 4 | `audioFileName` | `String` | [L12](../app-four/Models/Recording.swift#L12) | TEXT | no (`""`) |
| 5 | `duration` | `TimeInterval` | [L13](../app-four/Models/Recording.swift#L13) | REAL | no (`0`) |
| 6 | `fileSize` | `Int64` | [L14](../app-four/Models/Recording.swift#L14) | INTEGER | no (`0`) |
| 7 | `status` | `RecordingStatus` | [L15](../app-four/Models/Recording.swift#L15) | TEXT (rawValue) | no (`placeholder`) |
| 8 | `fullTranscriptText` | `String` | [L21](../app-four/Models/Recording.swift#L21) | TEXT | no (`""`) |
| 9 | `title` | `String` | [L22](../app-four/Models/Recording.swift#L22) | TEXT | no (`"Untitled"`) |
| 10 | `isFavorite` | `Bool` | [L23](../app-four/Models/Recording.swift#L23) | INTEGER (0/1) | no (`false`) |
| 11 | `cloudSyncStatus` | `String?` | [L24](../app-four/Models/Recording.swift#L24) | TEXT | yes |
| 12 | `summary` | `String?` | [L27](../app-four/Models/Recording.swift#L27) | TEXT | yes |
| 13 | `summaryStatus` | `String?` | [L28](../app-four/Models/Recording.swift#L28) | TEXT | yes |
| 14 | `topicTagsJSON` | `String?` | [L29](../app-four/Models/Recording.swift#L29) | TEXT (JSON blob) | yes |
| 15 | `summaryGeneratedAt` | `Date?` | [L30](../app-four/Models/Recording.swift#L30) | INTEGER | yes |
| 16 | `hasMedication` | `Bool` | [L33](../app-four/Models/Recording.swift#L33) | INTEGER | no (`false`) |
| 17 | `medicationInfo` | `String?` | [L34](../app-four/Models/Recording.swift#L34) | TEXT | yes |
| 18 | `energyLevel` | `String?` | [L35](../app-four/Models/Recording.swift#L35) | TEXT | yes |
| 19 | `focusLevel` | `String?` | [L36](../app-four/Models/Recording.swift#L36) | TEXT | yes |
| 20 | `mood` | `String?` | [L37](../app-four/Models/Recording.swift#L37) | TEXT | yes |
| 21 | `sleepHours` | `Double?` | [L38](../app-four/Models/Recording.swift#L38) | REAL | yes |
| 22 | `sleepQuality` | `String?` | [L39](../app-four/Models/Recording.swift#L39) | TEXT | yes |
| 23 | `summaryBulletsJSON` | `String?` | [L40](../app-four/Models/Recording.swift#L40) | TEXT (JSON blob) | yes |
| 24 | `noteExtractionJSON` | `String?` | [L41](../app-four/Models/Recording.swift#L41) | TEXT (JSON blob) | yes |
| 25 | `sideEffectsJSON` | `String?` | [L42](../app-four/Models/Recording.swift#L42) | TEXT (JSON blob) | yes |
| 26 | `sleepEventJSON` | `String?` | [L43](../app-four/Models/Recording.swift#L43) | TEXT (JSON blob) | yes |
| 27 | `emotionsJSON` | `String?` | [L44](../app-four/Models/Recording.swift#L44) | TEXT (JSON blob) | yes |
| 28 | `sleepLevelValue` | `String?` | [L45](../app-four/Models/Recording.swift#L45) | TEXT | yes |
| 29 | `isMockData` | `Bool` | [L46](../app-four/Models/Recording.swift#L46) | INTEGER | no (`false`) |

> The six `…JSON` columns (14, 23–27) hold `JSONEncoder`-serialized value types, not normalized rows — they are opaque TEXT to the DB. **Cross-platform byte-parity depends on canonical JSON encoding** (see P0.4 §5 "making output canonical", [ANDROID_PHASE0.md:993](ANDROID_PHASE0.md#L993)); the persistence layer stores whatever the extractor emits and must not re-serialize.

**3 relationships — all `deleteRule: .cascade`, all optional arrays** ([Recording.swift:60-69](../app-four/Models/Recording.swift#L60)). CloudKit forces optional relationships; read via `?? []`.

| Relationship | Type | Rule | Line |
|--------------|------|------|------|
| `segments` | `[TranscriptionSegment]?` | cascade | [L60-61](../app-four/Models/Recording.swift#L60) |
| `correctionTags` | `[RecordingTag]?` | cascade | [L63-64](../app-four/Models/Recording.swift#L63) |
| `medicationEvents` | `[MedicationEvent]?` | cascade | [L68-69](../app-four/Models/Recording.swift#L68) |

**Child `TranscriptionSegment` — 7 fields + FK** ([TranscriptionSegment.swift:7-15](../app-four/Models/TranscriptionSegment.swift#L7)): `id: UUID`, `text: String`, `startTime: TimeInterval`, `endTime: TimeInterval`, `isFinal: Bool` (`true`), `confidence: Double?`, `language: String` (`"en"`), inverse `recording`. **Natural sort key: `startTime`** ([ANDROID_PORT_PLAN.md:32](ANDROID_PORT_PLAN.md#L32)).

**Child `RecordingTag` — 6 fields + FK** ([RecordingTag.swift:20-27](../app-four/Models/RecordingTag.swift#L20)): `id: UUID`, `name: String`, `category: String` (`TagCategory` rawValue: mood/energy/focus/medication/emotions), `source: String` (`TagSource` rawValue: nlp/user/userCorrected), `confidence: Double?`, `createdAt: Date`, inverse `recording`. Sort key: `createdAt`.

**Child `MedicationEvent` — 12 fields + FK** ([MedicationEvent.swift:11-32](../app-four/Models/MedicationEvent.swift#L11)): `id: UUID`, `name: String`, `dose: String?`, `takenAt: Date`, `taken: Bool` (`true`), `quantity: Double?`, `durationHours: Double` (`10.0`), `change: MedEventChange?` (regular/started/stopped, [NoteExtraction.swift:133](../app-four/Services/NoteExtraction/NoteExtraction.swift#L133)), `timeLabel: String?`, `source: Source` (manual/transcript, [MedicationEvent.swift:36](../app-four/Models/MedicationEvent.swift#L36)), `createdAt: Date`, `isMockData: Bool` (`false`), inverse `recording`. Sort key: `takenAt`.

**Enums stored as String rawValue:** `RecordingStatus` = recorded/transcribing/pendingTranscription/completed/failed/placeholder ([AppEnums.swift:5](../app-four/Models/AppEnums.swift#L5)); `MedicationEvent.Source` (hoisted to flat `MedicationEventSource` in SquirlSignals, P1-A step 2) = manual/transcript; `MedEventChange` = regular/started/stopped. Persist rawValue only — never the ordinal — so the string survives enum reordering.

---

### Path A — SkipSQL schema (recommended)

One Swift persistence core, compiled natively into the Fuse app and reused verbatim on iOS. Authoritative artifact is the **DDL**; the `SQLCodable` structs are the typed mapping layer over it.

**Schema version pin (SQLite `user_version`, greenfield = 1):**

```swift
import SkipSQL

enum SquirlSchema {
    static let version: Int32 = 1

    static func migrate(_ db: SQLContext) throws {
        let current = try db.userVersion            // PRAGMA user_version
        if current < 1 { try createV1(db); try db.setUserVersion(1) }
        // future: if current < 2 { try migrateV1toV2(db); try db.setUserVersion(2) }
    }
}
```

**DDL — 1 parent + 3 child tables, FKs ON DELETE CASCADE (mirrors SwiftData `.cascade`):**

```sql
PRAGMA foreign_keys = ON;   -- REQUIRED per-connection; SQLite defaults OFF, cascade is silently dead without it

CREATE TABLE IF NOT EXISTS recording (
    id                  TEXT    PRIMARY KEY NOT NULL,   -- UUID string, app-level merge key
    createdAt           INTEGER NOT NULL,               -- epoch millis
    updatedAt           INTEGER NOT NULL,
    audioFileName       TEXT    NOT NULL DEFAULT '',
    duration            REAL    NOT NULL DEFAULT 0,
    fileSize            INTEGER NOT NULL DEFAULT 0,
    status              TEXT    NOT NULL DEFAULT 'placeholder',
    fullTranscriptText  TEXT    NOT NULL DEFAULT '',
    title               TEXT    NOT NULL DEFAULT 'Untitled',
    isFavorite          INTEGER NOT NULL DEFAULT 0,     -- Bool 0/1
    cloudSyncStatus     TEXT,
    summary             TEXT,
    summaryStatus       TEXT,
    topicTagsJSON       TEXT,
    summaryGeneratedAt  INTEGER,
    hasMedication       INTEGER NOT NULL DEFAULT 0,
    medicationInfo      TEXT,
    energyLevel         TEXT,
    focusLevel          TEXT,
    mood                TEXT,
    sleepHours          REAL,
    sleepQuality        TEXT,
    summaryBulletsJSON  TEXT,
    noteExtractionJSON  TEXT,
    sideEffectsJSON     TEXT,
    sleepEventJSON      TEXT,
    emotionsJSON        TEXT,
    sleepLevelValue     TEXT,
    isMockData          INTEGER NOT NULL DEFAULT 0
);   -- 29 columns

CREATE TABLE IF NOT EXISTS transcription_segment (
    id           TEXT    PRIMARY KEY NOT NULL,
    recordingId  TEXT    NOT NULL REFERENCES recording(id) ON DELETE CASCADE,
    text         TEXT    NOT NULL DEFAULT '',
    startTime    REAL    NOT NULL DEFAULT 0,
    endTime      REAL    NOT NULL DEFAULT 0,
    isFinal      INTEGER NOT NULL DEFAULT 1,
    confidence   REAL,
    language     TEXT    NOT NULL DEFAULT 'en'
);
CREATE INDEX IF NOT EXISTS idx_segment_recordingId ON transcription_segment(recordingId);

CREATE TABLE IF NOT EXISTS recording_tag (
    id           TEXT    PRIMARY KEY NOT NULL,
    recordingId  TEXT    NOT NULL REFERENCES recording(id) ON DELETE CASCADE,
    name         TEXT    NOT NULL DEFAULT '',
    category     TEXT    NOT NULL DEFAULT '',    -- TagCategory rawValue
    source       TEXT    NOT NULL DEFAULT '',    -- TagSource rawValue
    confidence   REAL,
    createdAt    INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_tag_recordingId ON recording_tag(recordingId);

CREATE TABLE IF NOT EXISTS medication_event (
    id            TEXT    PRIMARY KEY NOT NULL,
    recordingId   TEXT    REFERENCES recording(id) ON DELETE CASCADE,  -- NULLABLE: standalone manual doses have no recording
    name          TEXT    NOT NULL DEFAULT '',
    dose          TEXT,
    takenAt       INTEGER NOT NULL,
    taken         INTEGER NOT NULL DEFAULT 1,
    quantity      REAL,
    durationHours REAL    NOT NULL DEFAULT 10.0,
    change        TEXT,                            -- MedEventChange rawValue, nullable
    timeLabel     TEXT,
    source        TEXT    NOT NULL DEFAULT 'manual',
    createdAt     INTEGER NOT NULL,
    isMockData    INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_medevent_recordingId ON medication_event(recordingId);
```

> `medication_event.recordingId` is **nullable** by design — `source == .manual` standalone doses carry `recording == nil` ([MedicationEvent.swift:8, 30-32](../app-four/Models/MedicationEvent.swift#L8)). All other FKs are NOT NULL.

**`SQLCodable` typed row structs** (SkipSQL ships `SQLCodable` + `SQLPredicate` querying, [ANDROID_PHASE0.md:816](ANDROID_PHASE0.md#L816)). Value types, not classes — no SwiftData, cross-platform:

```swift
import SkipSQL
import Foundation

struct RecordingRow: SQLCodable, Identifiable, Sendable {
    static let table = SQLTable(name: "recording")

    var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var audioFileName: String = ""
    var duration: Double = 0
    var fileSize: Int64 = 0
    var status: String = RecordingStatus.placeholder.rawValue   // rawValue at the boundary
    var fullTranscriptText: String = ""
    var title: String = "Untitled"
    var isFavorite: Bool = false
    var cloudSyncStatus: String?
    var summary: String?
    var summaryStatus: String?
    var topicTagsJSON: String?
    var summaryGeneratedAt: Date?
    var hasMedication: Bool = false
    var medicationInfo: String?
    var energyLevel: String?
    var focusLevel: String?
    var mood: String?
    var sleepHours: Double?
    var sleepQuality: String?
    var summaryBulletsJSON: String?
    var noteExtractionJSON: String?
    var sideEffectsJSON: String?
    var sleepEventJSON: String?
    var emotionsJSON: String?
    var sleepLevelValue: String?
    var isMockData: Bool = false
}

struct TranscriptionSegmentRow: SQLCodable, Identifiable, Sendable {
    static let table = SQLTable(name: "transcription_segment")
    var id: UUID
    var recordingId: UUID
    var text: String = ""
    var startTime: Double = 0
    var endTime: Double = 0
    var isFinal: Bool = true
    var confidence: Double?
    var language: String = "en"
}

struct RecordingTagRow: SQLCodable, Identifiable, Sendable {
    static let table = SQLTable(name: "recording_tag")
    var id: UUID
    var recordingId: UUID
    var name: String = ""
    var category: String = ""
    var source: String = ""
    var confidence: Double?
    var createdAt: Date
}

struct MedicationEventRow: SQLCodable, Identifiable, Sendable {
    static let table = SQLTable(name: "medication_event")
    var id: UUID
    var recordingId: UUID?          // nullable FK
    var name: String = ""
    var dose: String?
    var takenAt: Date
    var taken: Bool = true
    var quantity: Double?
    var durationHours: Double = 10.0
    var change: String?             // MedEventChange rawValue
    var timeLabel: String?
    var source: String = "manual"
    var createdAt: Date
    var isMockData: Bool = false
}
```

**Store API — upsert + ordered reads** (SkipSQL uses SQLite's native `ON CONFLICT` upsert; children read with an explicit `ORDER BY` because relationship order is not implied):

```swift
@MainActor
final class RecordingStore {
    private let db: SQLContext

    init(path: String) throws {
        db = try SQLContext(path: path)
        try db.exec("PRAGMA foreign_keys = ON")   // per-connection, every open
        try SquirlSchema.migrate(db)
    }

    // Upsert = INSERT … ON CONFLICT(id) DO UPDATE. Never DELETE+INSERT: a delete
    // would cascade and wipe the recording's segments/tags/medication events.
    func save(_ r: RecordingRow) throws {
        try db.upsert(r, onConflict: [\.id])
    }

    func segments(of recordingId: UUID) throws -> [TranscriptionSegmentRow] {
        try db.select(TranscriptionSegmentRow.self,
                      where: \.recordingId == recordingId,
                      orderBy: [.asc(\.startTime)])            // explicit sort
    }

    func medicationEvents(of recordingId: UUID) throws -> [MedicationEventRow] {
        try db.select(MedicationEventRow.self,
                      where: \.recordingId == recordingId,
                      orderBy: [.asc(\.takenAt)])
    }
}
```

> The `SQLCodable`/`SQLPredicate`/`upsert` method *shapes* are per the skip-sql README ([ANDROID_PHASE0.md:816](ANDROID_PHASE0.md#L816)); **pin the exact signatures against the skip-sql version resolved in P0.1 at implementation time** — the DDL above is version-independent and authoritative regardless.

---

### Path B — Room schema (fallback)

Only if SkipSQL fails the `mode: 'native'` round-trip. Kotlin store on Android, DTOs across SkipBridge; iOS keeps SwiftData untouched. Four Room specifics ([Room `@Upsert`](https://developer.android.com/reference/androidx/room/Upsert), [`OnConflictStrategy.REPLACE`](https://developer.android.com/reference/androidx/room/OnConflictStrategy#REPLACE); [ANDROID_PORT_PLAN.md:32](ANDROID_PORT_PLAN.md#L32)): `@Upsert`, `@Index` on every FK child column, sorted `@Relation`, Date↔Long converters.

**Entities** (`recordingId` FKs indexed — Room emits `MISSING_INDEX_ON_FOREIGN_KEY_CHILD` warning otherwise, [Room `ForeignKey`](https://developer.android.com/reference/androidx/room/ForeignKey)):

```kotlin
@Entity(tableName = "recording")
data class RecordingEntity(
    @PrimaryKey val id: String,                 // UUID.toString()
    val createdAt: Long,                        // epoch millis via converter
    val updatedAt: Long,
    val audioFileName: String = "",
    val duration: Double = 0.0,
    val fileSize: Long = 0,
    val status: String = "placeholder",         // RecordingStatus rawValue
    val fullTranscriptText: String = "",
    val title: String = "Untitled",
    val isFavorite: Boolean = false,
    val cloudSyncStatus: String? = null,
    val summary: String? = null,
    val summaryStatus: String? = null,
    val topicTagsJSON: String? = null,
    val summaryGeneratedAt: Long? = null,
    val hasMedication: Boolean = false,
    val medicationInfo: String? = null,
    val energyLevel: String? = null,
    val focusLevel: String? = null,
    val mood: String? = null,
    val sleepHours: Double? = null,
    val sleepQuality: String? = null,
    val summaryBulletsJSON: String? = null,
    val noteExtractionJSON: String? = null,
    val sideEffectsJSON: String? = null,
    val sleepEventJSON: String? = null,
    val emotionsJSON: String? = null,
    val sleepLevelValue: String? = null,
    val isMockData: Boolean = false
)   // 29 columns

@Entity(
    tableName = "transcription_segment",
    foreignKeys = [ForeignKey(
        entity = RecordingEntity::class,
        parentColumns = ["id"], childColumns = ["recordingId"],
        onDelete = ForeignKey.CASCADE)],
    indices = [Index("recordingId")]            // MANDATORY: silences MISSING_INDEX_ON_FOREIGN_KEY_CHILD
)
data class TranscriptionSegmentEntity(
    @PrimaryKey val id: String,
    val recordingId: String,
    val text: String = "",
    val startTime: Double = 0.0,
    val endTime: Double = 0.0,
    val isFinal: Boolean = true,
    val confidence: Double? = null,
    val language: String = "en"
)

@Entity(
    tableName = "recording_tag",
    foreignKeys = [ForeignKey(
        entity = RecordingEntity::class,
        parentColumns = ["id"], childColumns = ["recordingId"],
        onDelete = ForeignKey.CASCADE)],
    indices = [Index("recordingId")]
)
data class RecordingTagEntity(
    @PrimaryKey val id: String,
    val recordingId: String,
    val name: String = "",
    val category: String = "",                  // TagCategory rawValue
    val source: String = "",                    // TagSource rawValue
    val confidence: Double? = null,
    val createdAt: Long
)

@Entity(
    tableName = "medication_event",
    foreignKeys = [ForeignKey(
        entity = RecordingEntity::class,
        parentColumns = ["id"], childColumns = ["recordingId"],
        onDelete = ForeignKey.CASCADE)],
    indices = [Index("recordingId")]
)
data class MedicationEventEntity(
    @PrimaryKey val id: String,
    val recordingId: String? = null,           // NULLABLE FK: standalone manual doses
    val name: String = "",
    val dose: String? = null,
    val takenAt: Long,
    val taken: Boolean = true,
    val quantity: Double? = null,
    val durationHours: Double = 10.0,
    val change: String? = null,                // MedEventChange rawValue
    val timeLabel: String? = null,
    val source: String = "manual",
    val createdAt: Long,
    val isMockData: Boolean = false
)
```

**Aggregate + DAO** — `@Relation` result order is undefined ([Room `@Relation`](https://developer.android.com/reference/androidx/room/Relation)), so **sort in the query, never rely on relation order**:

```kotlin
data class RecordingWithChildren(
    @Embedded val recording: RecordingEntity,
    @Relation(parentColumn = "id", entityColumn = "recordingId")
    val segments: List<TranscriptionSegmentEntity>,     // UNORDERED as returned
    @Relation(parentColumn = "id", entityColumn = "recordingId")
    val tags: List<RecordingTagEntity>,
    @Relation(parentColumn = "id", entityColumn = "recordingId")
    val medicationEvents: List<MedicationEventEntity>
)

@Dao
interface RecordingDao {
    // @Upsert = UPDATE-or-INSERT. NEVER @Insert(onConflict = REPLACE): REPLACE is
    // DELETE-then-INSERT, which fires ON DELETE CASCADE and destroys all children.
    @Upsert suspend fun upsert(recording: RecordingEntity)
    @Upsert suspend fun upsertSegments(rows: List<TranscriptionSegmentEntity>)
    @Upsert suspend fun upsertTags(rows: List<RecordingTagEntity>)
    @Upsert suspend fun upsertMedEvents(rows: List<MedicationEventEntity>)

    @Transaction
    @Query("SELECT * FROM recording WHERE id = :id")
    suspend fun withChildren(id: String): RecordingWithChildren?

    // Ordering is asserted here, not inferred from @Relation:
    @Query("SELECT * FROM transcription_segment WHERE recordingId = :id ORDER BY startTime ASC")
    suspend fun segments(id: String): List<TranscriptionSegmentEntity>

    @Query("SELECT * FROM medication_event WHERE recordingId = :id ORDER BY takenAt ASC")
    suspend fun medicationEvents(id: String): List<MedicationEventEntity>
}

@Database(
    entities = [RecordingEntity::class, TranscriptionSegmentEntity::class,
                RecordingTagEntity::class, MedicationEventEntity::class],
    version = 1,                                 // versioned from 1; greenfield, no migration yet
    exportSchema = true                          // schema JSON checked into VCS for future diffs
)
@TypeConverters(Converters::class)
abstract class SquirlDatabase : RoomDatabase() {
    abstract fun recordingDao(): RecordingDao
}
```

The DTO seam (Path B only): the shared Swift core produces `JournalRecordingDTO` value types (owned by P1-A); a Kotlin mapper converts `RecordingWithChildren` ⇄ DTO across SkipBridge. This is the doubled surface Path A avoids.

---

### Converters, indexing, versioning (both paths)

**Type converters** (identical semantics both paths; Room needs them explicit):

```kotlin
class Converters {
    // Date ↔ Long: store epoch MILLIS. Pick one unit and pin it — iOS Date is
    // seconds-since-2001, JS is millis; millis-since-1970 is the interchange contract.
    @TypeConverter fun dateToLong(d: Date?): Long? = d?.time
    @TypeConverter fun longToDate(v: Long?): Date? = v?.let { Date(it) }
    // UUID ↔ String (lowercased canonical form, matches UUID.uuidString on iOS).
    @TypeConverter fun uuidToString(u: UUID?): String? = u?.toString()
    @TypeConverter fun stringToUuid(s: String?): UUID? = s?.let { UUID.fromString(it) }
    // Enums cross the boundary as rawValue String — never ordinal.
}
```

- **Date unit contract:** epoch **milliseconds** everywhere (both paths). The one cross-platform hazard — iOS `Date` reference epoch is 2001, not 1970 (`timeIntervalSinceReferenceDate`, [developer.apple.com/documentation/foundation/date](https://developer.apple.com/documentation/foundation/date)) — is resolved at the DTO boundary, not in the DB. Document the unit once; a silent seconds-vs-millis mismatch corrupts every timeline.
- **Enums:** always persist `rawValue` (String), never the ordinal, so enum-case reordering never rewrites stored data. Applies to `RecordingStatus`, `MedicationEvent.Source`, `MedEventChange`, `TagCategory`, `TagSource`.
- **Indexing:** every FK child column (`recordingId` in all 3 child tables) is indexed on both paths — Path A via `CREATE INDEX`, Path B via `@Index` (Room hard-warns `MISSING_INDEX_ON_FOREIGN_KEY_CHILD` without it). This is a query-plan requirement for "load a recording's children", the app's hottest read.
- **Cascade correctness:** SkipSQL needs `PRAGMA foreign_keys = ON` on **every connection** (SQLite defaults OFF); Room enforces FKs by default. Both mirror SwiftData `.cascade`.
- **Upsert discipline:** `@Upsert` / `ON CONFLICT DO UPDATE` on both paths ([Room `@Upsert`](https://developer.android.com/reference/androidx/room/Upsert)). The forbidden pattern is REPLACE-on-conflict — SQLite `ON CONFLICT REPLACE` is DELETE+INSERT ([sqlite.org/lang_conflict](https://www.sqlite.org/lang_conflict.html), [`OnConflictStrategy.REPLACE`](https://developer.android.com/reference/androidx/room/OnConflictStrategy#REPLACE)), and the DELETE cascades away the children. This is the single most likely correctness bug in a naive port.
- **Versioning:** schema version = **1** (greenfield). Path A: SQLite `PRAGMA user_version`, gated `migrate()`. Path B: Room `version = 1` + `exportSchema = true` (schema JSON in VCS). No migration to write for v1; the machinery exists so v2 is a diff, not a rebuild.

---

### Recommendation + feature-038 impact

**Recommend Path A (SkipSQL)**, conditional on the P0.3 round-trip passing under `mode: 'native'` — which the C-interop guarantee says it will ([skip-sql README](https://github.com/skiptools/skip-sql)).

Why:
- **One persistence surface.** The store is shared Swift, compiled natively into both apps. Path B doubles it (SwiftData + Room) and adds a hand-maintained DTO/bridge seam — the exact cost Fuse exists to avoid ([ANDROID_PHASE0.md:818](ANDROID_PHASE0.md#L818)).
- **With Skip's grain.** SwiftData is unsupported on Android; SkipSQL is Skip's documented, supported persistence path under Fuse. Room-via-SkipBridge is *undocumented* — no supported reference to copy ([ANDROID_PHASE0.md:818](ANDROID_PHASE0.md#L818)).
- **Parity for free.** Identical SQLite C API on both platforms → identical rounding, collation, NULL handling. A Room/SwiftData split reintroduces two engines that must be proven equivalent.

**The cost this recommendation carries — feature-038 iCloud-sync (do not bury this):**

Adopting SkipSQL on iOS means **replacing SwiftData**, and the entire in-flight **feature-038 iCloud-sync is built on the SwiftData+CloudKit mirroring path** — the reason every model in the inventory carries inline defaults, drops `.unique`, and keeps all relationships optional ([Recording.swift:6-8, 66-69](../app-four/Models/Recording.swift#L6); [MedicationEvent.swift:12-14](../app-four/Models/MedicationEvent.swift#L12)). **SkipSQL has no CloudKit story.** So Path A's true cost is not just "rewrite the iOS store":

| Cost line | Detail |
|-----------|--------|
| **Rewrite iOS persistence** | SwiftData `@Model` → SkipSQL `SQLCodable` across all 4 models + every `@Query`/`ModelContext` call site (view models, `applySummary`/`setMedicationEvents` at [Recording.swift:215, 314](../app-four/Models/Recording.swift#L215)). |
| **Forfeit 038 sync engine** | The SwiftData+CloudKit mirror is gone. A **replacement sync mechanism must be named and estimated on both platforms** ([ANDROID_PHASE0.md:822](ANDROID_PHASE0.md#L822)) — e.g. `CKSyncEngine` hand-driven over SkipSQL, or the `JournalArchive` export as the interchange floor. |
| **Lose ADP E2E-encryption posture** | 038's FR-016 privacy guarantee rides on the CloudKit private DB under Advanced Data Protection ([Recording.swift:16-20](../app-four/Models/Recording.swift#L16)). Any replacement must re-establish that guarantee or explicitly descope it. |
| **iOS regression surface** | 038 already merged/in-flight on `feat/038-icloud-sync`; ripping SwiftData out is a large, well-tested-surface rewrite with its own QA cost. |

**Because of this, the recommendation is deliberately owner-gated at G0, not auto-adopted.** The engineering-optimal answer for the *Android port in isolation* is SkipSQL. The *product* answer depends on how much the owner values 038's shipped iCloud sync. Two honest resolutions:

1. **SkipSQL everywhere** — best long-term shared core; pay the 038 rewrite + a new cross-platform sync design now.
2. **Keep SwiftData(iOS)+038 intact, Room on Android (Path B)** — protects the shipped sync feature; accepts the doubled persistence surface and the undocumented bridge as the price of not disturbing 038.

Given 038 is **explicitly out of scope for Android v1** ([ANDROID_PORT_PLAN.md:6-7](ANDROID_PORT_PLAN.md#L6)) yet **in-flight and valued on iOS**, the pragmatic near-term call is often **Path B for v1** (don't touch a shipping iOS feature to build a standalone Android v1), with **Path A as the v2 convergence target** once an Android sync story is actually on the roadmap. State both; let the owner pick at G0.

---

### Exit criteria (binary, per branch)

**Common (both paths):**
- [ ] All 4 tables created with exactly the inventoried columns (29 + 7 + 6 + 12), enums stored as rawValue, dates as epoch-millis INTEGER.
- [ ] A `Recording` with ≥1 segment, ≥1 tag, ≥1 medication event round-trips write→read byte-identical (incl. all 6 `…JSON` blobs unmodified).
- [ ] Deleting a `Recording` cascades: its segments, tags, and transcript-sourced medication events are gone; a **standalone manual `MedicationEvent` (`recordingId == NULL`) survives**.
- [ ] Upsert of an existing `Recording` (same `id`) updates in place and **preserves all children** (proves no REPLACE/DELETE+INSERT).
- [ ] Children read back in deterministic order (segments by `startTime`, med events by `takenAt`).
- [ ] Schema version reads 1; a no-op `migrate()`/Room-open on an existing v1 DB does not rebuild.
- [ ] The P1-E `JournalRepository` conformance suite (P1-E exit #6) passes unmodified against the Path-A/B impl.

**Path A (SkipSQL) only:**
- [ ] SkipSQL links and round-trips a row under `mode: 'native'` on a real Android device (the P0.3 gate, [ANDROID_PHASE0.md:816](ANDROID_PHASE0.md#L816)).
- [ ] **(P1-scoped)** the identical `SQLCodable` store compiles for the iOS host and passes the same round-trip *as a standalone store* (`swift test`) — **no iOS SwiftData→SkipSQL app migration is required for Phase-1 sign-off**; under Path A, Phase 1 leaves the shipping iOS app on SwiftData. The full iOS store migration + 038 sync replacement is a separate, out-of-Phase-1 project (see cost sheet above).
- [ ] `PRAGMA foreign_keys = ON` verified active on the opened connection (cascade proven, not assumed).

**Path B (Room) only:**
- [ ] Room compiles with **zero** `MISSING_INDEX_ON_FOREIGN_KEY_CHILD` warnings.
- [ ] `@Upsert` path proven not to cascade-delete children (explicit test).
- [ ] `exportSchema` JSON committed to VCS.
- [ ] DTO ⇄ entity mapper round-trips every field across the SkipBridge seam with no loss.

---

### Risks & effort

| Risk | Path | Severity | Mitigation |
|------|------|----------|------------|
| SkipSQL fails `mode: 'native'` round-trip | A | High (forces B) | Gated at P0.3 before Phase 1 starts; C-interop guarantee makes it unlikely; Path B fully specified as fallback. |
| REPLACE-on-conflict silently cascades away children | Both | High | `@Upsert` / `ON CONFLICT DO UPDATE` mandated; explicit preserve-children test in exit criteria. |
| `foreign_keys` PRAGMA forgotten on a connection → dead cascade | A | Med | Set in store `init` on every open; exit criterion verifies it live. |
| Date unit drift (seconds vs millis; 2001 vs 1970 epoch) | Both | Med | Single documented contract (epoch millis); 2001→1970 conversion pinned at DTO boundary. |
| Enum stored as ordinal → reorder corrupts data | Both | Med | rawValue-only converters; covered by round-trip test. |
| `@Relation` unordered → non-deterministic UI | B | Low | `ORDER BY` in every child query; never trust relation order. |
| 038 sync rewrite scope underestimated | A | High (product) | Cost sheet above; owner-gated at G0; Path B avoids it entirely for v1. |
| skip-sql `SQLCodable` API signatures drift from README | A | Low | DDL is authoritative + version-independent; pin API against the resolved skip-sql version at impl. |

**Effort (solo dev + agent):**
- **Path A (SkipSQL):** ~3–4 days for the Android store (DDL + `SQLCodable` + store API + tests), **plus a separate, larger iOS SwiftData→SkipSQL rewrite + 038 sync replacement** that is its own project (not costed in Phase 1's 3 weeks — flagged as the owner's G0 decision, likely multi-week).
- **Path B (Room):** ~4–5 days (entities + DAOs + converters + DTO bridge + tests). No iOS disturbance. The DTO/bridge seam is the extra cost vs Path A's Android-only work.

### Cross-phase dependencies & assumptions

*(Upstream P0.1/P0.3 gating and the intra-Phase-1 deps on P1-A DTOs / P1-E's `JournalRepository` / P1-D's audio-column writes are consolidated in the final section. Retained here: what Phase 2 consumes + standing data assumptions.)*

- **P2 extractor wiring** ([ANDROID_PORT_PLAN.md:38](ANDROID_PORT_PLAN.md#L38)) — writes `noteExtractionJSON`/`emotionsJSON`/`sideEffectsJSON`/`sleepEventJSON` into the columns here. **Assumes the extractor emits canonical JSON** (P0.4 §5, [ANDROID_PHASE0.md:993](ANDROID_PHASE0.md#L993)); the store is a byte-faithful sink and must not re-serialize.
- **P2 UI build-out** ([ANDROID_PORT_PLAN.md:39](ANDROID_PORT_PLAN.md#L39)) — day card / calendar / recording-detail read `RecordingWithChildren`; relies on the ordered-children guarantee.
- Android v1 is **standalone, local-only**; sync (038) is out of scope for the *port*, so Path B's "don't touch iOS" posture has zero v1 functional cost ([ANDROID_PORT_PLAN.md:6-7](ANDROID_PORT_PLAN.md#L6)).
- The `JournalArchive` export (`formatVersion`, `currentFormatVersion = 1`, [ExportService.swift:11-18](../app-four/Services/ExportService.swift#L11)) remains the versioned interchange floor whatever the sync posture — the zero-cost hedge both paths preserve.
- Field inventory is frozen at **29/3** as of this session; any new `Recording` field added on iOS before the port must bump the Android schema and, if Path A is chosen, the shared `SQLCodable` struct.

---

## P1-D — Audio capture pipeline

Phase 1 (Foundation) workstream. Builds the Android equivalent of the iOS `AudioRecordingServiceImpl` + `AudioFileStorageServiceImpl` capture path: microphone → 16 kHz mono PCM → (1) AAC-encoded `.m4a` artifact for storage/playback, (2) raw 16 kHz mono float PCM to the STT engine chosen in P0.2. Depends on G0 (P0.1 toolchain, P0.2 STT winner). All Android API claims carry a `developer.android.com` URL; repo claims carry `file:line`.

### Goal

Reproduce, natively on Android, the two guarantees the iOS capture path gives today:

1. **A stored `.m4a` artifact** byte-shape-compatible with what iOS produces (AAC-in-MP4, 16 kHz, mono) so the recording is playable in the app's detail view and the `JournalArchive` export format stays honest — the iOS artifact is AAC `.m4a` at 16 kHz mono ([AudioRecordingServiceImpl.swift:14-19](../app-four/Services/Audio/AudioRecordingServiceImpl.swift#L14), stored as `.m4a` at [AudioFileStorageServiceImpl.swift:28](../app-four/Services/Audio/AudioFileStorageServiceImpl.swift#L28)).
2. **A 16 kHz mono PCM stream** as the *only* input path to the signal-extractor pipeline (via STT). On iOS this is implicit: WhisperKit is handed the `.m4a` path and decodes it internally ([WhisperKitTranscriptionService.swift:154](../app-four/Services/WhisperKit/WhisperKitTranscriptionService.swift#L154)). On Android the STT engine (whisper.cpp / sherpa-onnx) wants raw float PCM, so we must expose the PCM explicitly — and, critically, **not** round-trip audio through AAC encode→decode before STT (that lossy round trip would degrade WER, the exact metric P0.2 gates on).

**Non-goals (v1):** no live/streaming partial transcription during capture (STT is batch, post-stop, mirroring iOS); no background *recording* as a product feature — the FGS `microphone` type exists to keep an *in-progress, user-initiated* recording alive across a screen-off / app-switch, matching iOS `UIBackgroundModes: audio` ([Info.plist:7-9](../app-four/Info.plist#L7)), not to record unattended.

### iOS capture config to match (repo grounding)

| Parameter | iOS value | Source |
|---|---|---|
| Container / codec | MPEG-4 AAC in `.m4a` | `AVFormatIDKey: kAudioFormatMPEG4AAC` [AudioRecordingServiceImpl.swift:15](../app-four/Services/Audio/AudioRecordingServiceImpl.swift#L15) |
| Sample rate | **16 000 Hz** | `AudioConstants.sampleRate = 16000` [Constants.swift:4](../app-four/Utils/Constants.swift#L4) |
| Channels | **1 (mono)** | `AudioConstants.channels = 1` [Constants.swift:5](../app-four/Utils/Constants.swift#L5) |
| Encoder quality | `AVAudioQuality.high` | [AudioRecordingServiceImpl.swift:18](../app-four/Services/Audio/AudioRecordingServiceImpl.swift#L18) |
| Format label (UI/export) | `"16 kHz • M4A"` | [Constants.swift:6](../app-four/Utils/Constants.swift#L6) |
| Max duration | **480 s (8 min)** auto-stop | `LayoutConstants.maxRecordingDuration` [Constants.swift:10](../app-four/Utils/Constants.swift#L10) |
| Min free disk to start | 50 MB constant declared; **20 MB used in code** (discrepancy reconciled in the final section — grounded value is 20 MB) | [Constants.swift:11](../app-four/Utils/Constants.swift#L11) vs guard `< 20_000_000` [AudioRecordingServiceImpl.swift:60](../app-four/Services/Audio/AudioRecordingServiceImpl.swift#L60) |
| Session config | `.playAndRecord`, `.default`, `allowBluetoothHFP`/`allowBluetoothA2DP` | [AudioRecordingServiceImpl.swift:65](../app-four/Services/Audio/AudioRecordingServiceImpl.swift#L65) |
| Interruption policy | pause / resume / stayPaused / ignore — never stop-and-discard | `InterruptionResponse` [AudioRecordingServiceImpl.swift:179-249](../app-four/Services/Audio/AudioRecordingServiceImpl.swift#L179) |
| STT PCM target | float32, 16 kHz, mono, non-interleaved | `convertToPCM` placeholder [AudioConverter.swift:20-22](../app-four/Utils/AudioConverter.swift#L20) |

Note: iOS `AVAudioQuality.high` has no direct AAC-bitrate integer. For 16 kHz mono speech, target **~24–32 kbps** AAC-LC on Android (`KEY_BIT_RATE`), sized to keep files close to iOS and comfortably under the 8-minute cap. This is a tunable, not a parity-critical value — the artifact is for human playback, not for STT (STT eats the pre-encode PCM tap).

### AudioRecord config (16 kHz mono; float caveat)

Capture with `AudioRecord` at 16 kHz mono. **Capture 16-bit PCM (`ENCODING_PCM_16BIT`), not float** — `ENCODING_PCM_FLOAT` is *not guaranteed on all devices* ([AudioRecord ref](https://developer.android.com/reference/android/media/AudioRecord), [AudioFormat#ENCODING_PCM_FLOAT](https://developer.android.com/reference/android/media/AudioFormat#ENCODING_PCM_FLOAT)). 16-bit is the universally-supported floor and sidesteps the float question at the source; the STT engine's float requirement is met by a trivial in-app `short → Float` normalization (`sample / 32768.0f`), which is lossless-enough for speech and avoids depending on device float-capture support.

Use `AudioSource.VOICE_RECOGNITION` to mirror iOS's speech-tuned path (noise suppression / AEC, no music-oriented AGC) — it is the correct source for an STT pipeline ([MediaRecorder.AudioSource](https://developer.android.com/reference/android/media/MediaRecorder.AudioSource#VOICE_RECOGNITION)). Fall back to `MIC` only if a device rejects `VOICE_RECOGNITION`.

```kotlin
private const val SAMPLE_RATE = 16_000                       // AudioConstants.sampleRate parity
private const val CHANNEL = AudioFormat.CHANNEL_IN_MONO      // AudioConstants.channels = 1
private const val ENCODING = AudioFormat.ENCODING_PCM_16BIT  // guaranteed; float not (see above)

private fun buildRecord(): AudioRecord {
    val minBuf = AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL, ENCODING)
    require(minBuf != AudioRecord.ERROR && minBuf != AudioRecord.ERROR_BAD_VALUE) { "bad AudioRecord params" }
    // Over-provision the ring buffer (≥4× min) so a scheduling hiccup during MediaCodec
    // draining or STT-tap accumulation never overruns and drops PCM frames.
    val bufBytes = maxOf(minBuf * 4, SAMPLE_RATE /*~0.5s @16bit mono = 32KB*/ )
    @SuppressLint("MissingPermission") // RECORD_AUDIO checked before this is reachable (see FGS §)
    return AudioRecord.Builder()
        .setAudioSource(MediaRecorder.AudioSource.VOICE_RECOGNITION)
        .setAudioFormat(
            AudioFormat.Builder()
                .setEncoding(ENCODING)
                .setSampleRate(SAMPLE_RATE)
                .setChannelMask(CHANNEL)
                .build()
        )
        .setBufferSizeInBytes(bufBytes)
        .build()
}
```

Read loop runs on a dedicated thread (never the main thread; `AudioRecord.read` blocks). Each read yields a `ShortArray` chunk that is **fanned two ways** (see Dual output): fed to the AAC encoder *and* normalized to float for the STT accumulator.

```kotlin
val record = buildRecord()
record.startRecording()
val chunk = ShortArray(SAMPLE_RATE / 10) // ~100ms @16kHz mono
while (isRecording) {
    val n = record.read(chunk, 0, chunk.size)
    if (n > 0) {
        encoderSink.feed(chunk, n)   // → MediaCodec AAC → MediaMuxer .m4a
        pcmSink.feed(chunk, n)       // → normalize short→float, accumulate for STT
    }
}
record.stop(); record.release()
```

Because we capture at 16 kHz mono directly, **no resampling is needed for either consumer** — the artifact and the STT input share the capture rate, exactly matching the iOS 16 kHz-throughout design. (`getMinBufferSize`, `read`, `startRecording`, `stop`, `release`: [AudioRecord ref](https://developer.android.com/reference/android/media/AudioRecord).)

### MediaCodec AAC encode + MediaMuxer `.m4a` (PTS / EOS)

**MediaCodec alone emits a raw AAC elementary stream (ADTS-less), not a playable file — `MediaMuxer` with `MUXER_OUTPUT_MPEG_4` is REQUIRED** to produce a `.m4a` the app (and iOS-parity tooling) can open ([MediaMuxer ref](https://developer.android.com/reference/android/media/MediaMuxer), [MediaMuxer.OutputFormat](https://developer.android.com/reference/android/media/MediaMuxer.OutputFormat#MUXER_OUTPUT_MPEG_4)). The muxer track must be added from the **encoder's output** `MediaFormat` delivered via `INFO_OUTPUT_FORMAT_CHANGED` (which carries the codec-specific `csd-0`/ESDS), never from the input format, and `writeSampleData` timestamps (`presentationTimeUs`) must be **monotonically increasing** ([MediaMuxer ref](https://developer.android.com/reference/android/media/MediaMuxer)).

**Encoder configuration** (feed 16-bit PCM in; the float-input path is not needed because we capture 16-bit):

```kotlin
val format = MediaFormat.createAudioFormat(MediaFormat.MIMETYPE_AUDIO_AAC, SAMPLE_RATE, 1).apply {
    setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
    setInteger(MediaFormat.KEY_BIT_RATE, 32_000)            // ~AVAudioQuality.high for 16k mono speech
    setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, 16_384)
    // Default encoder PCM input is 16-bit. If a future variant captures float, the encoder
    // only accepts float input when KEY_PCM_ENCODING = ENCODING_PCM_FLOAT is supported —
    // which MUST be re-read from getInputFormat() after configure(), NOT assumed. On any
    // device where getInputFormat() does not report ENCODING_PCM_FLOAT, fall back to
    // converting float→16-bit before feeding the encoder. We avoid this entirely by
    // capturing 16-bit (see AudioRecord §).
}
val encoder = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC)
encoder.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
encoder.start()
```

**Float-input confirmation gate** (only if float capture is ever adopted): after `configure()`, read back `encoder.inputFormat` and check `KEY_PCM_ENCODING`; if it is not `ENCODING_PCM_FLOAT`, the encoder does not accept float on this device — convert to 16-bit first. ([KEY_PCM_ENCODING](https://developer.android.com/reference/android/media/MediaFormat#KEY_PCM_ENCODING); the ground-truth caveat carried from the plan, [ANDROID_PORT_PLAN.md:33](ANDROID_PORT_PLAN.md#L33).)

**Drain loop with PTS derived from sample count (drift-free) and explicit EOS:**

```kotlin
class AacMuxSink(outputPath: String, private val encoder: MediaCodec) {
    private val muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
    private var trackIndex = -1
    private var muxerStarted = false
    private var totalSamplesIn = 0L          // monotonic PTS clock
    private val bufInfo = MediaCodec.BufferInfo()

    // Feed one PCM chunk; PTS is computed from cumulative sample count, NOT wall clock,
    // so the muxed timeline is strictly monotonic and gap-free even under scheduling jitter.
    fun feed(pcm: ShortArray, n: Int) {
        val inIx = encoder.dequeueInputBuffer(10_000)
        if (inIx >= 0) {
            val inBuf = encoder.getInputBuffer(inIx)!!.apply { clear() }
            inBuf.asShortBuffer().put(pcm, 0, n)
            val ptsUs = totalSamplesIn * 1_000_000L / SAMPLE_RATE
            encoder.queueInputBuffer(inIx, 0, n * 2 /*bytes*/, ptsUs, 0)
            totalSamplesIn += n
        }
        drain(endOfStream = false)
    }

    fun finish() {
        // Signal EOS to the encoder so it flushes its final frames.
        val inIx = encoder.dequeueInputBuffer(10_000)
        if (inIx >= 0) {
            val ptsUs = totalSamplesIn * 1_000_000L / SAMPLE_RATE
            encoder.queueInputBuffer(inIx, 0, 0, ptsUs, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
        }
        drain(endOfStream = true)
        encoder.stop(); encoder.release()
        if (muxerStarted) { muxer.stop() }
        muxer.release()
    }

    private fun drain(endOfStream: Boolean) {
        while (true) {
            val outIx = encoder.dequeueOutputBuffer(bufInfo, 10_000)
            when {
                outIx == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                    check(!muxerStarted) { "format changed twice" }
                    // Add track from the ENCODER OUTPUT format (carries csd-0/ESDS) — required.
                    trackIndex = muxer.addTrack(encoder.outputFormat)
                    muxer.start(); muxerStarted = true
                }
                outIx == MediaCodec.INFO_TRY_AGAIN_LATER ->
                    if (!endOfStream) return  // no more output for now; wait for next feed
                    else continue             // on EOS, keep polling until the flag arrives
                outIx >= 0 -> {
                    val outBuf = encoder.getOutputBuffer(outIx)!!
                    // Drop the codec-config buffer: its bytes live in the track format (csd-0),
                    // not in the sample stream — writing it would corrupt the .m4a.
                    if (bufInfo.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0) bufInfo.size = 0
                    if (bufInfo.size > 0 && muxerStarted) {
                        outBuf.position(bufInfo.offset)
                        outBuf.limit(bufInfo.offset + bufInfo.size)
                        muxer.writeSampleData(trackIndex, outBuf, bufInfo) // PTS already monotonic
                    }
                    encoder.releaseOutputBuffer(outIx, false)
                    if (bufInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) return
                }
            }
        }
    }
}
```

Three correctness points that are load-bearing and easy to get wrong:
- **PTS from sample count, not `System.nanoTime()`** — guarantees strict monotonicity and a duration that matches the true captured sample count (the muxer rejects/duplicates non-increasing timestamps).
- **Codec-config buffer must be skipped** in `writeSampleData` — its payload belongs in the track format (`csd-0`), and writing it as a sample corrupts the file.
- **EOS is explicit** — queue an empty input buffer with `BUFFER_FLAG_END_OF_STREAM`, then drain until the output carries the same flag, or the last AAC frames are truncated.

### FGS microphone (manifest + permission + can't-start-from-background)

Android 14 (API 34) requires every foreground service to declare a type; the `microphone` type requires the `FOREGROUND_SERVICE_MICROPHONE` permission **and** a granted `RECORD_AUDIO` runtime permission, and **a `microphone` FGS cannot be started while the app is in the background** because `RECORD_AUDIO` is a while-in-use permission ([FGS service types](https://developer.android.com/develop/background-work/services/fgs/service-types)).

**Manifest:**

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MICROPHONE" />
<!-- API 33+: the FGS notification itself requires notification permission -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />

<service
    android:name=".audio.RecordingService"
    android:exported="false"
    android:foregroundServiceType="microphone" />
```

**Start (from the foreground only) + `startForeground` with the matching type:**

```kotlin
// Caller (an Activity/visible UI) — RECORD_AUDIO must already be granted, and the app
// must be foreground; starting this from the background throws on API 34+.
fun beginRecording(ctx: Context) {
    check(ContextCompat.checkSelfPermission(ctx, Manifest.permission.RECORD_AUDIO)
        == PackageManager.PERMISSION_GRANTED) { "RECORD_AUDIO not granted" }
    ContextCompat.startForegroundService(ctx, Intent(ctx, RecordingService::class.java))
}

class RecordingService : Service() {
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notif = buildRecordingNotification()  // ongoing, non-dismissible
        // Type MUST match the manifest declaration, or Android 14 throws
        // MissingForegroundServiceTypeException
        // (developer.android.com/develop/background-work/services/fgs/service-types).
        ServiceCompat.startForeground(
            this, NOTIF_ID, notif,
            ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
        )
        startCaptureLoop()  // AudioRecord read loop on a background thread
        return START_NOT_STICKY // do not silently resurrect a mic service after process death
    }
    override fun onBind(intent: Intent?) = null
}
```

**Runtime permission flow (mirrors the iOS `requestPermission()` gate at [AudioRecordingServiceImpl.swift:54](../app-four/Services/Audio/AudioRecordingServiceImpl.swift#L54)):**
- `RECORD_AUDIO` is a **dangerous** permission → request at runtime with `ActivityResultContracts.RequestPermission()` before the first record; if denied, surface the same "mic unavailable" affordance the iOS app shows on `false`.
- `POST_NOTIFICATIONS` (API 33+) is a runtime permission requested separately ([notification runtime permission](https://developer.android.com/develop/ui/views/notifications/notification-permission)) — a denied notification does **not** block the FGS from starting, but the ongoing-recording notification won't show; keep recording functional regardless.
- Because a `microphone` FGS **can't start from the background**, all record entry points must originate from a visible UI. This is stricter than iOS (which permits `UIBackgroundModes: audio` starts); the product flow already starts recording from a foreground tap, so parity holds. Document this as a hard constraint: no "start recording via notification action / widget / boot" on v1.

### Interruption / focus handling

On iOS the OS auto-pauses `AVAudioRecorder` and posts `interruptionNotification`; the app maps it to pause/resume/stayPaused/ignore ([AudioRecordingServiceImpl.swift:179-249](../app-four/Services/Audio/AudioRecordingServiceImpl.swift#L179)). Android has **no auto-pause** — we must request audio focus, listen for loss, and pause the `AudioRecord` read loop ourselves. Use the modern `AudioFocusRequest` (API 26+); the legacy `requestAudioFocus(listener, stream, hint)` is deprecated ([AudioManager](https://developer.android.com/reference/android/media/AudioManager), [AudioFocusRequest](https://developer.android.com/reference/android/media/AudioFocusRequest)).

Incoming/outgoing **calls** manifest as audio-focus loss — prefer focus over the legacy telephony listeners (`PhoneStateListener`/`TelephonyCallback` need `READ_PHONE_STATE` and are the wrong tool here).

```kotlin
private lateinit var focusRequest: AudioFocusRequest

private fun requestFocus(am: AudioManager): Boolean {
    focusRequest = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
        .setAudioAttributes(
            AudioAttributes.Builder()
                .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                .setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
                .build()
        )
        .setOnAudioFocusChangeListener { change ->
            when (change) {
                // Transient (a call rings, Assistant, a nav prompt): pause + remember,
                // mirroring iOS .began → .pause and setting wasInterrupted = true.
                AudioManager.AUDIOFOCUS_LOSS_TRANSIENT,
                AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK ->
                    pauseForInterruption()
                // Permanent loss: keep what we captured, do NOT discard — this is the iOS
                // .stayPaused branch. Finalize the .m4a so nothing is lost.
                AudioManager.AUDIOFOCUS_LOSS ->
                    stayPausedPreserve()
                // Focus back after a transient loss: resume, mirroring iOS .resume.
                AudioManager.AUDIOFOCUS_GAIN ->
                    if (wasInterrupted) resumeFromInterruption()
            }
        }
        .build()
    return am.requestAudioFocus(focusRequest) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
}

// On stop/cancel:  am.abandonAudioFocusRequest(focusRequest)
```

Policy parity table (Android focus event → iOS `InterruptionResponse`):

| Android focus change | Action | iOS equivalent |
|---|---|---|
| `AUDIOFOCUS_LOSS_TRANSIENT[_CAN_DUCK]` | pause read loop, set `wasInterrupted`, keep encoder/muxer open | `.pause` ([:218](../app-four/Services/Audio/AudioRecordingServiceImpl.swift#L218)) |
| `AUDIOFOCUS_GAIN` (after transient) | resume read loop | `.resume` ([:219](../app-four/Services/Audio/AudioRecordingServiceImpl.swift#L219)) |
| `AUDIOFOCUS_LOSS` (permanent) | stop loop, **finalize `.m4a`, preserve capture**, hand off to STT | `.stayPaused` ([:220](../app-four/Services/Audio/AudioRecordingServiceImpl.swift#L220)) |
| no active recording | ignore | `.ignore` ([:221](../app-four/Services/Audio/AudioRecordingServiceImpl.swift#L221)) |

Core invariant carried verbatim from iOS: **never stop-and-discard on interruption** — an interruption pauses or finalizes, it never throws away the in-progress recording ([AudioRecordingServiceImpl.swift:212-215](../app-four/Services/Audio/AudioRecordingServiceImpl.swift#L212)). "Pause" here means stop pulling from `AudioRecord` and stop advancing the PTS clock; the encoder/muxer stay open so the resumed timeline continues monotonically. Also handle the 8-minute auto-stop ([Constants.swift:10](../app-four/Utils/Constants.swift#L10)) and the pre-flight disk check (port the iOS guard — grounded value is 20 MB, see the final section's reconciliation).

### Dual output (artifact + PCM-to-STT seam to Phase 2)

The single `AudioRecord` read loop is the **one** capture; it fans out to two independent sinks, so the STT input never suffers an AAC encode→decode round trip:

```
                       ┌──► AacMuxSink ──► MediaCodec(AAC) ──► MediaMuxer(MP4) ──► recording_<uuid>.m4a  (stored artifact)
AudioRecord (16k mono, ─┤
16-bit PCM chunks)     └──► PcmSttSink ──► short→float (/32768) ──► 16k mono float PCM ──► [Phase 2] JNI → STT engine
```

- **Artifact sink** → `.m4a`, saved exactly where iOS saves it (Documents/Recordings, `recording_<uuid>.m4a`, [AudioFileStorageServiceImpl.swift:28](../app-four/Services/Audio/AudioFileStorageServiceImpl.swift#L28)); feeds the `Recording` row (`audioFileName`, `fileSize`, `duration`) built in workstream P1-C — written through the `JournalRepository` contract (P1-E).
- **STT sink** → 16 kHz mono **float** PCM. This is the seam to **Phase 2 step 5** (STT integration): PCM enters the engine as a **direct `ByteBuffer`**, but the STT engine is driven from Swift via C interop (**P1-E §6**) — the transcript stays in-Swift as `TranscriptionSegmentDTO`, so JNI carries **PCM-in only**. The plan's UTF-8 `jbyteArray` transcript return ([ANDROID_PORT_PLAN.md:37](ANDROID_PORT_PLAN.md#L37)) applies only to the rejected Kotlin-driven-STT variant (and the sherpa-onnx official-AAR deviation recorded in P1-E). P1-D's deliverable stops at producing the float PCM (in-memory buffer for ≤8-min clips, or a scratch file) with a stable handoff type; the JNI bridge and vocabulary injection are Phase 2.
- **Why not decode the `.m4a` for STT (the iOS shape):** iOS gets away with handing WhisperKit the `.m4a` because WhisperKit decodes internally ([WhisperKitTranscriptionService.swift:154](../app-four/Services/WhisperKit/WhisperKitTranscriptionService.swift#L154)). Replicating that on Android would mean AAC-encode-then-decode before STT — lossy, and it puts encoder artifacts into the exact signal P0.2's WER gate measures. Tapping pre-encode PCM is both faster and higher-fidelity. This is the one deliberate *divergence* from the iOS data flow, and it is an improvement, not a shortcut.
- **Handoff type (freeze in P1-D so Phase 2 can build against it):** `FloatArray` / direct `ByteBuffer` of 16 kHz mono float samples in `[-1.0, 1.0]`, sample count == captured frames, plus duration seconds. Mirrors the iOS `convertToPCM` contract (float32/16 kHz/mono, [AudioConverter.swift:20-22](../app-four/Utils/AudioConverter.swift#L20)).

### Exit criteria (binary)

1. **`.m4a` parity:** a recorded file opened with `ffprobe`/`MediaExtractor` reports `mp4`/`aac (LC)`, **16000 Hz, 1 channel**; it plays start-to-finish in a standard player and in the app's recording-detail view; reported duration is within ±100 ms of wall-clock capture time.
2. **PCM-to-STT parity:** the STT sink yields 16 kHz mono float samples in `[-1,1]` with sample count == captured frames (no resample, no round trip); a fixed test tone produces the expected sample count (`duration_s × 16000`).
3. **FGS compliance:** recording runs under a `microphone`-typed foreground service with an ongoing notification; it **survives screen-off and app-switch** (continues capturing); a background-initiated start is verified to fail (throws / is blocked) on an API 34+ device.
4. **Permission flow:** first record triggers the `RECORD_AUDIO` runtime prompt; denial surfaces the "mic unavailable" path and never crashes; grant → record succeeds.
5. **Interruption:** an incoming phone call **pauses** capture and preserves the partial recording; on call end it **resumes** (transient) or the file is **finalized intact** (permanent loss) — never discarded; resumed timeline has no PTS discontinuity (monotonic, gap-free).
6. **Robustness:** 8-minute auto-stop finalizes a valid `.m4a`; low-disk pre-flight blocks start with the ported guard; `AudioRecord`/`MediaCodec`/`MediaMuxer` are all released on every exit path (stop, cancel, error) with no leaked mic indicator.

All six pass on a **real mid-tier Android device** (same class targeted by P0.2), not only an emulator.

### Risks & effort

| Risk | Impact | Mitigation |
|---|---|---|
| `MediaMuxer` PTS/EOS/codec-config mistakes | Corrupt or unplayable `.m4a`; STT unaffected but artifact fails QA | Sample-count PTS, skip `BUFFER_FLAG_CODEC_CONFIG`, explicit EOS drain (code above); assert with `MediaExtractor` in a JUnit test |
| Float encoder input assumption | Encoder rejects float on some devices | Capture 16-bit throughout; only touch float via `getInputFormat()` check — documented as not-taken path |
| Dropped PCM frames under load | Gaps in artifact **and** worse WER | Dedicated read thread, ≥4× min ring buffer, encoder drain off the read thread |
| FGS type mismatch / bg-start | `MissingForegroundServiceTypeException` or `ForegroundServiceStartNotAllowedException` | Type string == `startForeground` constant; start only from foreground UI; `START_NOT_STICKY` |
| No auto-pause on Android | Recording keeps running through a call, or is lost | Own the focus listener; map every focus event to the iOS policy table |
| `VOICE_RECOGNITION` unavailable | Build/record failure on some OEMs | Fall back to `AudioSource.MIC` |
| Disk-guard discrepancy (20 vs 50 MB) | Behavioral drift from iOS | Reconcile to a single source of truth (grounded value 20 MB); see final section |

**Effort: ~3–4 engineer-days** (of the Phase 1 "Audio capture" line). Day 1: `AudioRecord` loop + 16-bit capture + float STT tap + handoff type. Day 2: MediaCodec/MediaMuxer `.m4a` with PTS/EOS + `MediaExtractor` test. Day 3: FGS `microphone` service + runtime permission flow + notification. Day 4: audio-focus/interruption policy + call-interruption QA + release-path/leak audit. Highest-variance item is the muxer edge cases (config buffer, EOS truncation) — budget the extra half-day there.

### Cross-phase dependencies & assumptions

*(G0 gating and the intra-Phase-1 feeds into P1-C's `Recording` row / P1-E's contracts are consolidated in the final section. Retained here: the Phase 2 STT handoff + standing scope assumptions.)*

- **Feeds Phase 2 step 5 (STT integration):** P1-D delivers the 16 kHz mono float PCM buffer + duration; Phase 2 owns the STT integration — per P1-E §6 the engine is driven from Swift via C interop (transcript stays in-Swift as `TranscriptionSegmentDTO`, JNI confined to PCM-in as a direct `ByteBuffer`; the plan's `jbyteArray`-return standard, [ANDROID_PORT_PLAN.md:37](ANDROID_PORT_PLAN.md#L37), applies only on the rejected Kotlin-driven route) — plus vocabulary/`initial_prompt` injection and model delivery. **Freeze the handoff type in P1-D** so Phase 2 builds against a stable contract.
- **Assumes** `targetSdk = 36`, `minSdk = 28` (plan-wide, [ANDROID_PORT_PLAN.md:45](ANDROID_PORT_PLAN.md#L45)) — API 34's FGS-type rules and API 33's `POST_NOTIFICATIONS` both apply; capture APIs (`AudioRecord`/`MediaCodec`/`MediaMuxer`) are all ≥ API 16/18/26 and pose no floor risk.
- **Assumes** batch (post-stop) STT, matching iOS — no streaming partial-transcript path in v1; if product later wants live transcription, the STT sink already streams chunks and can be re-pointed without touching the artifact path.
- **Out of scope / deferred:** Bluetooth SCO mic routing (iOS enables `allowBluetoothHFP` — Android SCO capture is an OEM minefield; v1 records from the built-in mic, flag BT capture as a v2 item); noise-suppression/AEC effect toggles beyond the `VOICE_RECOGNITION` source default.
- **Divergence from iOS (intentional, documented):** STT consumes **pre-encode PCM**, not the decoded `.m4a`, to avoid an AAC round trip that would corrupt the P0.2 WER signal. This is the only place P1-D's data flow departs from the iOS shape.

---

## P1-B — Android scaffold, build system & CI

*Phase 1 (Foundation) workstream. Prerequisite: G0 green — in particular P0.1 (toolchain bring-up), which already proved the pins, packaging, and 16 KB gate this workstream now automates. This workstream stands up the **real** project and the **first CI** the port has ever had — Phase 0 established there is no Android CI (every P0 "gate" ran as a checked-in local script whose output was pasted into the spike report; [ANDROID_PHASE0.md:1085](ANDROID_PHASE0.md#L1085)). Grep of the repo confirms it: no `.github/workflows/` exists — the only YAML under any `workflows/` dir is `.specify/workflows/` and vendored-gem workflows under `.gems/`. This is a greenfield CI, nothing to reconcile with.*

### Goal

Stand up the shippable Android app skeleton and a push-triggered pipeline that proves, on every commit, three things Phase 0 proved once by hand:

1. the shared Swift core **cross-compiles** to `aarch64-unknown-linux-android28` against the pinned official Swift Android SDK;
2. a **debug APK assembles** from the Skip-generated Gradle project with the Swift `.so` + `libc++_shared.so` packaged (deduped via `pickFirsts`);
3. **every `.so` is 16 KB-aligned** (P0.1 §4 gate) and the **golden-fixture suite is byte-identical** on device/emulator (P0.4 gate) — both wired as CI-equivalent local scripts so `local == CI`.

Non-goal: STT model delivery, UI build-out, persistence schema — those are P1-C / Phase 2. This workstream owns the *build system and its gates*, not feature code.

### Scaffold steps (`skip init --native-app`)

Skip is **v1.9.4** (latest release, [github.com/skiptools/skip/releases](https://github.com/skiptools/skip/releases)), **free/OSS** ([skip.dev/pricing](https://skip.dev/pricing/)); docs at **skip.dev** (skip.tools redirects). `skip.yml` **defaults to transpiled (Lite) mode — Fuse/native must be requested explicitly** ([skip.dev/docs/modes](https://skip.dev/docs/modes/)). Do **not** hand-roll an AGP shell; let `skip init` generate the Gradle project ([ANDROID_PORT_PLAN.md:11](ANDROID_PORT_PLAN.md#L11)).

```bash
# 0. Preflight the host (once): full end-to-end native check
skip checkup --native        # runs skip doctor + builds a sample Fuse project on device/emulator
                             # (skip.dev/docs/skip-cli)

# 1. Generate the native (Fuse) app. Syntax: skip init [flags] <project-dir> <Module> [more modules...]
skip init --native-app --appid=com.squirl.app squirl-android Squirl
#   --native-app  → Skip Fuse (Swift compiled natively via the official Swift Android SDK)
#   --appid       → Android applicationId / bundle id
#   squirl-android → project dir ; Squirl → first module
#   (skip.dev/docs/skip-cli confirms --native-app / --transpiled-app / --appid / -c ;
#    it does NOT document --module-tests/--bridged/--show-tree — verify against `skip init --help` at run time.)
```

**Generated layout** (Skip app projects put the Android world under a root `Android/` folder; each Skip module carries a `Skip/skip.yml` that governs its Gradle representation — [skip.dev/docs/gradle](https://skip.dev/docs/gradle/), [skip.dev/docs/project-types](https://skip.dev/docs/project-types/)):

```
squirl-android/
├── Package.swift                 # SwiftPM: the Fuse module(s) as native targets
├── Sources/Squirl/…              # Swift/SwiftUI → SkipFuseUI → SkipUI → Compose
├── Skip/skip.yml                 # per-module Gradle mapping (mode: native; deps; customizations)
├── Android/
│   ├── settings.gradle.kts       # open in Android Studio OR `./gradlew` directly
│   ├── app/
│   │   ├── build.gradle.kts       # the app module — where we add §Gradle config below
│   │   ├── src/main/AndroidManifest.xml
│   │   └── src/main/kotlin/…/MainActivity.kt
│   └── gradle/wrapper/gradle-wrapper.properties
└── …
```

**Repository layout (monorepo).** `skip init` targets `app-four/android/squirl-android/`. The Fuse `Package.swift` depends on the shared core by path: `.package(path: "../../Packages/SquirlCore")`, and the Fuse target lists `.product(name: "SquirlNoteExtraction", package: "SquirlCore")`, `SquirlModelDTO`, `SquirlSignals`, `SquirlDesignTokens`. No git submodule — CI checks out the one repo plainly (no `submodules: recursive`).

The shared core (`SquirlSignals`, `SquirlNoteExtraction` + lexicon/inflection table, DTOs, design tokens — products of `SquirlCore`, P1-A) is consumed as SwiftPM dependencies of the Fuse module. Skip's Gradle build drives `swift build` for the Android triple and links the resulting `.so` into the APK; `swift build` outputs stage under `.build/plugins/outputs/` ([skip.dev/docs/gradle](https://skip.dev/docs/gradle/)). **Record what `skip init` actually pins** (AGP, Gradle, Kotlin, `compileSdk`) into the report — Skip owns those defaults; we override only the four Play-facing values in the next section.

### Gradle / AGP config (real snippets)

**Version landscape (verified 2026-07-22, pin whatever `skip init` emits unless it predates these):**
- **AGP latest stable 9.3.0**; AGP 9.x supports up to **API level 37.0** ([about-agp](https://developer.android.com/build/releases/about-agp)). The latest 8.x is **AGP 8.13** (min Gradle 8.13) if Skip still targets the 8.x DSL.
- **AGP→Gradle minimums:** 9.3→Gradle **9.5.0**, 9.2→9.4.1, 9.1→9.3.1, 9.0→9.1.0 ([about-agp](https://developer.android.com/build/releases/about-agp)). Latest Gradle is **9.6.1** (2026-07-06, [docs.gradle.org](https://docs.gradle.org/current/release-notes.html)).
- Gradle 9 requires **JDK 17+** to run ([gradle.org/whats-new/gradle-9](https://gradle.org/whats-new/gradle-9/)) — the CI runner must provision JDK 17 (21 LTS safe).

Do not fight Skip's pins; only enforce the Play gates and packaging. Edit `Android/app/build.gradle.kts`:

```kotlin
android {
    namespace = "com.squirl.app"
    compileSdk = 36                     // compileSdk 36 needs AGP ≥ 8.9.1; API 37 needs AGP ≥ 9.1.1 (about-agp)

    defaultConfig {
        applicationId = "com.squirl.app"
        minSdk = 28                     // deployment floor = Android 9 (P0.1 §2 triple android28)
        targetSdk = 36                  // REQUIRED for new Play apps + all updates from 2026-08-31
                                        // (developer.android.com/google/play/requirements/target-sdk)
        ndk { abiFilters += listOf("arm64-v8a") }   // add "x86_64" ONLY in the emulator/CI-fixture variant
    }

    packaging {
        jniLibs {
            // Multiple deps each vendor libc++_shared.so → dedup or the packager errors on duplicate .so.
            // pickFirsts from DAY ONE (ANDROID_PORT_PLAN.md:31).
            pickFirsts += listOf("**/libc++_shared.so")
            // useLegacyPackaging = false is the AGP default: keeps .so uncompressed & page-aligned in the
            // APK — mandatory for the 16 KB gate (developer.android.com/guide/practices/page-sizes). Do NOT set true.
        }
    }

    // 16 KB alignment on the r27d toolchain (NDK r27 does NOT align by default; r28+ does —
    // developer.android.com/guide/practices/page-sizes; r28 default: github.com/android/ndk/wiki/Changelog-r28).
    // Any C/C++ .so built by AGP (externalNativeBuild) needs the flags; the Swift .so gets them via
    // swift-build-flags in CI (see below). — P0.1 §4.
    externalNativeBuild { cmake { path = file("src/main/cpp/CMakeLists.txt") } }  // only if a C bridge shim exists
}
```

CMake side (any AGP-built native lib, mirrors P0.1 §3.6a):

```cmake
target_link_options(bridge PRIVATE
    "-Wl,-z,max-page-size=16384" "-Wl,-z,common-page-size=16384")
```

Swift core side — the flags are **mandatory and manual on r27** ([ANDROID_PHASE0.md:321](ANDROID_PHASE0.md#L321)); pass them through SwiftPM (in CI via `swift-build-flags`, locally via `swift build`):

```
-Xlinker -z -Xlinker max-page-size=16384 -Xlinker -z -Xlinker common-page-size=16384
```

### CI pipeline

Two push-triggered jobs. The tool of record for the Swift-Android side is **`skiptools/swift-android-action@v2`** — it installs the official Swift SDK for Android (`swift-version` default **6.3**), cross-compiles the package, and (on runners that can host the emulator) runs the tests **on an Android emulator** at `android-api-level` (default **28**) ([github.com/skiptools/swift-android-action](https://github.com/skiptools/swift-android-action)). **Runner constraint:** ARM macOS (`macos-14/15`) **cannot** run the Android emulator (no nested virt) — emulator jobs must use `ubuntu-latest` (KVM) or `macos-15-intel`/`*-large`; on ARM macOS set `run-tests: false` ([swift-android-action README](https://github.com/skiptools/swift-android-action)). Inputs that matter here: `swift-configuration`, `swift-build-flags` (→ inject the 16 KB linker flags), `custom-sdk-url`+`custom-sdk-id` (→ pin the exact 6.3.3 artifactbundle from P0.1), `run-tests`, `free-disk-space`.

`.github/workflows/android.yml`:

```yaml
name: android
on:
  push:
    branches: ['**']
  pull_request:
  workflow_dispatch:

concurrency:
  group: android-${{ github.ref }}
  cancel-in-progress: true

jobs:
  # ── Job 1: shared-core cross-compile + golden-fixture parity (P0.4 gate) ──
  # Runs the fixtures ON an Android emulator — the CI form of scripts/android/run-fixtures.sh.
  swift-core-parity:
    runs-on: ubuntu-latest          # emulator needs KVM; ARM macOS cannot host it
    steps:
      - uses: actions/checkout@v6            # monorepo — no submodules
      - uses: swift-actions/setup-swift@v2   # ubuntu runner has no Swift toolchain preinstalled
        with: { swift-version: '6.3.3' }
      - name: Host swift test (generator + iOS-equivalent baseline)
        run: swift test --package-path Packages/SquirlCore
      - name: Cross-compile + run fixtures on Android emulator
        uses: skiptools/swift-android-action@v2
        with:
          swift-version: '6.3.3'                       # pin — never float (P0.1 §6)
          android-api-level: '28'                      # matches the -android28 triple
          package-path: 'Packages/SquirlCore'    # owned by P1-A; must match Packages/SquirlCore verbatim
          swift-configuration: 'release'
          # 16 KB alignment flags on r27d — mandatory on every .so:
          swift-build-flags: >-
            -Xlinker -z -Xlinker max-page-size=16384
            -Xlinker -z -Xlinker common-page-size=16384
          run-tests: true                              # executes the fixture suite on the emulator
          free-disk-space: true

  # ── Job 2: assemble debug APK from the Skip-generated Gradle project ──
  assemble-apk:
    runs-on: macos-15               # Skip is macOS-first; assembleDebug needs NO emulator, so ARM is fine
    steps:
      - uses: actions/checkout@v6            # monorepo — no submodules

      - uses: actions/setup-java@v4
        with: { distribution: 'temurin', java-version: '21' }   # Gradle 9 needs JDK 17+

      # Host Swift toolchain via swiftly, pinned (P0.1 §3.1)
      - name: Install swiftly + Swift 6.3.3
        run: |
          curl -fsSL https://swiftlang.github.io/swiftly/swiftly-install.sh | bash -s -- -y
          . "$HOME/.swiftly/env.sh"
          swiftly install 6.3.3 && swiftly use 6.3.3

      # Swift Android SDK — checksum is MANDATORY (SwiftPM throws checksumNotProvided without it). Cached.
      - name: Cache Swift Android SDK
        id: sdk-cache
        uses: actions/cache@v4
        with:
          path: ~/.swiftpm/swift-sdks
          key: swift-android-sdk-6.3.3-RELEASE
      - name: Install Swift Android SDK
        if: steps.sdk-cache.outputs.cache-hit != 'true'
        run: |
          . "$HOME/.swiftly/env.sh"
          swift sdk install \
            https://download.swift.org/swift-6.3.3-release/android-sdk/swift-6.3.3-RELEASE/swift-6.3.3-RELEASE_android.artifactbundle.tar.gz \
            --checksum d160cc3206dd1886dae3fef2337af5e25ec034692cd0ec225721c56cc69da7f5

      # NDK r27d pinned (r27 needs the manual 16 KB flags; do not float — P0.1 §6). Cached via setup-ndk.
      - name: Setup NDK r27d
        id: setup-ndk
        uses: nttld/setup-ndk@v1
        with: { ndk-version: r27d, local-cache: true }
      - run: echo "ANDROID_NDK_ROOT=${{ steps.setup-ndk.outputs.ndk-path }}" >> "$GITHUB_ENV"

      - name: Cache Gradle
        uses: actions/cache@v4
        with:
          path: |
            ~/.gradle/caches
            ~/.gradle/wrapper
          key: gradle-${{ hashFiles('Android/**/*.gradle.kts','Android/gradle/wrapper/gradle-wrapper.properties') }}

      - name: Assemble debug APK
        working-directory: Android
        run: ./gradlew :app:assembleDebug --no-daemon --stacktrace
        # Skip's Gradle build drives `swift build --swift-sdk aarch64-unknown-linux-android28
        # --static-swift-stdlib` and links the .so; pass the 16 KB flags via the Skip/skip.yml
        # build config or a gradle property so the Swift .so is aligned too.

      # ── 16 KB gate (P0.1 §4) — the local script, run identically in CI ──
      - name: 16 KB alignment gate
        run: scripts/android/check-alignment.sh Android/app/build/outputs/apk/debug/app-debug.apk
        # wraps check_elf_alignment.sh (vendored+pinned from android/ndk-samples); non-zero exit on any
        # non-16384 .so FAILS the build.

      - uses: actions/upload-artifact@v4
        with: { name: app-debug-apk, path: Android/app/build/outputs/apk/debug/app-debug.apk }
```

**CI-equivalent local scripts** (checked in; CI calls the *same* files so a green push == a green desk-run):
- `scripts/android/check-alignment.sh <apk>` — the P0.1 §4 gate. Extracts `lib/arm64-v8a/*.so`, runs the pinned `check_elf_alignment.sh`, greps for anything not `ALIGNED (16384)`, exits non-zero on any 4096/`0x1000` result.
- `scripts/android/run-fixtures.sh` — the P0.4 fixture-runner ([ANDROID_PHASE0.md:1019](ANDROID_PHASE0.md#L1019)): `swift build --swift-sdk aarch64-unknown-linux-android28` the `fixture-runner` executable target (declared in `Packages/SquirlCore/Package.swift`, P1-A), `adb push` binary+fixtures to `/data/local/tmp`, `adb shell` run, assert byte-identical per-case output. **CI authority = Job 1 `swift test` on the emulator; `run-fixtures.sh`/adb runs this executable as the local + fallback path. Both consume the identical `ExtractorFixtures/` directory.**

### Dependency / version pinning

| Component | Pin | Why / source |
|---|---|---|
| Swift host + Android SDK | `6.3.3` / `swift-6.3.3-RELEASE_android.artifactbundle` **by `--checksum`** | No platform owner → self-support; never float ([ANDROID_PHASE0.md:375](ANDROID_PHASE0.md#L375)). |
| NDK | **r27d** exactly | Doc-pinned floor; r27 needs manual 16 KB flags — a bump is its own reviewed change with full §4/§5 re-verify. |
| Skip | **1.9.4** (or `skip checkup --native`-verified) | Version: [github.com/skiptools/skip/releases](https://github.com/skiptools/skip/releases); free/OSS ([skip.dev/pricing](https://skip.dev/pricing/)); record `skip --version` in CI logs. |
| AGP / Gradle | whatever `skip init` emits; enforce AGP ≥ **8.9.1** for `compileSdk 36` (9.1.1 only if targeting 37), Gradle ≥ AGP-min (9.3→**9.5.0**) | [about-agp](https://developer.android.com/build/releases/about-agp). Don't hand-bump ahead of Skip. |
| JDK | **21 (LTS)**, min 17 | Gradle 9 requires 17+ ([gradle.org/whats-new/gradle-9](https://gradle.org/whats-new/gradle-9/)). |
| `check_elf_alignment.sh` | vendored + pinned commit under `scripts/android/` | It *is* the gate tool — pin it, don't `curl` at runtime ([ANDROID_PHASE0.md:354](ANDROID_PHASE0.md#L354)). |
| `swift-android-action` | `@v2` | Marketplace major tag ([github.com/skiptools/swift-android-action](https://github.com/skiptools/swift-android-action)). |

All pins live **in-repo** (workflow YAML, `gradle-wrapper.properties`, `Package.swift`, a `TOOLCHAIN.lock`-style note) so a toolchain regression is a reviewable diff, not a silent float.

### Exit criteria (binary)

1. `skip init --native-app` project committed; `skip checkup --native` green on the host; `Android/` opens and `./gradlew :app:assembleDebug` succeeds locally.
2. `.github/workflows/android.yml` is the first workflow in the repo and **runs on every push** (verified by a green run on the feature branch, not asserted from the file).
3. **Job 2 produces `app-debug.apk`** with `libSwiftCore.so` + `libc++_shared.so` present, `libc++_shared.so` appearing **exactly once** (`pickFirsts` working — no duplicate-`.so` failure).
4. **16 KB gate is a hard CI failure**: `scripts/android/check-alignment.sh` exits non-zero on any non-`16384` `.so` and the pipeline goes red (prove it by temporarily dropping a flag → red → restore).
5. **Fixture parity is a hard CI failure**: Job 1 runs the golden-fixture suite on the emulator and any byte-diff fails the build; host `swift test` and the emulator run agree.
6. Pins are all in-repo and echoed in CI logs (`swift --version`, `skip --version`, NDK path, AGP/Gradle from `./gradlew --version`).

### Risks & effort

| Risk | Impact | Mitigation |
|---|---|---|
| **Skip-CLI-on-Linux uncertainty for the assemble job.** Skip is macOS-first; whether the full Fuse Gradle build runs headless on `ubuntu-latest` is unverified. | Job 2 runner choice / cost. | Default Job 2 to `macos-15` (ARM is fine — assembleDebug needs no emulator). Test an Ubuntu variant Day 1; if it works, it's cheaper. |
| **16 KB flags not reaching the Swift `.so` through Skip's Gradle build.** Skip owns the `swift build` invocation; injecting `-Xlinker` flags may need a `Skip/skip.yml` build-config or gradle property, not the CI `swift-build-flags` input. | Silent 4 KB `.so` → Play upload reject. | The `check-alignment.sh` gate catches it every build; Day-1 task is finding the exact Skip-side flag injection point and documenting it. |
| **`libc++_shared.so` from r27 is 4 KB-aligned.** NDK-prebuilt, not covered by our linker flags. | Gate red even when our own `.so`s pass. | P0.1 §4 contingency: source that single file from an r28+ NDK while keeping the r27d build; automate the swap in the assemble job. |
| **macOS runner minutes cost** (Skip build is heavy; macOS minutes bill 10×). | CI budget. | `concurrency: cancel-in-progress`; cache SDK/NDK/Gradle aggressively (above); consider self-hosted or the Ubuntu path once viable. |
| **`swift-android-action` emulator can't run the `fixture-runner` executable target** (it runs `swift test`, not arbitrary executables). | Job 1 parity gate gap. | Make the fixture suite a real `swift test` (Swift Testing) target so the action runs it natively; keep `run-fixtures.sh`/adb as the local + fallback path. |
| **Skip pins an AGP/Gradle behind `compileSdk 36`.** | Build fails on API 36. | Enforce AGP ≥ 8.9.1 (API-36 floor, about-agp) only if Skip's default is older; otherwise leave Skip's pins. |

**Effort: ~4–5 engineer-days.** Day 1: `skip init` + `skip checkup --native`, local `assembleDebug`, wire the four Play values + `pickFirsts`, find the Skip-side 16 KB flag injection. Day 2: both CI jobs green on the branch (SDK/NDK/Gradle caching, runner selection). Day 3: harden the two gates into hard failures + prove-red-then-green for each. Day 4–5: contingency buffer (Skip-on-Linux experiment, r28 `libc++_shared` swap, macOS-minutes tuning). Front-loaded risk is the Skip↔Gradle 16 KB flag path and the assemble-runner decision.

### Cross-phase dependencies & assumptions

*(G0 gating detail and the intra-Phase-1 dependency on P1-A's Android-buildable packages are consolidated in the final section. Retained here: what Phase 2/3 add into this pipeline + standing runner assumptions.)*

- **Feeds Phase 2 (STT, extractor wiring, UI):** those add modules/deps *into the scaffold and pipeline this workstream owns*. The STT model (P0.2 winner: whisper-small q8_0 264 MB vs Parakeet int8 ≈640 MB) drives a Play **asset-pack** build step added later — out of scope here, but the Gradle project must not preclude asset packs (keep base module < 500 MB, [Play Asset Delivery size limits](https://developer.android.com/guide/playcore/asset-delivery)).
- **`bridging:true` module map** (P1-E §7 exit-4) tells this workstream which modules carry JNI glue.
- **Assumes** runners have JDK 17+, `adb`, and (Job 1) KVM. Assumes Skip 1.9.4 behavior holds; a Skip bump is a reviewed change re-running `skip checkup --native`.
- **Explicitly out of scope** (per owner scope ruling, [ANDROID_PORT_PLAN.md:8](ANDROID_PORT_PLAN.md#L8)): TestFlight-style stable channel, widgets/Intents, sync (038) — so no release-signing / Play-upload / AAB job here; this pipeline stops at a **debug APK artifact**. Release/AAB + Play readiness is **Phase 3**.

---

## Consolidated risks & sequencing

### Intra-phase run order

Phase 1's five workstreams are not a flat parallel batch — they layer onto one contract:

1. **P1-E's seam contract lands first.** The `JournalRepository` protocol + DTO seam inventory + the iOS-side `@Model`→repository refactor is the gating deliverable: it is **pure Swift, zero Android risk**, verifiable by the existing iOS suite before any Android code exists, and it is what makes the orchestration state machine shareable. Everything else plugs into these contracts. (P1-E §3.3.)
2. **P1-A packages the shared core against the seam.** Once the contracts exist, P1-A extracts the shared Swift — DTOs, extractor (P0.4-fenced), design tokens, and the now-decoupled orchestration VMs + `JournalRepository` protocol — into the `SquirlCore` SPM umbrella. Gated on **P0.1** (Android triple cross-compiles) + **P0.4** (fence + inflection table + fixture parity).
3. **P1-C and P1-D implement the platform contracts.** P1-C implements `JournalRepository` (Path A SkipSQL Swift-side / Path B Room bridged) — **gated on the P0.3 fork decision at G0**, cannot start until the owner picks A or B. P1-D implements `AudioRecordingService`/storage over `AudioRecord`/`MediaCodec` — **pure Kotlin, needs neither the Swift core nor the fork**, so it can start as soon as the scaffold exists. Both consume the P1-A DTO shape and the P1-E contracts.
4. **P1-B: scaffold early, CI gates last.** `skip init --native-app` must land **early** — P1-D and P1-E's on-scaffold round-trip smoke both need it. P1-B's *CI hardening* (16 KB alignment + golden-fixture parity as hard failures) **wraps every workstream at the end**, turning each P0 hand-run gate into an every-push automated gate.

### Ownership (single-source, no duplicate claims)

- **P1-A owns** the DTO value-types (`SquirlModelDTO`: `JournalRecordingDTO` + `JournalSegmentDTO`/`JournalTagDTO`/`JournalMedEventDTO` — a NEW family, distinct from (but validated as tractable by) the app-target export DTOs) **and** the design-token extraction (`SquirlDesignTokens`). P1-C, P1-D, P1-E and P1-B **consume** these; none redefine them.
- **P1-E owns** the `JournalRepository` protocol contract (DTO-speaking, `@MainActor`, `Sendable`) and the `bridging:true` module map. **P1-C implements** it (SkipSQL Swift-side or Room bridged); **P1-D writes** the audio columns (`audioFileName`/`duration`/`fileSize`) through it. P1-C's store/DAO code and P1-E's protocol are the same seam viewed from each side — no duplication of the contract.

### Contradictions reconciled

- **Disk-guard 20 MB vs 50 MB (P1-D).** The shipping iOS code enforces `< 20_000_000` (**20 MB**) as the executable guard at [AudioRecordingServiceImpl.swift:60](../app-four/Services/Audio/AudioRecordingServiceImpl.swift#L60); the 50 MB value at [Constants.swift:11](../app-four/Utils/Constants.swift#L11) is a declared-but-unused constant. **Grounded value = 20 MB.** The port collapses both to a single source of truth (one constant feeding the guard); do not carry both.
- **Persistence engine in P1-E's data-flow diagram.** P1-E labels the persist leaf "Room" illustratively; the `JournalRepository` abstraction is **engine-agnostic** and holds under either P0.3 fork (SkipSQL → Swift-side impl, **no JNI at the persist leaf**; Room → bridged Kotlin impl). The fork changes only P1-E §4's bridged-module list, not the contract — reconciled by annotating the diagram/§4 accordingly.
- **DTO naming (collision guard).** Five app-target types already own the bare names: export `RecordingDTO`/`SegmentDTO`/`TagDTO`/`MedicationEventDTO` ([ExportService.swift:20-91](../app-four/Services/ExportService.swift#L20)) and streaming `TranscriptionSegmentDTO` ([Protocols.swift:48](../app-four/Services/Protocols.swift#L48)). The P1-A persistence family takes the distinct `Journal*` names (`JournalRecordingDTO`/`JournalSegmentDTO`/`JournalTagDTO`/`JournalMedEventDTO`) so importing `SquirlModelDTO` into the app target does not shadow them; the export/streaming types stay app-target-local and are structurally different (export omits `cloudSyncStatus`/`isMockData`, adds `audioBase64`, `status: String`; streaming has `isError`, no `language`, not `Codable`).

### Total effort (honest sum)

| Workstream | Low | High |
|---|---|---|
| P1-A — shared-core extraction | 5 | 7 |
| P1-E-core — data-flow / bridging seam (pure Swift) | 4 | 5 |
| P1-E-smoke — on-scaffold bridge smoke | 1 | 1 |
| P1-C — persistence (Path A Android-only 3–4 / Path B 4–5) | 3 | 5 |
| P1-D — audio capture | 3 | 4 |
| P1-B — scaffold + build + CI (one budget line covering the early-scaffold + late-CI split in the run order) | 4 | 5 |
| **Total (engineer-days)** | **20** | **27** |

**~20–27 engineer-days** against a **3-week (≈15 working-day) wall-clock.** The sum **exceeds** the wall-clock: the 3-week target only holds if the independent workstreams are **parallelized** (solo dev + agent fan-out — P1-D is pure Kotlin and P1-E's iOS refactor is pure Swift, so they run concurrently off the critical path). At 1× serial throughput this is **4–5.4 wall-clock weeks**. Flag: the plan's "3 weeks" is a *parallelized* estimate, not a serial one — surface it as such to the owner.

**Uncosted, out-of-band (not inside the 20–27 days):** if G0 picks **Path A (SkipSQL)**, the iOS **SwiftData→SkipSQL rewrite + a replacement cross-platform sync design that forfeits-and-replaces feature-038 iCloud sync (and its ADP E2E-encryption posture)** is its own **multi-week project** (P1-C flags it as the owner's G0 decision). **Path B keeps the 3-week envelope honest; Path A blows it.** Separately, P1-A inherits **+2–4 d** if P0.4 landed only "green conditional on the iOS-tokenizer hatch."

### Top risks across the phase

1. **Skip↔Gradle 16 KB flag injection + r27 `libc++_shared.so` alignment (P1-B, inherited from P0.1).** Skip owns the `swift build` invocation, so getting `-Xlinker …max-page-size=16384` to reach the Swift `.so` through Skip's Gradle build is unverified, and the NDK-prebuilt `libc++_shared.so` may ship 4 KB-aligned — either → **Play upload rejection**. Mitigation: the `check-alignment.sh` CI gate catches every build; Day-1 task is finding the Skip-side injection point; r28+ `libc++_shared.so` swap is the contingency. **Build-blocking, launch gate.**
2. **The persistence fork is unresolved and expensive (P1-C / P0.3).** P1-C cannot start until G0 picks A or B. Path A is engineering-optimal for the shared core but drags in the uncosted multi-week iOS rewrite and **forfeits shipped 038 iCloud sync**; Path B protects 038 at the cost of a doubled persistence surface + an undocumented Room-via-SkipBridge seam. Owner-gated at G0; pragmatic near-term call is **Path B for v1, Path A as the v2 convergence target**.
3. **`@Model`→`JournalRepository` refactor is wider than it looks (P1-E).** The orchestration VMs mutate `Recording` at many sites; a missed one strands an iOS-only type in the shared core and breaks the Android compile. It is the **critical-path blocker** for P1-A sharing the state machine. Mitigation: do it iOS-first behind the protocol with the SwiftData impl unchanged; the existing suite is the gate; the drain actor's id-across-hop pattern is the template.
4. **Extractor byte-parity must hold by construction (P1-A / P0.4).** The 718-entry lexicon and the inflection table are compiled-in Swift constants (no `Bundle.main`/`Bundle.module` lookup), and the `LinguisticProvider` fence must leave **no live `NL*` symbol** on the Android build. A drift here silently gives Android a *different vocabulary* than iOS. If P0.4 was only conditionally green, P1-A carries the +2–4 d tokenizer-swap/re-baseline.

### Cross-phase couplings — what Phase 2 consumes

- **STT (Phase 2 step 5):** the P0.2-winning engine integrates as a **Swift `TranscriptionService` wrapping the engine's C API via Swift C interop** (not a Kotlin service), consuming **P1-D's frozen 16 kHz mono float PCM handoff**; the single-engine serialization / pending-drain invariants already live in the shared VMs (P1-E). JNI is confined to PCM-in.
- **Extractor wiring (Phase 2 step 6):** transcript → shared Swift extractor → DTO → `JournalRepository` — **Swift→Swift end to end, zero new bridge**; the golden-fixture suite (P0.4) runs at the DTO output in the **P1-B CI** as the parity guarantee.
- **UI (Phase 2 step 7):** SkipFuseUI reads **`SquirlDesignTokens`** (P1-A) for Paper & Pollen and is the top JNI caller into the bridged VM API (P1-E).
- **Model delivery:** the STT model (whisper-small 264 MB vs Parakeet int8 ≈640 MB) drives a Play **asset-pack** build step; **P1-B's Gradle project must keep the base module < 500 MB** ([Play Asset Delivery size limits](https://developer.android.com/guide/playcore/asset-delivery)) so asset packs remain available. Release/AAB signing + Play readiness is **Phase 3**, explicitly out of P1-B.

### Gate G1 (Foundation complete)

Phase 1 is complete iff **all five workstream exit sets pass AND**:

1. The **P0.3 owner fork is resolved** (Path A or B chosen) before P1-C sign-off.
2. P1-E exit #5 (on-scaffold bridge smoke) is **required**, gating on P1-B-scaffold (reclassified from "opportunistic").
3. Under **Path A**, the iOS SwiftData→SkipSQL app migration + 038 sync replacement are **explicitly excluded** from G1 (separate project; see P1-C cost sheet).
4. Both CI gates (16 KB alignment, golden-fixture parity) are green as **hard** failures on the feature branch.

Only then does Foundation → Phase 2 proceed.
