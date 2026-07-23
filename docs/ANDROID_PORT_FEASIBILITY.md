<!-- Created: 2026-07-21 18:45 WEST · Updated: 2026-07-21 22:08 WEST -->
# Android Port Feasibility — Deep Verification Report (v2)

**Scope.** Claim-by-claim cross-check of the externally produced "Squirl iOS-to-Android Porting Feasibility Study". This v2 report supersedes the same-day v1 pass (recoverable at `git show 3cd4b567:docs/ANDROID_PORT_FEASIBILITY.md`): 52 claims graded via **10 parallel agents** — 6 web-verification, 1 repo-grounding, 2 code-sample audits, 1 adversarial strategy pass. Every external verdict is grounded in a **primary source fetched 2026-07-21**; repo verdicts cite file:line at branch `feat/038-icloud-sync`. Nothing is asserted from memory; inferences are labeled.

---

## 1. Bottom line

- **The port is feasible, and the study's two headline premises hold**: Swift 6.3 (2026-03-24) ships the first official Swift SDK for Android, and Skip is fully free/OSS since v1.7 (2026-01-21).
- **But the study is a pre-2026 snapshot with a broken strategy layer**: of 40 external claims — **18 confirmed, 17 partially true, 5 incorrect**. All three code samples contain crash- or data-loss-class defects. Both roadmaps rest on disproven premises, and the comparison matrix compares options that no longer exist as described.
- **Do not plan work from the study as written.** Use §7 (corrected recommendation) instead.

**Scorecard**

| Section | Claims | ✅ | ⚠️ Partial | ❌ Incorrect |
|---|---|---|---|---|
| §1 Swift-Android toolchain (C1–C7) | 7 | 2 | 3 | 2 |
| §1 swift-java / JNI (C8–C14) | 7 | 2 | 5 | 0 |
| §2 Skip.tools (C15–C24) | 10 | 6 | 3 | 1 |
| §3.2 STT (C25–C30) | 6 | 2 | 3 | 1 |
| §3.3 NLP (C31–C35) | 5 | 3 | 1 | 1 |
| §3.1/§4 Persistence + NDK (C36–C40) | 5 | 3 | 2 | 0 |
| Repo grounding (R1–R8) | 8 | 7 | 1 | 0 |

Code audits: Room sample **7 findings** (1 compile-error, 1 data-loss trap) · OpenNLP sample **7 findings** (silent total failure) · C++/JNI sample **10 findings** (3 crash-class). Strategy layer: **21 adversarial findings**, 5 blocker-level.

---

## 2. Toolchain & interop verdicts (study §1)

