<!-- Created: 2026-07-21 18:45 WEST · Updated: 2026-07-21 18:51 WEST -->
# Android Port Feasibility — Verification Report

**Scope.** Cross-check of the externally produced "Squirl iOS-to-Android Porting Feasibility Study" (2026-07-21). Every checkable claim was graded against **primary sources fetched 2026-07-21** (swift.org, skip.dev, GitHub, developer.android.com, developer.apple.com, opennlp.apache.org, HF model cards) and against **this repo** (branch `feat/038-icloud-sync`). Method: 4 parallel web-verification agents + local code grounding + independent spot-checks of the two most load-bearing quotes. Unverifiable assertions are labeled as such — nothing below is asserted from memory.

---

## 1. Bottom line

**Is an Android port possible? Yes — by at least three routes, none blocked.** The study is *directionally* correct but **unreliable in its specifics**: of 28 concrete claims graded, **12 confirmed · 11 true-but-imprecise (need correction) · 4 false · 1 fabricated module name** (plus one fabricated download URL inside the false set). Its percentages, timelines, and performance numbers are unverifiable estimates and should not be planned against.

The four errors that would actually hurt a plan:

1. **The STT acceleration story is wrong.** sherpa-onnx does *not* give Whisper NPU acceleration — its 2026 QNN support covers Paraformer/Zipformer only, and NNAPI is deprecated (Android 15) and broken/slower in practice. Whisper on Android open-source stacks is **CPU-bound**. The best real options the study missed: **NVIDIA Parakeet TDT 0.6b v3 int8 (25 European languages, free, working sherpa-onnx Android APK)** or Qualcomm AI Hub's QNN-compiled Whisper.
2. **GRDB.swift has no official Android support** (v7.10.0 merged two build-compat tweaks; README lists Apple platforms only). The native-Swift route's persistence story is weaker than claimed.
3. **Skip is described as a transpiler; since v1.8 the recommended mode is Skip Fuse (natively compiled Swift)** — and **SwiftData is confirmed unsupported** in Skip (SkipSQL only), so persistence is a rewrite on every route.
4. **The single biggest omission: iCloud sync (spec 038, being built on this very branch).** CloudKit has no Android SDK; the web-services API is archive-status with an opaque `CD_`-prefixed mirror schema. Cross-device sync strategy — not UI or STT — is the real strategic decision of any port.

**Timing (flagged once, per role):** Squirl 1.0 (build 2) was uploaded to App Store Connect *today* and tagged `v1.0` ([DEVLOG 2026-07-21 18:47](DEVLOG.md)). An Android port started now competes with launch, and there is no Android demand signal yet. The correct move is to make the *sync architecture decision* Android-aware now (cheap), and revisit the port after v1.0 ships with real user data.

---

## 2. Claim-by-claim scorecard

Verdict key: ✅ confirmed · ⚠️ partly true (correction needed) · ❌ false · 🚫 fabricated/not found · ❓ unverifiable.

### 2.1 Option 1 — Native Swift on Android (study §1)