| # | Study claim | Verdict | Correction + source |
|---|---|---|---|
| C1 | Swift 6.3 released 2026-03-24 | ✅ | [swift.org/blog/swift-6.3-released](https://www.swift.org/blog/swift-6.3-released/) |
| C2 | Android now "first-class" target | ⚠️ | First **official** SDK release, yes — but Android is not a full "Deployment and Development" platform and has no platform owner on [swift.org/platform-support](https://www.swift.org/platform-support/). Min: **Android 9 / API 28**. |
| C3 | `swift sdk install …android-sdk.artifactbundle.tar.gz` | ❌ | URL is fabricated. Real: versioned bundle `swift-6.3.3-RELEASE_android.artifactbundle.tar.gz` + **mandatory `--checksum`** — [getting-started](https://www.swift.org/documentation/articles/swift-sdk-for-android-getting-started.html) |
| C4 | `swiftly` toolchain manager | ✅ | Same source. |
| C5 | NDK r27c/r27d+ | ⚠️ | Minimum is **r27d** LTS; r27c fails. Same source. |
| C6 | Triples `aarch64-unknown-linux-android` | ⚠️ | Need API suffix: `aarch64-unknown-linux-android28`. Same source. |
| C7 | `swift build --swift-sdk … --triple …` | ❌ | Real: `swift build --swift-sdk aarch64-unknown-linux-android28 --static-swift-stdlib` (no `--triple`). Same source. |
| C8 | `swift-java-jni-core` package | ✅ | Separate repo; product is **`SwiftJavaJNICore`** — [swiftlang/swift-java-jni-core](https://github.com/swiftlang/swift-java-jni-core) |
| C9 | "JavaKit" @JavaClass/@JavaMethod macros | ⚠️ | Macros real; library renamed **SwiftJava** (JavaKit is the stale 2025 name) — [swift-java docs](https://github.com/swiftlang/swift-java) |
| C10 | `jextract` generates Java bindings | ✅ | Subcommand `swift-java jextract`; **JNI mode required for Android** (FFM mode needs JDK 22+) — [GSoC showcase](https://www.swift.org/blog/gsoc-2025-showcase-swift-java/) |
| C11 | `@JavaImplementation` sample code | ⚠️ | Pattern real, signature wrong: Java `String` bridges directly to Swift `String` — `func analyzeText(_ text: String) -> String`, not `JavaString?`/`stringValue()`. |
| C12 | JNI overhead 100–300 ns | ⚠️ | AOSP figures: **~115 ns regular, 25–35 ns with `@FastNative`/`@CriticalNative`** (which the study omits) — [AOSP CriticalNative.java](https://android.googlesource.com/platform/libcore/+/refs/heads/main/dalvik/src/main/java/dalvik/annotation/optimization/CriticalNative.java) |
| C13 | `SwiftArena` cleanup pattern | ⚠️ | Exists (`ofConfined()`/`ofAuto()`), but it's a **Java-side** API in jextract output deallocating Swift instances. |
| C14 | Private libsqlite3 = Play policy violation | ⚠️ | Must-bundle-SQLite is right; enforcement is **Android 7.0+ linker namespaces** (runtime `UnsatisfiedLinkError`), not Play policy — [Android 7.0 changes](https://developer.android.com/about/versions/nougat/android-7.0-changes) |

## 3. Skip.tools verdicts (study §2)

| # | Study claim | Verdict | Correction + source |
|---|---|---|---|
| C15 | v1.7 (Jan 2026) fully free/OSS | ✅ | Announced 2026-01-21 — [skip.dev/blog/skip-is-free](https://skip.dev/blog/skip-is-free/) · [pricing](https://skip.dev/pricing/) |
| C16 | skipstone AGPL-3.0; skip-ui/foundation MPL-2.0 | ⚠️ | License IDs correct (LICENSE.txt verified); the "copyleft only on engine mods" gloss is an inference, not a license term. |
| C17–C18, C20, C22, C24 | Architecture, module roles, UI mappings, SkipWeb, numeric casts | ✅ | Verified against skip.dev docs + skip-ui source; numeric-cast rule scoped to non-Int/Double types. |
| C19 | "Skip Fuse" = optional native add-on | ⚠️ | **Framing inverted: Fuse (natively compiled Swift on the official SDK) is the recommended mode for most apps; transpilation is legacy "Skip Lite"** — [skip.dev/docs/modes](https://skip.dev/docs/modes/) |
| C21 | Map unsupported; `#if !SKIP` idiom | ⚠️ | Map unsupported ✓; current idiom is `#if os(Android)` / `#if SKIP` — [platform customization](https://skip.dev/docs/platformcustomization/) |
| C23 | private members not transpiled | ❌ | No doc support; the real rule: **non-private** code gets *bridged* in Fuse. The study conflates bridging with transpilation. |

Also: the site moved **skip.tools → skip.dev**; SkipSQL exists but is "not a complete ORM" and a **Skip Lite** framework ([skip.dev/docs/modules/skip-sql](https://skip.dev/docs/modules/skip-sql/)); **no SwiftData support exists in Skip**.

## 4. STT verdicts (study §3.2) — the study's most broken section

| # | Study claim | Verdict | Correction + source |
|---|---|---|---|
| C25 | WhisperKitAndroid archived Jan 2026 | ✅ | Deprecation notice in [README](https://raw.githubusercontent.com/argmaxinc/WhisperKitAndroid/main/README.md); archive date snippet-corroborated. |
| C26 | Migrate to LiteRT / argmax-sdk-kotlin | ✅⚠️ | True, but `argmax-sdk-kotlin` is the **commercial** Argmax Pro SDK (GA 2026-03-18): **$1.00–1.33/device/month, 1k-device minimum** — [blog](https://www.argmaxinc.com/blog/argmax-pro-sdk-for-android) · [pricing](https://www.argmaxinc.com/pricing). The study never mentions cost. |
| C27 | whisper.cpp strictly CPU on Android | ⚠️ | Stale: **Vulkan + Qualcomm Adreno OpenCL backends exist** in-tree (custom build; stock Android example is CPU-only, recommends tiny/base) — [whisper.cpp README](https://github.com/ggml-org/whisper.cpp) · [Qualcomm blog](https://www.qualcomm.com/developer/blog/2024/11/introducing-new-opn-cl-gpu-backend-llama-cpp-for-qualcomm-adreno-gpu) |
| C28 | Thermal/battery claims | ⚠️ | Direction right, figures uncited. Citable: Android streaming ~5× slower than realtime; batch 5s audio in 1–2s — [discussion #3567](https://github.com/ggml-org/whisper.cpp/discussions/3567) |
| C29 | sherpa-onnx = near-instant Whisper via NNAPI/QNN | ❌ (operative claim) | **sherpa-onnx QNN does NOT support Whisper** (only Zipformer CTC/Paraformer/SenseVoice — [QNN docs](https://k2-fsa.github.io/sherpa/onnx/qnn/index.html)); NNAPI integration is a fallback-to-CPU flag; **NNAPI itself is deprecated since Android 15** — [NDK docs](https://developer.android.com/ndk/guides/neuralnetworks). Android Whisper in sherpa-onnx is CPU int8. |
| C30 | `whisper_init_from_file` | ❌ | Deprecated: use `whisper_init_from_file_with_params` — [whisper.h](https://raw.githubusercontent.com/ggml-org/whisper.cpp/master/include/whisper.h) |

**Net**: the only productized NPU-accelerated Whisper on Android today is commercial (Argmax Pro). Free paths are CPU-bound; a **device bench (RTF on mid-tier Snapdragon) is the go/no-go**, and a smaller mobile-first model (e.g. Parakeet TDT v3 int8, or SenseVoice for the NPU path) must be in the bake-off.

## 5. NLP + persistence verdicts (study §3.3, §3.1, §4)

| # | Study claim | Verdict | Correction + source |
|---|---|---|---|
| C31 | CoreNLP is GPL v2 | ❌ | **GPLv3+**, and Stanford sells a commercial license — [CoreNLP license](https://stanfordnlp.github.io/CoreNLP/#license). "Don't use" conclusion survives; both stated facts wrong. |
| C32 | CoreNLP too heavy for mobile | ✅ | ~1 GB heap for POS+lemma+NER — [memory docs](https://stanfordnlp.github.io/CoreNLP/memory-time.html) |
| C33–C34 | OpenNLP Apache-2.0, API usage | ✅ | Verified vs 2.5.4 javadoc/source. Unknown lemma sentinel is letter `"O"` only ("0" is dead code). No official Apache `.dict` — community file. |
| C35 | Penn Treebank "VB*" tags | ⚠️ **code-breaking** | Current models emit **UD tags ("VERB")** → `startsWith("VB")` never matches AND Penn-keyed dictionaries miss. Fix: `POSTaggerME(model, POSTagFormat.PENN)` — [models](https://opennlp.apache.org/models.html) · OPENNLP-1539 |
| C36 | SwiftData closed-source | ✅ | — |
| C37 | GRDB official Android support v7.10.0 | ⚠️ misleading | v7.10.0 contains only community "Android and Windows adjustments"; README platform table lists **no Android** — [CHANGELOG](https://github.com/groue/GRDB.swift/blob/master/CHANGELOG.md) |
| C38 | Room entity compiles as written | ⚠️ | UUID ✓ (built-in since 2.4.0-alpha05); **`java.util.Date` has no built-in converter → compile error** without `@TypeConverters` — [Room docs](https://developer.android.com/training/data-storage/room/referencing-data) |
| C39 | CASCADE ≈ SwiftData | ✅ | With caveat: SwiftData default is `.nullify`; Squirl's `Recording.segments` IS `.cascade` ([Recording.swift:60](../app-four/Models/Recording.swift#L60)). |
| C40 | libc++_shared conflict + pickFirsts | ✅ | Verified end-to-end (NDK one-STL rule, AGP `jniLibs.pickFirsts`, swift.org names libc++_shared as a required dep). |

**Big strategic correction**: **Room is Kotlin Multiplatform with iOS support since 2.7.0 (Apr 2025); Room 3.0 (stable 2026-07-01) is KMP-first** — [room releases](https://developer.android.com/jetpack/androidx/releases/room) · [room3](https://developer.android.com/jetpack/androidx/releases/room3). The matrix's KMP row is stale.

## 6. Repo grounding + code-sample audits

**Repo (7/8 ✅)**: WhisperKit v1.0.0 + `openai_whisper-small` ✓; NLTagger/NLTokenizer + 7 signal categories ✓; SwiftData ✓; `SquirlDesignSystem` local SPM package ✓; lexicon **exactly 718** entries across 32 categories ([lexicon.json](../app-four/Resources/lexicon.json)) ✓; `unloadModel()` ✓ ([WhisperKitTranscriptionService.swift:216](../app-four/Services/WhisperKit/WhisperKitTranscriptionService.swift#L216)); under-a-minute target ✓ (DESIGN.md:11). **R6 ⚠️**: every listed `Recording` field exists, but the study omits **15 fields + 2 cascade relationships** (`correctionTags`, `medicationEvents`) and 4 segment fields — its Room mapping is ~half the real schema.

**Room sample**: ❌ compile error (`Date`, no converter; no `@Database` class) · **data-loss trap: `REPLACE` + `ON DELETE CASCADE` silently wipes all segments on every upsert** (use `@Upsert`, Room ≥2.5) — [sqlite.org/lang_conflict](https://www.sqlite.org/lang_conflict.html) · missing FK index (warning + full scans) · `@Relation` returns segments **unordered** · sort semantics depend on the unwritten Date converter.

**OpenNLP sample**: silent total failure via UD tags (C35, double-break) · `lemma != surface` guard nulls base-form verbs ("read", "focus") — logic bug for a lexicon matcher · lowercasing before POS tagging degrades accuracy · `TokenizerME`/`POSTaggerME` documented **not thread-safe** ([javadoc](https://opennlp.apache.org/docs/2.5.4/apidocs/opennlp-tools/opennlp/tools/tokenize/TokenizerME.html)) · sync model load = ANR risk.

**C++/JNI whisper sample** (not shippable): use-after-free race (`whisper_full` not thread-safe per context; bare `ctxPointer`, no lock) · **`NewStringUTF` on raw UTF-8 → CheckJNI VM abort on any non-ASCII output** ([JNI tips](https://developer.android.com/training/articles/perf-jni)) · no JNI null checks · errors swallowed as `""` (lost check-in ≡ empty recording) · missing `<string>` include · `language="en"` hardcoded (contradicts multilingual story) · `n_threads=4` hardcode strictly worse than library default · ~1.9 MB array copy per call (use direct ByteBuffer). Verified-safe (non-findings): `initial_prompt` lifetime OK; `no_context` already defaults `true`.

## 7. Strategy layer — corrected (adversarial pass, 21 findings)

**Comparison matrix — discard.** Percentages are unsourced and internally incoherent (rewrite-in-Kotlin = 60% but rewrite-in-Dart = 0%); the Skip and Native-Swift columns are **no longer distinct** (Fuse *is* native Swift compilation, so post-1.7 the Skip column dominates the JNI column at $0); the KMP row ignores Room-KMP + stable Compose Multiplatform for iOS.

**Roadmap A — fails as written**: sherpa-onnx step rests on the disproven Whisper-QNN premise; "verify with XCTest serial suites" is incoherent (XCTest doesn't run on Android; Fuse has no automatic test carry-over for the repo's 67 XCTest files); "migrate SwiftData to skip-sql in 14d" assumes SwiftData support Skip doesn't have and mixes Lite-mode SkipSQL into a Fuse plan; UI step targets the legacy transpiler mode.

**Roadmap B — both pillars collapse**: the C++/Rust NLP rewrite is unnecessary (the Swift extractor compiles natively for Android under Fuse; NLTagger is Apple-only but the extractor **already ships a lemma-less fallback** — [CueMatcher.swift:28](../app-four/Services/NoteExtraction/CueMatcher.swift#L28) — and a static inflection table over 718 entries closes the gap in Swift); "unified whisper.cpp" would pin Android to the worst STT option. Residual parity insurance is cheaper as a golden-transcript conformance fixture suite.

**Blocker omissions in the study**:
1. **CoreML/WhisperKit `.mlmodelc` assets cannot run on Android** — a GGUF/ONNX/LiteRT re-bundle with its own WER re-validation is required. Never stated.
2. **Sync (spec 038, in flight)**: CloudKit has no Android peer; sync posture (standalone / `JournalArchive` interchange / backend) is the real strategic decision and is route-independent. Neither roadmap schedules it.
3. Audio capture pipeline (iOS AAC/AVAudioRecorder vs Android `AudioRecord` 16kHz PCM + Android 14 foreground-service mic rules).
4. Widgets / Live Activities (037) / App Intents (030): no Android equivalents; full rewrite, unscheduled.
5. Play size: study silent — and the commonly assumed 200MB is stale; current limits are **500MB base module / 1.5GB asset packs** ([Play docs](https://support.google.com/googleplay/android-developer/answer/9859372)), so whisper-small q8 (252MiB) fits. Model-delivery UX still needs design.

**Corrected recommendation** (grounded in the verified facts):
- **Default route: revised Option A on Skip Fuse** — natively compiled Swift (official 6.3 SDK), extractor reused verbatim, $0 licensing, one logic codebase for a solo dev. Option B (C++/Rust core) is strictly worse here: 3 languages, 2 UIs, both original justifications disproven.
- **Decide sync posture during 038 — now.** No-regret move regardless of the port: keep `JournalArchive` export versioned as the interchange format, and keep the extractor free of Apple-only imports behind its existing fallback.
- **Hold the port until v1.0 (uploaded 2026-07-21) shows Android demand.** When revisited, gate any roadmap on a Phase-0 week: (1) STT bake-off on a mid-tier Snapdragon (~20 golden clips: Parakeet TDT v3 int8 vs whisper-small q8_0 CPU vs SenseVoice-QNN), (2) Skip Fuse spike (check-in screen + one SkipSQL/Room table), (3) extractor golden-fixture suite. Week-precise Gantt charts before those spikes are false precision.

---
*Method note: 6 web agents (toolchain / JNI / Skip / STT / NLP / persistence) + 1 repo agent + 2 code auditors + 1 adversarial agent, all claims graded against primary sources fetched this session; github.com was intermittently unreachable from the sandbox, so GitHub evidence uses raw.githubusercontent.com file contents (noted where a date is snippet-corroborated only).*