| # | Study claim | Verdict | Corrected fact + source |
|---|---|---|---|
| A1 | Swift 6.3 released 2026-03-24; Android "first-class" | ⚠️ | Date exact; 6.3 ships the **first official Swift SDK for Android** ("Swift 6.3 includes the first official release of the Swift SDK for Android" — [swift.org/blog/swift-6.3-released](https://www.swift.org/blog/swift-6.3-released/), spot-checked). But swift.org classifies Android as **"Deployment-only"**, not full first-class — [swift.org/platform-support](https://www.swift.org/platform-support/) |
| A2 | Install via `…/android-sdk/android-sdk.artifactbundle.tar.gz` | ❌ | That URL **404s** (curl-verified). Real, documented command: `swift sdk install https://download.swift.org/swift-6.3.3-release/android-sdk/swift-6.3.3-RELEASE/swift-6.3.3-RELEASE_android.artifactbundle.tar.gz --checksum d160cc…` — [Getting started](https://www.swift.org/documentation/articles/swift-sdk-for-android-getting-started.html) |
| A3 | NDK r27c/r27d; min API unstated | ⚠️ | Docs say **NDK LTS r27d or later** (r27c not documented); **min Android API 28 / Android 9** (~91.7% of devices per workgroup) — [getting started](https://www.swift.org/documentation/articles/swift-sdk-for-android-getting-started.html), [forums thread](https://forums.swift.org/t/android-api-minimum-for-the-swift-sdk-for-android/82874) |
| A4 | Triples `aarch64-unknown-linux-android` | ⚠️ | Documented SDK ids carry the API suffix: `swift build --swift-sdk aarch64-unknown-linux-android28 --static-swift-stdlib` (same doc) |
| A5 | `swiftly` manages toolchains | ✅ | "The easiest and recommended way… is to use the swiftly command" (same doc) |
| A6a | `swift-java-jni-core` package | 🚫 | **No such module** in [swiftlang/swift-java](https://github.com/swiftlang/swift-java) (Sources listing checked via GitHub API). Real modules: `SwiftJava`/`JavaKit`, `SwiftJavaMacros`, `JExtractSwiftLib`, … |
| A6b | `@JavaClass`/`@JavaMethod`, `@JavaImplementation`, jextract, SwiftArena | ✅ | All exist in swift-java. Crucial nuance: jextract has **FFM mode (JDK 25+, default) and JNI mode — only JNI mode works on Android** ("even Android systems can be supported by this mode" — repo README) |
| A7 | JNI overhead 100–300 ns | ⚠️ | No source states that range. AOSP's measured figure: **regular JNI ≈115 ns** (Fast ≈60, @CriticalNative ≈25) — [AOSP CriticalNative.java](https://android.googlesource.com/platform/libcore/+/master/dalvik/src/main/java/dalvik/annotation/optimization/CriticalNative.java). Advice (batch, don't chat) stands |
| A8 | Must bundle `libc++_shared.so`; conflicts | ⚠️ | Bundling requirement confirmed on swift.org ("along with the required libc++_shared.so dependency"). Conflict behavior is documented by Android, not swift.org: two versions ⇒ "only one will be installed to the APK and that may lead to unreliable behavior" — [NDK middleware guide](https://developer.android.com/ndk/guides/middleware-vendors). `pickFirsts` fix is the standard workaround |
| — | (gap the study missed) | ℹ️ | **Google Play 16 KB page-size rule**: since **2025-11-01** new apps/updates targeting Android 15+ must be 16 KB-aligned — [page-sizes](https://developer.android.com/guide/practices/page-sizes). Swift's Android runtime got the 16 KB linker flag in 6.2.1 ([swift#83809](https://github.com/swiftlang/swift/pull/83809)); NDK r28+ aligns by default. Every bundled `.so` (STT engine included) must comply |

### 2.2 Option 2 — Skip.tools (study §2)

| # | Study claim | Verdict | Corrected fact + source |
|---|---|---|---|
| B1 | v1.7 (Jan 2026): fully free, all fees removed | ✅ | "As of Skip 1.7, all licensing requirements have been removed." — [skip.dev/blog/skip-is-free](https://skip.dev/blog/skip-is-free/) (2026-01-21, spot-checked). Site is now **skip.dev**; funded by sponsorships — [pricing](https://skip.dev/pricing/) |
| B2 | skipstone AGPL-3.0; skip-ui/skip-foundation MPL-2.0 | ✅ | LICENSE files confirm: [skipstone](https://github.com/skiptools/skipstone) AGPL-3.0; [skip-ui](https://github.com/skiptools/skip-ui), [skip-foundation](https://github.com/skiptools/skip-foundation), [skip-model](https://github.com/skiptools/skip-model) MPL-2.0. No copyleft exposure for app code |
| B3 | Skip = Swift→Kotlin transpiler; "Skip Fuse" integrates native Swift *alongside* | ⚠️ | Outdated framing. Two modes: **Skip Lite** (transpiled) and **Skip Fuse** (Swift compiled natively with the official Swift Android SDK; SwiftUI bridged to Compose via [skip-fuse-ui](https://github.com/skiptools/skip-fuse-ui)). Docs: native mode "is the mode we recommend for most apps" — [docs/modes](https://skip.dev/docs/modes/). Skip 1.8 (2026-03-26) adopted the Swift 6.3 SDK; latest skipstone 1.9.4 (2026-06-26) |
| B4 | Private properties are hidden from transpiled Kotlin | ❌ | Conflation. The visibility rule is a **Fuse bridging rule for SwiftUI Views** ("Private views and properties are not visible to Skip's bridging layer"), and docs state explicitly: "These restrictions do not apply to transpiled Skip Lite SwiftUI" — [app-development](https://skip.dev/docs/app-development/) |
| B5 | `Map` unsupported; SkipWeb wraps android.webkit.WebView | ✅ | Map absent from SkipUI's supported list; SkipWeb: "On iOS it uses a WKWebView and on Android it uses an android.webkit.WebView" — [skip-ui README](https://github.com/skiptools/skip-ui), [skip-web](https://skip.dev/docs/modules/skip-web/). (Squirl uses neither — low relevance.) Fuse conditional is `#if !os(Android)`, not `#if !SKIP` |
| B6 | Kotlin strict numerics ⇒ explicit casts | ✅ | "Kotlin can be picky about converting between numeric types… you should be explicit" — [swiftsupport](https://skip.dev/docs/swiftsupport/) (Lite mode) |
| B7 | Persistence via skip-sql (implies no SwiftData) | ✅ | **SwiftData is not supported by Skip at all** as of 2026-07. SkipSQL = "low-level access to the… SQLite3 library"; ORM "considered", none released — [FAQ](https://skip.dev/docs/faq/), [discussion #124](https://github.com/orgs/skiptools/discussions/124) |
| B8 | `@State/@Binding` → `remember { mutableStateOf() }` | ✅ | Mechanism confirmed: observable properties backed by Compose `MutableState` — [skip-model README](https://github.com/skiptools/skip-model) |

### 2.3 Speech-to-text (study §3.2)

| # | Study claim | Verdict | Corrected fact + source |
|---|---|---|---|
| C1 | WhisperKitAndroid deprecated & archived Jan 2026; migrate to LiteRT via argmax-sdk-kotlin | ✅ | Archive banner: "archived by the owner on **Jan 24, 2026**" — [WhisperKitAndroid](https://github.com/argmaxinc/WhisperKitAndroid). Nuance: `argmax-sdk-kotlin` is a **commercial SDK** (token+API key; only a [playground repo](https://github.com/argmaxinc/argmax-sdk-kotlin-playground) is public), and Argmax's Android flagship is **streaming Parakeet on LiteRT, not Whisper** — [Argmax blog 2026-03-18](https://www.argmaxinc.com/blog/argmax-pro-sdk-for-android) |
| C2 | whisper.cpp on Android: strictly CPU/NEON, no Vulkan/NNAPI | ⚠️ | Out-of-the-box CPU-only: true (Android example ships no GPU flags; recommends tiny/base). But ggml **does** have Vulkan (`-DGGML_VULKAN=1`) and OpenCL/Adreno backends — they are DIY and unstable on Android (device-lost crashes: [#3168](https://github.com/ggml-org/whisper.cpp/issues/3168); unanswered build ask: [#2370](https://github.com/ggml-org/whisper.cpp/issues/2370)). NNAPI: correct, none |
| C3 | sherpa-onnx: "mature, robust NNAPI + QNN (NPU)" ⇒ near-instant Whisper | ⚠️→❌ for Whisper | Whisper in sherpa-onnx = **non-streaming, CPU** ([docs](https://k2-fsa.github.io/sherpa/onnx/pretrained_models/whisper/index.html)). NNAPI: broken/slower in practice ([#958](https://github.com/k2-fsa/sherpa-onnx/issues/958), [ORT #7859](https://github.com/microsoft/onnxruntime/issues/7859)). QNN NPU support **exists since 2026 but only for Paraformer/Zipformer** ([QNN docs](https://k2-fsa.github.io/sherpa/onnx/qnn/index.html), SM8350+). "Near-instant Whisper via NNAPI/QNN" is not a thing today |
| C4 | (implied) NNAPI is a valid 2026 target | ❌ | **NNAPI deprecated in Android 15**: "NNAPI is deprecated… we recommend migrating to… the TF Lite GPU runtime" — [developer.android.com/ndk/guides/neuralnetworks](https://developer.android.com/ndk/guides/neuralnetworks). 2026 paths: LiteRT delegates, ORT QNN EP (quantized models), vendor SDKs |
| C5 | (study's "under a minute" thermal claims) | ❓ | No published RTF for whisper-**small** quantized on a named mid-tier Snapdragon was found; nearest datapoints: tiny.en ≈2.5× realtime on an A311D2 ([report](https://www.atomglitch.com/whisper-android-example/)); research RTFs for medium/large on flagship CPUs ([NPUsper, arXiv 2607.01108](https://arxiv.org/pdf/2607.01108)). **Must be measured in a device spike** |
| C6 | Whisper small footprint | ✅ (sizes verified) | 244 M params ([openai/whisper](https://github.com/openai/whisper)); ggml files: fp16 **466 MiB**, q8_0 **252 MiB**, q5_1 **181 MiB** ([ggerganov/whisper.cpp on HF](https://huggingface.co/ggerganov/whisper.cpp)). Qualcomm QNN float variant ≈924 MB ([qualcomm/Whisper-Small](https://huggingface.co/qualcomm/Whisper-Small)) |

**Corrected STT landscape for Squirl** (transcription is currently **hardcoded English** — [WhisperKitTranscriptionService.swift:133](../app-four/Services/WhisperKit/WhisperKitTranscriptionService.swift#L133)):

| Engine | Accel | Languages | Size | License/cost | Fit |
|---|---|---|---|---|---|
| **sherpa-onnx + Parakeet TDT 0.6b v3 int8** | CPU (fast TDT decoder) | **25 EU languages**, auto-detect | ~0.6 B int8 | Free (Apache/CC-BY-4.0 model) | **Best first candidate** — working [Android APK demo](https://github.com/k2-fsa/sherpa-onnx) exists |
| sherpa-onnx / whisper.cpp + Whisper small q8_0 | CPU only | 99 (multilingual) | 252 MiB | Free (MIT) | Exact model parity with iOS; RTF unproven on mid-tier — spike |
| Qualcomm AI Hub Whisper-Small (QNN) | **NPU** (8 Gen+ only) | multilingual | ~924 MB float / w8a16 quant | Free models, QNN runtime | Premium-device path; heavy assets; fragmentation |
| Argmax Pro SDK (argmax-sdk-kotlin) | NPU/GPU via LiteRT | Parakeet-based | ~5 MB SDK + models | **Commercial** | Buys WhisperKit-equivalent polish; ongoing cost |
| Moonshine (2026 release) | CPU (ONNX .ort) | en/es/zh/ja/ko/vi/uk/ar | 34 MB+ (tiny en) | Open weights | Tiny/fast; language set ≠ EU-centric — [repo](https://github.com/moonshine-ai/moonshine) |
| Android `SpeechRecognizer` on-device | System | device-dependent | 0 | Free | Docs: "not intended… for continuous recognition" — wrong tool for 1-min dictation |

The study's *prompt-injection* concept survives every option that exposes `initial_prompt`/hotwords (whisper.cpp, sherpa-onnx do); Squirl's medical prompt is already opt-out-able ([WhisperKitTranscriptionService.swift:134](../app-four/Services/WhisperKit/WhisperKitTranscriptionService.swift#L134)).

### 2.4 NLP + persistence (study §3.1, §3.3)

| # | Study claim | Verdict | Corrected fact + source |
|---|---|---|---|
| D1 | Stanford CoreNLP is GPL v2 ⇒ avoid | ⚠️ license wrong, conclusion right | "The full Stanford CoreNLP is licensed under the GNU General Public License **v3 or later**" — [stanfordnlp.github.io/CoreNLP](https://stanfordnlp.github.io/CoreNLP/). Avoid stands |
| D2 | OpenNLP: Apache-2.0, legal & lightweight, `.bin`+`.dict` models | ⚠️ | License ✅. But: **no official Android support** (community examples only); OpenNLP 2.x requires **Java 17**, 3.x **Java 21** ([README](https://github.com/apache/opennlp/blob/main/README.md)); `en-pos-maxent.bin` ≈5.4 MB is official, **the English lemmatizer dictionary is NOT an Apache artifact** — the commonly used `en-lemmatizer.dict` (~7.2 MB) is community-sourced. The study's code sample depends on a file Apache doesn't ship |
| D3 | GRDB.swift officially supports Android since v7.10.0 | ❌ | README requirements list Apple platforms only; 7.10.0 merged "Android and Windows adjustments" = build-compat tweaks (e.g. [PR #1849](https://github.com/groue/GRDB.swift/pull/1849), a Sendable conformance). Latest: v7.11.1 (2026-06-18). **No official Android support** — [GRDB.swift](https://github.com/groue/GRDB.swift) |
| D4 | System libsqlite3.so private; linking "violates Play Store policies" | ⚠️ | Substance right, framing wrong: it's an **OS/NDK restriction**, not Play policy. SQLite is not in the [NDK stable API list](https://developer.android.com/ndk/guides/stable_apis); since Android 7.0 "the system prevents apps from dynamically linking against non-NDK libraries" — [Android 7.0 changes](https://developer.android.com/about/versions/nougat/android-7.0-changes). Bundle your own SQLite (sqlite.org's own guidance) |
| — | Room mapping code (study §3.1) | ⚠️ incomplete | Structure idiomatic and correct in kind (FK + cascade ≈ `.cascade`), but it maps **2 of 6** `@Model` classes and drops fields — see §3 below |
| — | (gap) Room/KMP status | ℹ️ | Room 2.8.4 stable; KMP stable since 2.7.0; **Room 3.0.0 (androidx.room3) went stable 2026-07-01, Kotlin-first, targets Android + iOS/JVM/JS/Wasm** — [room3 releases](https://developer.android.com/jetpack/androidx/releases/room3) |

### 2.5 Repo-grounded claims (checked against this codebase)

| Study claim | Verdict | Evidence |
|---|---|---|
| Lexicon has **718 items** | ✅ exact | [lexicon.json](../app-four/Resources/lexicon.json) — 32 categories, script-counted total = 718 (largest: moodSpecific 90, medications 89) |
| Whisper **Small** via WhisperKit | ✅ | `modelName = "openai_whisper-small"` — [WhisperKitTranscriptionService.swift:11](../app-four/Services/WhisperKit/WhisperKitTranscriptionService.swift#L11); WhisperKit pinned **1.0.0** (Package.resolved) |
| NLTagger POS + lemmatization drive extraction | ✅ | `NLTagger(tagSchemes: [.lexicalClass, .lemma])` — [CueMatcher.swift:62](../app-four/Services/NoteExtraction/CueMatcher.swift#L62) |
| Room `RecordingEntity` mirrors `Recording` | ⚠️ | Actual [Recording](../app-four/Models/Recording.swift) has **12 more fields** than the study's entity (`cloudSyncStatus`, `summary`, `summaryStatus`, `topicTagsJSON`, `summaryGeneratedAt`, `hasMedication`, `noteExtractionJSON`, `sideEffectsJSON`, `sleepEventJSON`, `emotionsJSON`, `sleepLevelValue`, `isMockData`); `TranscriptionSegment` also has `isFinal`, `confidence`, `language`. Study maps **2 of 6 models** — missing `RecordingTag`, `MedicationEvent`, `AppSettings`, `ModelMetadata` ([AppModelContainer.swift:18-23](../app-four/App/AppModelContainer.swift#L18-L23)) |

A free parity gift the study missed: the extractor **already runs without the lemma model** — NLTagger's lemma data is absent on the iOS simulator, so a surface-form fallback path exists and is exercised ([CueMatcher.swift:28](../app-four/Services/NoteExtraction/CueMatcher.swift#L28)). Android parity therefore does *not* strictly require a lemmatizer on day one; a **static inflection table for the 718 lexicon entries** (the study's own "recommended" option) matches how the code already degrades, and is the right call. OpenNLP becomes optional, not foundational.

---

## 3. What the study missed entirely

1. **iCloud sync (spec 038 — in flight on this branch).** The container mirrors 4 journal models to the user's **private CloudKit DB** ([AppModelContainer.swift:44-52](../app-four/App/AppModelContainer.swift#L44-L52)). There is **no CloudKit SDK for Android**; the only access is CloudKit Web Services — an **archived** doc set, per-round-trip web-auth tokens ("the web authentication token expires 30 minutes after it is created"), Apple-ID web login on Android, and an undocumented-by-contract `CD_`-prefixed Core-Data mirror schema ([Web Services Reference](https://developer.apple.com/library/archive/documentation/DataManagement/Conceptual/CloudKitWebServicesReference/index.html), [CD_ mapping](https://developer.apple.com/documentation/CoreData/reading-cloudkit-records-for-core-data)). Verdict: **workable for one-shot import, brittle as a live sync peer**. Options, in order of sanity:
   - **A. Android standalone, no cross-ecosystem sync** (each platform syncs within its own cloud). Cheapest; honest.
   - **B. One-time migration via the existing encrypted `JournalArchive` export** ([ExportService.swift](../app-four/Services/ExportService.swift), versioned `formatVersion`) — make the archive the cross-platform interchange contract. Low cost, high value; worth doing regardless.
   - **C. Replace CloudKit with a cross-platform backend** (self-hosted or vendor). Conflicts with "Data Not Collected" + zero-server privacy stance unless E2E-encrypted; big scope.
   - **D. CloudKit Web Services client on Android.** Technically exists; brittle (above). Not recommended as the plan of record.
2. **Widgets / Live Activities / App Intents.** Jetpack Glance is the Compose-style widget analog (stable 1.1.1 of 2024-10; 1.2.0 stalled at rc01; 1.3.0-alpha02 — [releases](https://developer.android.com/jetpack/androidx/releases/glance)); there is no Live-Activity equivalent in it, and the 030 App-Intents layer maps to a different Android stack entirely. All UI-adjacent system surfaces are rewrites.
3. **Audio capture pipeline.** iOS records AAC `.m4a` via AVAudioRecorder ([AudioRecordingServiceImpl.swift:15](../app-four/Services/Audio/AudioRecordingServiceImpl.swift#L15)); every Android STT engine consumes 16 kHz mono PCM float — the Android side needs `AudioRecord` (or MediaCodec decode of recorded AAC) plumbing the study never mentions.
4. **Test suite parity.** 67 XCTest files / ~6.2k LOC. Skip transpiles tests to JUnit in Lite mode only; Fuse and all other routes mean a parallel test strategy for ported logic.
5. **Play-side compliance:** 16 KB pages (2.1 table, last row), min API 28 (Swift SDK floor), Play Data-safety form (the iOS "Data Not Collected" story must be re-made for Play), foreground-service rules for recording.
6. **iOS-26-specific UI.** Any Liquid-Glass-era API used by the 50 view files has no SkipUI/Compose counterpart; expect per-screen fallbacks regardless of route (verify in a spike — not graded here).
7. **The comparison matrix's numbers** ("85% logic reuse", "95% UI reuse", week-precise Gantt bars) have no measurable basis. Treat as marketing-shaped placeholders; the corrected qualitative matrix is below.

---

## 4. Corrected option analysis

### Option 1 — Native Swift core + Kotlin/Compose UI (study §1) · **Possible, real, but most plumbing**
- Toolchain is official as of Swift 6.3 (2026-03-24), **Deployment-only** tier, API 28+, NDK r27d+, `--swift-sdk aarch64-unknown-linux-android28`.
- Bridging: swift-java **jextract JNI mode** (FFM mode needs JDK 25 — not Android). SwiftArena is real; ~115 ns/call means batching, exactly as the study says.
- **Weak spot the study hid:** persistence. SwiftData doesn't exist off Apple platforms and **GRDB isn't officially Android-supported** → the shared-Swift core would sit on raw SQLite C or community forks. The "85% shared Swift" figure collapses once models/persistence/STT/UI are all platform-split.
- Choose only if the goal is a shared *pure-logic* Swift kernel (extractor + lexicon + tense rules — which *is* portable Swift with zero Apple imports today, ~4 files) under a fully native Android app.

### Option 2 — Skip Fuse (study §2, corrected) · **Possible, cheapest total effort, now $0**
- Licensing fear is gone: free since 1.7 (2026-01-21); app-side frameworks MPL-2.0; AGPL touches only the build tool.
- Use **Fuse** (native Swift + skip-fuse-ui→Compose), not Lite transpilation the study describes; Skip 1.8+ rides the same official Swift 6.3 SDK as Option 1.
- **Real costs:** SwiftData → SkipSQL/SQLite rewrite of all 6 models + stores; STT via a JNI/Fuse bridge to sherpa-onnx; every unsupported SwiftUI construct across 50 views needs a fallback; internal-visibility rule on bridged Views.
- Best fit for "one Swift codebase, solo dev" — *if* a 3-screen spike proves the UI bridge holds for Squirl's design system.

### Option 3 — Kotlin-native Android app (KMP-flavored or plain) · **Possible, cleanest Android citizen, full rewrite**
- New facts favor it more than the study allowed: **Room 3.0 stable (2026-07-01) is KMP-first and targets iOS too**, and Compose Multiplatform for iOS has been stable since 1.8.0 (2025-05-06) — meaning a Kotlin shared core could *eventually* serve both platforms (inverse of the study's direction).
- Cost: rewrite of ~16k LOC of Swift logic + 50 views; permanent two-codebase (or Kotlin-first) reality. Parity drift risk on the extractor is the study's one honest warning here.

### Option B (study) — C++/Rust shared core · **Possible, highest insurance, highest upfront**
- Unchanged by verification: 100% analytical parity, at the price of rewriting the extractor + persistence in a third language and re-binding on both sides. Overkill while the extractor is 4 pure-Swift files that two platforms could conformance-test against a shared **golden-transcript fixture suite** instead.

### Corrected decision matrix (qualitative — replaces study §5)

| | Skip Fuse | Native Swift core | Kotlin rewrite | C++/Rust core |
|---|---|---|---|---|
| Existing Swift reused | High (logic + most UI) | Logic kernel only | None | None (rewrite) |
| Persistence | Rewrite (SkipSQL) | Weakest (raw SQLite; no GRDB) | Best-in-class (Room 3) | SQLite C (shared) |
| STT | Bridge sherpa-onnx | Bridge sherpa-onnx | Native sherpa-onnx AAR | whisper.cpp unified |
| Extractor parity | Same Swift source ✅ | Same Swift source ✅ | Drift risk — needs golden fixtures | Identical ✅ |
| iCloud/CloudKit sync | ❌ same gap on all four — sync strategy is route-independent | ❌ | ❌ | ❌ |
| Solo-dev maintenance | 1 codebase | 1.5 codebases | 2 codebases | 2 UIs + 1 core |
| Maturity risk | Fuse young (prod apps exist, no marquee) | Deployment-only tier | None | None |
| Verdict | **Default candidate** | Niche | If Android must feel canonical | If parity is existential |

---

## 5. If/when you port — plan inputs

**Phase 0 — decisions & spikes (do before any roadmap):**
1. **Sync ruling** (Option A/B/C from §3.1) — this shapes 038 *now*: keeping the encrypted `JournalArchive` export as a versioned interchange format is a no-regret move.
2. **STT bake-off on a mid-tier device** (e.g. Snapdragon 6-series): Parakeet TDT v3 int8 vs Whisper small q8_0 — measure RTF, battery, accuracy on ~20 golden ADHD check-in clips. No published number exists; this is the port's true go/no-go.
3. **Skip Fuse spike**: check-in screen + calendar card + SkipSQL Recording table. Kills or confirms the default route in ~a week.
4. **Extractor conformance kit**: freeze N transcripts + expected `NoteExtraction` JSON as fixtures; any Android implementation (Swift-shared or ported) must match byte-for-byte. This — not a shared language — is what actually prevents parity drift.

**Rough effort bands (honest, not week-precise):** Skip Fuse route ≈ 2–4 months solo to closed beta (persistence rewrite + STT bridge + 50-view QA dominate); Kotlin rewrite ≈ 2× that; add model-download UX, Play data-safety, 16 KB/API-28 CI lane to any route.

**Recommendation:** hold until v1.0 ships and shows Android demand; meanwhile (a) rule on sync posture, (b) keep the export format versioned and documented, (c) keep the extractor free of Apple-framework imports (it already nearly is) so every future route stays open.

---

## 6. Residual unknowns (why this is 95%, not 100%)

- **Whisper-small quantized RTF on mid-tier Android CPUs**: no citable measurement exists — must be benched (Phase 0.2).
- **OpenNLP on Android**: community-proven only; if the lemma table route is taken (recommended), this risk evaporates.
- **CloudKit Web Services longevity**: docs are in Apple's archive; no deprecation notice, but no contract either.
- **Skip Fuse coverage of Squirl's exact SwiftUI surface** (incl. any iOS-26 APIs): unverified until the spike.
- All study percentages/timelines: unverifiable by construction.

## 7. Source index

**Swift/Android:** [6.3 release](https://www.swift.org/blog/swift-6.3-released/) · [nightly SDK announcement](https://www.swift.org/blog/nightly-swift-sdk-for-android/) · [SDK getting started](https://www.swift.org/documentation/articles/swift-sdk-for-android-getting-started.html) · [platform support](https://www.swift.org/platform-support/) · [min-API forum thread](https://forums.swift.org/t/android-api-minimum-for-the-swift-sdk-for-android/82874) · [swift-java](https://github.com/swiftlang/swift-java) · [AOSP JNI costs](https://android.googlesource.com/platform/libcore/+/master/dalvik/src/main/java/dalvik/annotation/optimization/CriticalNative.java) · [16 KB pages](https://developer.android.com/guide/practices/page-sizes) · [swift#83809](https://github.com/swiftlang/swift/pull/83809) · [NDK middleware](https://developer.android.com/ndk/guides/middleware-vendors)
**Skip:** [skip-is-free](https://skip.dev/blog/skip-is-free/) · [pricing](https://skip.dev/pricing/) · [modes](https://skip.dev/docs/modes/) · [swiftsupport](https://skip.dev/docs/swiftsupport/) · [app-development](https://skip.dev/docs/app-development/) · [FAQ](https://skip.dev/docs/faq/) · [skipstone](https://github.com/skiptools/skipstone) · [skip-ui](https://github.com/skiptools/skip-ui) · [skip-fuse-ui](https://github.com/skiptools/skip-fuse-ui) · [InfoQ](https://www.infoq.com/news/2026/01/swift-skip-open-sourced/)
**STT:** [WhisperKitAndroid (archived)](https://github.com/argmaxinc/WhisperKitAndroid) · [Argmax Pro SDK](https://www.argmaxinc.com/blog/argmax-pro-sdk-for-android) · [whisper.cpp](https://github.com/ggml-org/whisper.cpp) · [sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx) · [sherpa QNN](https://k2-fsa.github.io/sherpa/onnx/qnn/index.html) · [NNAPI deprecation](https://developer.android.com/ndk/guides/neuralnetworks) · [ORT QNN EP](https://onnxruntime.ai/docs/execution-providers/QNN-ExecutionProvider.html) · [qualcomm/Whisper-Small](https://huggingface.co/qualcomm/Whisper-Small) · [parakeet-tdt-0.6b-v3](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3) · [moonshine](https://github.com/moonshine-ai/moonshine) · [ggml whisper sizes](https://huggingface.co/ggerganov/whisper.cpp)
**NLP/DB/platform:** [CoreNLP license](https://stanfordnlp.github.io/CoreNLP/) · [OpenNLP](https://opennlp.apache.org/) · [OpenNLP README](https://github.com/apache/opennlp/blob/main/README.md) · [GRDB](https://github.com/groue/GRDB.swift) · [NDK stable APIs](https://developer.android.com/ndk/guides/stable_apis) · [Android 7.0 linker](https://developer.android.com/about/versions/nougat/android-7.0-changes) · [Room](https://developer.android.com/jetpack/androidx/releases/room) · [Room 3](https://developer.android.com/jetpack/androidx/releases/room3) · [Glance](https://developer.android.com/jetpack/androidx/releases/glance) · [CloudKit Web Services](https://developer.apple.com/library/archive/documentation/DataManagement/Conceptual/CloudKitWebServicesReference/index.html) · [CD_ schema](https://developer.apple.com/documentation/CoreData/reading-cloudkit-records-for-core-data) · [Compose MP 1.8](https://blog.jetbrains.com/kotlin/2025/05/compose-multiplatform-1-8-0-released-compose-multiplatform-for-ios-is-stable-and-production-ready/)
**Repo:** [Recording.swift](../app-four/Models/Recording.swift) · [TranscriptionSegment.swift](../app-four/Models/TranscriptionSegment.swift) · [AppModelContainer.swift](../app-four/App/AppModelContainer.swift) · [WhisperKitTranscriptionService.swift](../app-four/Services/WhisperKit/WhisperKitTranscriptionService.swift) · [CueMatcher.swift](../app-four/Services/NoteExtraction/CueMatcher.swift) · [lexicon.json](../app-four/Resources/lexicon.json) · [ExportService.swift](../app-four/Services/ExportService.swift) · [AudioRecordingServiceImpl.swift](../app-four/Services/Audio/AudioRecordingServiceImpl.swift)
