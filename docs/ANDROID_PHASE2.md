<!-- Created: 2026-07-22 01:34 WEST · Updated: 2026-07-22 11:06 WEST -->
# Android Port — Phase 2 (Core loop) → builds on Phase 1

**Scope.** This document expands **Phase 2 (Core loop)** of [ANDROID_PORT_PLAN.md](ANDROID_PORT_PLAN.md) (v1.1) into five execution-ready workstream specs. Phase 2 is the 4-week build of the signature loop — **record → transcribe → extract → persist → display** — split into: on-device **STT integration** (plan step 5), **model packaging & delivery**, the **extractor wired end-to-end** (plan step 6), the **UI build-out** of the four core-loop surfaces (plan step 7), and the **integration/state capstone** that makes the loop crash-durable. It is **conditional on G0 and Phase 1**: nothing here is scheduled until all four Phase 0 spikes pass (a red **P0.2** parks the port entirely) and the Phase 1 shared-core/scaffold/persistence/audio work has landed. Phase 2 **carries the forks Phase 0 left open**: the **P0.2 STT-winner fork** (whisper.cpp CPU q8_0 / Parakeet TDT int8 / Whisper-on-QNN), the **P0.3 persistence fork** (SkipSQL vs Room) and the **P0.3 glyph fork**, and the **P0.4 extractor-fence hatch**.

**Provenance.** Five workstream sections (P2-A…P2-E) were each drafted by a dedicated Opus/MAX engineer-agent (2026-07-22) and **assembled** into this document; the assembled document was then **independently reviewed by three Opus/MAX adversarial agents (Lens A accuracy · Lens B executability · Lens C repo/cross-phase) and the findings merged back in** (2026-07-22). Sourcing standard is unchanged: external claims carry an inline cited URL; repo claims carry `file:line` (verified against the working tree on `feat/038-icloud-sync`, 2026-07-22). Assembly explicitly **reconciled three cross-section contradictions** rather than concatenating them: (1) the **glyph reality supersedes the P0.3 assumption** (see the ⚠ callout in P2-D and Consolidated); (2) the STT native seam is described by **one bridge contract** (defined in P2-A; cited, not re-invented, by P2-B and P2-E); (3) the **audited-standard deviations** the STT winner may force are surfaced once, in Consolidated. A **second adversarial round** (2026-07-22, three fresh Opus reviewers — cross-doc consistency · leftover verification · sources audit — merged by a Fable agent) applied the outstanding round-1 findings, reconciled the RAM/mmap and abort-seam contradictions to the cross-doc contract of record (`transcribe(pcm)` + push-style `cancel()` + `isDecoding` + `unloadModel`), and hardened the citations to primary sources.

---

## Workstreams at a glance

| Workstream | One-line goal | Exit gate (binary) | Budget |
|---|---|---|---|
| **P2-A — STT JNI** | Bridge the P0.2-winning on-device STT engine into the app to the audited JNI standard | End-to-end parity with the P0.2 harness; jbyteArray / mutex / DirectBuffer / thrown-error contract honored; every `.so` 16 KB-aligned | **2–7 d** (branch-dependent) |
| **P2-B — Model delivery** | Ship the STT model via an install-time Play asset pack; own load→resident→unload | AAB builds with an install-time pack; airplane-mode first-run transcribes; explicit unload frees ≈ model-size RSS | **2–3 d** (+1–2 if Strategy 2) |
| **P2-C — Extractor wiring** | Run the *shared* Swift extractor on Android transcripts → DTO → persist, byte-parity held | On-device loop persists correct row; golden-fixture gate build-gating + green; STT-output normalizer + its own gate green | **6–9 d** |
| **P2-D — UI build-out** | Build the four core-loop screens from shared SwiftUI via SkipFuseUI at iOS-acceptable fidelity | 4 screens green on a physical arm64 device; glyph `Shape` port renders; aggregate erosion cap not exceeded | **10–12 d** |
| **P2-E — Integration & state** | Wire the crash-durable loop; port the iOS state machine + three-mechanism recovery | Kill-at-every-boundary always converges to `completed`/`failed`, no lost capture; all 10 exit criteria | **5–7 d** |

---

## P2-A — STT engine JNI integration

Workstream section of Android-port **Phase 2 (Core loop)**, expanding [ANDROID_PORT_PLAN.md](ANDROID_PORT_PLAN.md) step 5. Bridges the **P0.2-winning** on-device STT engine into the Android app across the JNI boundary, to the audited standard. Ground truth: [ANDROID_PHASE0.md](ANDROID_PHASE0.md) §P0.2 (candidate matrix, still-unresolved go/no-go) and the iOS service it mirrors, [WhisperKitTranscriptionService.swift](../app-four/Services/WhisperKit/WhisperKitTranscriptionService.swift). **This section defines the single STT bridge contract that P2-B and P2-E reference.**

### Goal

Turn the engine that clears the P0.2 gate into a `TranscriptionService` on Android with the **exact service contract of iOS** — lazy idempotent `loadModel()`, a streaming `transcribe()` that emits progress then a final transcript, and an explicit `unloadModel()` that frees the model's native memory *before* the stream completes (iOS frees Whisper's CoreML/Metal buffers before signaling done — [WhisperKitTranscriptionService.swift:172-177](../app-four/Services/WhisperKit/WhisperKitTranscriptionService.swift#L172), [:216](../app-four/Services/WhisperKit/WhisperKitTranscriptionService.swift#L216)). The native boundary must obey the plan's audited JNI standard ([ANDROID_PORT_PLAN.md](ANDROID_PORT_PLAN.md) §Phase 2 step 5):

1. **Transcript out as a UTF-8 `jbyteArray`, decoded on the Kotlin side** — never `NewStringUTF`, which expects *Modified UTF-8*: a standard-UTF-8 supplementary-plane sequence is invalid MUTF-8, so `NewStringUTF` **aborts the VM under CheckJNI (default on emulators) and silently corrupts the string in production** ([perf-jni](https://developer.android.com/training/articles/perf-jni) — *"Data passed to NewStringUTF must be in Modified UTF-8 format … CheckJNI … aborts the VM if it receives invalid input"*).
2. **Mutex-guarded context handle** — the engine context is not thread-safe; all init/decode/free serialize (mirrors the iOS `actor`).
3. **Direct `ByteBuffer` for PCM** — zero-copy 16 kHz mono float samples via `GetDirectBufferAddress`, not `GetFloatArrayElements` (which pins/copies a Java array).
4. **Errors thrown to Kotlin, never returned as `""`** — an empty string is a valid (silent) transcript and would poison the extractor; failures raise a typed exception.
5. **Thread count left to the library default** (see the sherpa caveat in Risks — the audited default is correct for whisper.cpp, a footgun for sherpa).
6. **`whisper_init_from_file_with_params`** (the non-`_with_params` forms are `WHISPER_DEPRECATED` — [whisper.h](https://github.com/ggml-org/whisper.cpp/blob/master/include/whisper.h)) with **per-engine vocabulary injection**.
7. **A cooperative abort seam + decode-state query** — the contract of record is `transcribe(pcm16kMono: FloatArray)` + **push-style `cancel()`** (a no-arg call that flips an atomic; whisper.cpp's `whisper_full_params.abort_callback` polls it between compute steps), `isDecoding` (the mutex-held decode state), and the already-defined `nativeFree()`/`unloadModel()`. This is a **first-class member of the bridge contract, not an afterthought**, because two downstream workstreams hard-depend on it: **P2-E** rides it for user-initiated cancel (§Concurrency), and **P3-A's thermal guardrail hard-depends on `cancel()`/`isDecoding`/`unloadModel`** ([ANDROID_PHASE3.md](ANDROID_PHASE3.md) — its governor invokes the bridge's `cancel()` when `shouldAbort` trips, and its `onTrimMemory` unload-guard consults `isDecoding`; there is **no pull-style abort-flag decode parameter** — the abort signal travels through `cancel()`, not a closure threaded into `transcribe`). On branch (a) the abort is **per-step** (whisper's `abort_callback`). On branches (b)/(c) the sherpa offline recognizer is invoked **single-shot per utterance and is NOT mid-utterance abortable** — `cancel()` there takes effect only **between queue items** (drop + unload); consequently P3-A's thermal defer on the sherpa branch means *let the in-flight utterance finish (or unload) and defer the rest of the queue*, never a mid-decode abort.

Input is **16 kHz mono float PCM** produced by the Phase 1 audio pipeline ([ANDROID_PORT_PLAN.md](ANDROID_PORT_PLAN.md) §Phase 1 step 4 — `AudioRecord` 16 kHz mono).

### The P0.2 fork — branch per winner

**P0.2 is unresolved and terminal-gated; this workstream does not exist unless one engine passes.** The integration shape differs sharply by which survives, because two of the three candidates ship an **official Kotlin/JNI AAR** and one does not:

| Winner | We write JNI? | Bridge shape | Vocab lever | Delivery |
|---|---|---|---|---|
| **(a) whisper.cpp CPU q8_0** (264 MB) | **Yes** — our own `libsttbridge.so` wrapping whisper.cpp, written to the audited standard | Custom C JNI (below) | `initial_prompt` (soft) | fits 500 MB base module |
| **(b) sherpa-onnx Parakeet TDT v3 int8** (≈640 MB) | **No** — consume the official `OfflineRecognizer` AAR ([kotlin-api/OfflineRecognizer.kt](https://github.com/k2-fsa/sherpa-onnx/blob/master/sherpa-onnx/kotlin-api/OfflineRecognizer.kt)) | Thin Kotlin adapter over the AAR | `hotwordsFile` + `hotwordsScore` (transducer) | asset pack mandatory (>500 MB) |
| **(c) sherpa-onnx Whisper-on-QNN** | **No custom JNI, but a QNN-enabled build** — the stock release AAR omits QNN; build sherpa-onnx from source with `SHERPA_ONNX_ENABLE_QNN=ON` + add Qualcomm QNN runtime `.so`s (license-gated, not shipped; owner spot-check against the current sherpa release before betting on this) | Same adapter, QNN branch | `initial_prompt` (Whisper) — **verify exposed on QNN path** | model + QNN blobs |

**Key architectural consequence of the fork:** the audited jbyteArray/mutex/ByteBuffer/thrown-error rules are things **we implement only on branch (a)** (we own the C). On branches (b)/(c) the JNI is *sherpa-onnx's* — we cannot rewrite its internal marshalling — so the audited rules become an **adaptation contract**: we wrap the AAR so the *service* satisfies them (typed exceptions, mutex-guarded recognizer, unload-before-finish) and we **flag the one rule the AAR violates internally** (its result comes back as a Java `String` via `NewStringUTF` in sherpa's C++, not a jbyteArray — see Risks; the exposure is near-zero for STT because speech transcripts don't contain emoji/supplementary planes, but it is a real deviation to record).

Everything below is written **(a) in full** (the hard case, our code) and **(b)/(c) as the AAR adapter**.

### Native build of the engine `.so` (+ 16 KB alignment flags)

All engine `.so`s inherit the **P0.1 16 KB gate**: Play blocks non-aligned `.so`s targeting API 35+, and **NDK r27x does not 16 KB-align by default** — flags are mandatory and manual on every `.so` (developer.android.com/guide/practices/page-sizes; [ANDROID_PHASE0.md §P0.1 step 4](ANDROID_PHASE0.md)). Flags: `-Wl,-z,max-page-size=16384 -Wl,-z,common-page-size=16384`.

**Branch (a) — whisper.cpp from source, static-linked into one bridge `.so`.** Vendor whisper.cpp as a pinned submodule; build `libwhisper`/`libggml` **static** and link them into our single `libsttbridge.so`, so there is exactly one native artifact to align and load. CMake, wired via AGP `externalNativeBuild`:

```cmake
cmake_minimum_required(VERSION 3.22)
project(sttbridge C CXX)

set(WHISPER_BUILD_TESTS    OFF CACHE BOOL "" FORCE)
set(WHISPER_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(BUILD_SHARED_LIBS      OFF CACHE BOOL "" FORCE)   # static libwhisper + libggml
# q8_0 decode leans on arm64 int8 dot-product / i8mm — enable so RTF isn't left on the table:
set(GGML_NATIVE   OFF CACHE BOOL "" FORCE)            # cross-compile: don't probe host CPU
set(GGML_CPU_ARM_ARCH "armv8.2-a+dotprod+i8mm" CACHE STRING "" FORCE)
add_subdirectory(whisper.cpp)

add_library(sttbridge SHARED whisper_jni.c)
target_link_libraries(sttbridge whisper)             # pulls in static ggml

# 16 KB alignment — mandatory on r27 (P0.1). Applies to THIS .so.
target_link_options(sttbridge PRIVATE
    "-Wl,-z,max-page-size=16384" "-Wl,-z,common-page-size=16384")
```

`app/build.gradle.kts`: `ndkVersion = "27.x"`, `defaultConfig { minSdk = 28; targetSdk = 36; ndk { abiFilters += "arm64-v8a" } }`, and `externalNativeBuild { cmake { path = file("src/main/cpp/CMakeLists.txt") } }`. `libc++_shared.so` still ships (deduped via `jniLibs.pickFirsts`, P0.1 §3.7) and must itself be verified 16 KB-aligned.

**Branch (b)/(c) — prebuilt sherpa-onnx AAR, alignment must be verified not assumed.** Consume `sherpa-onnx` via Maven/release AAR ([releases](https://github.com/k2-fsa/sherpa-onnx/releases)); it bundles `libsherpa-onnx-jni.so` + `libonnxruntime.so`. **The AAR's `.so`s were built with whatever NDK the sherpa release used — if that is r27 or earlier they are 4 KB-aligned and fail Play upload.** Mitigation order: (i) verify with `check_elf_alignment.sh` (P0.1 gate tool); (ii) if misaligned, **build sherpa-onnx from source** for `arm64-v8a` with `-DSHERPA_ONNX_ENABLE_JNI=ON` and the two linker flags injected via `CMAKE_SHARED_LINKER_FLAGS`; (iii) escalate to the sherpa maintainers / a newer release. For **(c)** additionally: the **Qualcomm QNN runtime `.so`s** (`libQnnHtp.so`, `libQnnHtpV**Stub.so`, `libQnnSystem.so`, from the QNN / AI-Engine-Direct SDK) are **Qualcomm-prebuilt binary blobs we cannot relink** — if any is 4 KB-aligned, (c) is blocked pending a QNN-SDK version that ships 16 KB blobs. This is a distinct, un-mitigable-by-us risk that must be checked *before* betting on (c) (its QNN model assets are distributed separately — sherpa's `asr-models-qnn-binary` — [k2-fsa GitHub release](https://github.com/k2-fsa/sherpa-onnx/releases/tag/asr-models-qnn-binary)).

### The JNI bridge — branch (a), real code

Our `libsttbridge.so`. Adapted from the official `whisper.android` example ([examples/whisper.android/.../jni.c](https://github.com/ggml-org/whisper.cpp/tree/master/examples/whisper.android/lib/src/main/jni/whisper)) which uses `whisper_init_from_file_with_params` + `whisper_full_default_params(WHISPER_SAMPLING_GREEDY)` + `whisper_full` — but that example returns text via `NewStringUTF` and reads audio via `GetFloatArrayElements`; **both are replaced below** to meet the audited standard.

`app/src/main/cpp/whisper_jni.c`:

```c
#include <jni.h>
#include <pthread.h>
#include <stdatomic.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include "whisper.h"

// Rule 2: the whisper_context is single-owner and NOT thread-safe. One global
// mutex serializes init/decode/free — the JNI mirror of the iOS `actor`.
static pthread_mutex_t g_ctx_mutex = PTHREAD_MUTEX_INITIALIZER;

// Rule 7: the cooperative abort seam. g_abort is polled by whisper's abort_callback
// between compute steps; g_decoding is the state P3-A's onTrimMemory unload-guard /
// thermal-defer consult so they never unload mid-decode. Set from ANOTHER thread
// (the UI/governor), so both are atomics and nativeCancel does NOT take g_ctx_mutex
// (it must run WHILE the decode holds the mutex).
static atomic_bool g_abort    = false;
static atomic_bool g_decoding = false;

// whisper_full_params.abort_callback: returns true → the running decode aborts.
static bool stt_abort_cb(void *user_data) { return atomic_load(&g_abort); }

// Rule 4: surface failures as a typed Kotlin exception, never a "" transcript.
static void throw_stt(JNIEnv *env, const char *msg) {
    jclass cls = (*env)->FindClass(env, "dev/appfour/stt/SttNativeException");
    if (cls) (*env)->ThrowNew(env, cls, msg);
}

// init — returns an opaque handle; throws (returns 0 only after a pending throw).
JNIEXPORT jlong JNICALL
Java_dev_appfour_stt_WhisperNative_nativeInit(JNIEnv *env, jclass c, jstring model_path) {
    const char *path = (*env)->GetStringUTFChars(env, model_path, NULL);
    if (!path) { throw_stt(env, "model path null"); return 0; }

    struct whisper_context_params cp = whisper_context_default_params();
    cp.use_gpu = false;   // CPU q8_0 path; Adreno GPU offload is unproven on mid-tier (P0.2.3)

    pthread_mutex_lock(&g_ctx_mutex);
    struct whisper_context *ctx =
        whisper_init_from_file_with_params(path, cp);   // non-_with_params is WHISPER_DEPRECATED
    pthread_mutex_unlock(&g_ctx_mutex);

    (*env)->ReleaseStringUTFChars(env, model_path, path);
    if (!ctx) { throw_stt(env, "whisper_init_from_file_with_params failed"); return 0; }
    return (jlong)(intptr_t)ctx;
}

// decode — PCM via DIRECT ByteBuffer (rule 3, zero-copy); transcript out as a
// UTF-8 jbyteArray (rule 1, never NewStringUTF).
JNIEXPORT jbyteArray JNICALL
Java_dev_appfour_stt_WhisperNative_nativeTranscribe(
        JNIEnv *env, jclass c, jlong handle,
        jobject pcm_buffer, jint sample_count,
        jstring initial_prompt, jstring language, jboolean carry_prompt) {

    struct whisper_context *ctx = (struct whisper_context *)(intptr_t)handle;
    if (!ctx) { throw_stt(env, "null context handle"); return NULL; }

    // Rule 3: read floats straight out of the direct buffer's native memory.
    const float *pcm = (const float *)(*env)->GetDirectBufferAddress(env, pcm_buffer);
    if (!pcm) { throw_stt(env, "PCM must be a DIRECT ByteBuffer"); return NULL; }

    const char *prompt = initial_prompt ? (*env)->GetStringUTFChars(env, initial_prompt, NULL) : NULL;
    const char *lang   = language       ? (*env)->GetStringUTFChars(env, language, NULL)       : NULL;

    struct whisper_full_params p = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
    p.language             = lang;                 // "en", or NULL for auto language-ID
    p.initial_prompt       = prompt;               // vocab bias (candidate a) — see Vocabulary
    p.carry_initial_prompt = (carry_prompt == JNI_TRUE);  // re-apply across decode windows (long audio)
    p.print_progress = p.print_realtime = false;
    p.no_timestamps  = true;
    // Rule 5: n_threads left at whisper.cpp's default (min(4, hw concurrency)) — do NOT hard-pin.
    // Rule 7: register the abort seam P2-E (user cancel) + P3-A (thermal governor) drive.
    p.abort_callback           = stt_abort_cb;
    p.abort_callback_user_data = NULL;

    atomic_store(&g_abort, false);                 // clear any stale cancel from a prior run
    pthread_mutex_lock(&g_ctx_mutex);              // rule 2: serialize the whole decode + read-back
    atomic_store(&g_decoding, true);
    int rc = whisper_full(ctx, p, pcm, (int)sample_count);
    atomic_store(&g_decoding, false);
    bool aborted = atomic_load(&g_abort);          // rc != 0 + abort flag ⇒ cancelled, not an error

    jbyteArray out = NULL;
    if (rc == 0) {
        int n = whisper_full_n_segments(ctx);
        size_t cap = 1;
        for (int i = 0; i < n; i++) cap += strlen(whisper_full_get_segment_text(ctx, i));
        char *buf = (char *)malloc(cap); buf[0] = '\0';
        for (int i = 0; i < n; i++) strcat(buf, whisper_full_get_segment_text(ctx, i));
        pthread_mutex_unlock(&g_ctx_mutex);

        jsize len = (jsize)strlen(buf);            // whisper emits UTF-8 already
        out = (*env)->NewByteArray(env, len);      // rule 1: raw UTF-8 bytes, decoded Kotlin-side
        (*env)->SetByteArrayRegion(env, out, 0, len, (const jbyte *)buf);
        free(buf);
    } else {
        pthread_mutex_unlock(&g_ctx_mutex);
    }

    if (prompt) (*env)->ReleaseStringUTFChars(env, initial_prompt, prompt);
    if (lang)   (*env)->ReleaseStringUTFChars(env, language, lang);

    if (rc != 0) {                                 // rule 4: never "" — but distinguish cancel from failure
        throw_stt(env, aborted ? "cancelled" : "whisper_full failed");
        return NULL;
    }
    return out;
}

// Rule 7: cancel — flip the abort flag the decode's abort_callback polls. Must NOT
// take g_ctx_mutex (the decode holds it); the atomic is the whole point.
JNIEXPORT void JNICALL
Java_dev_appfour_stt_WhisperNative_nativeCancel(JNIEnv *env, jclass c) {
    atomic_store(&g_abort, true);
}

// Rule 7: isDecoding — P3-A's thermal-defer + onTrimMemory unload-guard query this
// so they never unload/free while a decode is live.
JNIEXPORT jboolean JNICALL
Java_dev_appfour_stt_WhisperNative_nativeIsDecoding(JNIEnv *env, jclass c) {
    return atomic_load(&g_decoding) ? JNI_TRUE : JNI_FALSE;
}

// unload — mirrors iOS unloadModel(): free the native context, drop the handle.
JNIEXPORT void JNICALL
Java_dev_appfour_stt_WhisperNative_nativeFree(JNIEnv *env, jclass c, jlong handle) {
    struct whisper_context *ctx = (struct whisper_context *)(intptr_t)handle;
    if (!ctx) return;
    pthread_mutex_lock(&g_ctx_mutex);
    whisper_free(ctx);
    pthread_mutex_unlock(&g_ctx_mutex);
}
```

Kotlin side of branch (a) — the `external` declarations and the typed exception:

```kotlin
package dev.appfour.stt

class SttNativeException(message: String) : Exception(message)

internal object WhisperNative {
    init { System.loadLibrary("sttbridge") }   // whisper + ggml are static inside this .so
    external fun nativeInit(modelPath: String): Long
    external fun nativeTranscribe(
        handle: Long, pcm: java.nio.ByteBuffer, sampleCount: Int,
        initialPrompt: String?, language: String?, carryPrompt: Boolean,
    ): ByteArray               // UTF-8 bytes — decoded with Charsets.UTF_8, never a jstring
    external fun nativeFree(handle: Long)
    external fun nativeCancel()          // rule 7: flip the abort flag (thread-safe, no handle)
    external fun nativeIsDecoding(): Boolean   // rule 7: decode-state query for P3-A
}
```

The service (branch a) — mirrors the iOS contract (lazy idempotent load, progress emits, **unload before the stream finishes**, thrown errors surface as a final error segment) with **one deliberate input deviation**: iOS `transcribe(audioURL:)` opens the audio file itself; the Android bridge takes **already-decoded 16 kHz mono `FloatArray` PCM** (the Phase-1 `AudioRecord` output). For **retry/deferred-drain of a persisted `.m4a`** (P2-E drain, P3-A retry/thermal-defer), the **Phase-1 audio pipeline decodes the file to PCM (`MediaExtractor`/`MediaCodec`) and feeds `transcribe(pcm)` — the bridge never opens a path**. Kotlin `Flow<TranscriptionSegment>` is the analogue of iOS `AsyncStream<TranscriptionSegmentDTO>`; `Mutex` is the analogue of the iOS `actor`:

```kotlin
class WhisperTranscriptionService(
    private val modelPath: String,                     // resolved from base module / asset pack
    private val medicalPromptEnabled: () -> Boolean,   // Settings → Accessibility, as on iOS
) : TranscriptionService {

    private val mutex = Mutex()                        // ≈ the iOS actor's isolation
    private var handle: Long = 0L

    // ≈ loadModel(): idempotent, guarded (WhisperKitTranscriptionService.swift:49)
    override suspend fun loadModel() = mutex.withLock {
        if (handle != 0L) return
        handle = withContext(Dispatchers.Default) { WhisperNative.nativeInit(modelPath) }
        // nativeInit throws SttNativeException on failure — no 0/"" sentinel leaks out
    }

    // ≈ transcribe(audioURL:) (WhisperKitTranscriptionService.swift:83)
    override fun transcribe(pcm16kMono: FloatArray): Flow<TranscriptionSegment> = flow {
        emit(TranscriptionSegment("Setting up on-device transcription…", isFinal = false))
        val text = mutex.withLock {
            if (handle == 0L) handle = WhisperNative.nativeInit(modelPath)
            emit(TranscriptionSegment("Transcribing…", isFinal = false))

            // Rule 3: native-order DIRECT buffer over the PCM floats (zero array copy).
            val bb = java.nio.ByteBuffer
                .allocateDirect(pcm16kMono.size * 4)
                .order(java.nio.ByteOrder.nativeOrder())
            bb.asFloatBuffer().put(pcm16kMono)

            val prompt = if (medicalPromptEnabled()) SharedCore.adhdPrompt else null
            val utf8 = WhisperNative.nativeTranscribe(
                handle, bb, pcm16kMono.size, prompt, "en",
                /* carryPrompt = */ pcm16kMono.size > 16_000 * 30,   // >30 s clips
            )
            SharedCore.cleanTranscript(String(utf8, Charsets.UTF_8))  // rule 1: decode UTF-8 here
        }
        if (text.isEmpty()) throw SttNativeException("No transcription result")
        emit(TranscriptionSegment(text, isFinal = true))
        unloadModel()                                  // free BEFORE finish (iOS:172-177)
    }
        .catch { e ->
            unloadModel()                              // release on the error path too (iOS:198)
            emit(TranscriptionSegment("Transcription error: ${e.message}", isFinal = true, isError = true))
        }
        .flowOn(Dispatchers.Default)

    override suspend fun unloadModel() = mutex.withLock {
        if (handle != 0L) { WhisperNative.nativeFree(handle); handle = 0L }
    }

    // Rule 7 — REAL, not a stub. Does NOT take the mutex: the decode holds it, and this must
    // run concurrently to flip the abort flag whisper's abort_callback polls (per-step abort).
    // Consumed by P2-E (user cancel) and P3-A (thermal governor's shouldAbort).
    override suspend fun cancel() = WhisperNative.nativeCancel()

    // Rule 7 — decode-state query for P3-A's onTrimMemory unload-guard / thermal defer.
    val isDecoding: Boolean get() = WhisperNative.nativeIsDecoding()
}
```

**Branch (b)/(c) — the AAR adapter (no custom JNI).** Same `TranscriptionService` surface, wrapping sherpa's `OfflineRecognizer`. The audited rules are honored at the *service* layer (mutex-guarded recognizer, typed exception on empty/failed decode, unload-before-finish); the PCM already crosses via sherpa's own `acceptWaveform(samples: FloatArray, sampleRate: Int)` ([OfflineStream.kt](https://github.com/k2-fsa/sherpa-onnx/blob/master/sherpa-onnx/kotlin-api/OfflineStream.kt)):

```kotlin
class SherpaTranscriptionService(
    private val modelDir: java.io.File,   // P2-B provisionModel() output: filesDir/models/parakeet (Strategy 1)
    private val useQnn: Boolean,          // candidate (c) = true
    private val hotwordsPath: String,     // med-lexicon → hotwords (candidate b vocab lever)
    private val numThreads: Int,          // the P0.2-swept value — NOT sherpa's default of 1 (see Risks)
) : TranscriptionService {

    private val mutex = Mutex()
    private var recognizer: OfflineRecognizer? = null
    @Volatile private var decoding = false   // rule 7 on b/c: isDecoding lives HERE, in adapter state

    override suspend fun loadModel() = mutex.withLock {
        if (recognizer != null) return
        val model = OfflineModelConfig(
            // (b) Parakeet TDT v3 transducer — absolute paths into the P2-B extracted dir
            // (per P2-B Strategy 1: sherpa loads from the extracted filesDir path, NOT context.assets):
            transducer = OfflineTransducerModelConfig(
                encoder = java.io.File(modelDir, "encoder.int8.onnx").absolutePath,
                decoder = java.io.File(modelDir, "decoder.int8.onnx").absolutePath,
                joiner  = java.io.File(modelDir, "joiner.int8.onnx").absolutePath,
            ),
            // (c) instead: whisper = OfflineWhisperModelConfig(encoder=…, decoder=…, language="", task="transcribe")
            modelType = if (useQnn) "whisper" else "transducer",
            provider  = if (useQnn) "qnn" else "cpu",   // "qnn" needs Hexagon NPU + QNN runtime .so's
            numThreads = numThreads,                    // deviation from "library default" — justified in Risks
        )
        val cfg = OfflineRecognizerConfig(
            modelConfig    = model,
            hotwordsFile   = hotwordsPath,              // transducer bias (candidate b)
            hotwordsScore  = 1.5f,
            decodingMethod = "modified_beam_search",    // REQUIRED for hotwords (greedy ignores them)
        )
        recognizer = OfflineRecognizer(config = cfg)   // path-based load — never OfflineRecognizer(assets, …)
    }

    override fun transcribe(pcm16kMono: FloatArray): Flow<TranscriptionSegment> = flow {
        val r = recognizer ?: run { loadModel(); recognizer!! }
        val text = mutex.withLock {
            r.createStream().use { s ->                 // .use → release() in finally (frees native stream)
                s.acceptWaveform(pcm16kMono, sampleRate = 16000)
                decoding = true
                try { r.decode(s) } finally { decoding = false }
                r.getResult(s).text                     // sherpa returns a Kotlin String — see Risks (rule 1 deviation)
            }
        }
        if (text.isEmpty()) throw SttNativeException("empty transcript")
        emit(TranscriptionSegment(SharedCore.cleanTranscript(text), isFinal = true))
        unloadModel()
    }.flowOn(Dispatchers.Default)

    override suspend fun unloadModel() = mutex.withLock { recognizer?.release(); recognizer = null }

    // Rule 7 on b/c — HONEST semantics: the single-shot decode above CANNOT be aborted
    // mid-utterance. cancel() is a no-op for the in-flight utterance; it takes effect
    // between queue items only (the caller drops the result + unloads). P3-A thermal
    // defer on this branch = let the in-flight utterance finish (or unload), defer the queue.
    override suspend fun cancel() = Unit

    // Rule 7 on b/c — isDecoding is this Kotlin adapter flag (no native query exists);
    // P3-A's onTrimMemory unload-guard consults it, same as branch (a)'s nativeIsDecoding().
    val isDecoding: Boolean get() = decoding
}
```

### Vocabulary injection per engine

The iOS app biases Whisper with a natural-register ADHD/medication prompt ([WhisperKitTranscriptionService.swift:22-24](../app-four/Services/WhisperKit/WhisperKitTranscriptionService.swift#L22)) — leading with a plausible check-in sentence, then the med catalog + symptom lexicon — and only when the Settings toggle is on ([:134](../app-four/Services/WhisperKit/WhisperKitTranscriptionService.swift#L134)). **This exact string should live in the shared Swift core** (`SharedCore.adhdPrompt`) and be reused, not reimplemented — it is language/product content, not platform code.

| Engine | Mechanism | Notes |
|---|---|---|
| **(a) whisper.cpp** | `whisper_full_params.initial_prompt` (soft bias) | Whisper treats it as text spoken just before the clip. **Cap: `n_text_ctx/2 ≈ 224` tokens** for small — a *derived* figure (`n_text_ctx=448` for small; the exact truncation point is unconfirmed against source). Set `carry_initial_prompt = true` for >30 s clips so the bias re-applies across decode windows (`carry_initial_prompt`/`initial_prompt` fields — [whisper.h](https://github.com/ggml-org/whisper.cpp/blob/master/include/whisper.h)). Soft only — **no guarantee** a med-name is recognized. |
| **(c) Whisper-on-QNN** | same `initial_prompt` (Whisper decoder) | **Verify the QNN path exposes it** — `OfflineWhisperModelConfig` may not surface `initial_prompt`, and a QNN-frozen decoder graph can drop it. If unavailable, (c) loses its only vocab lever → a red flag on the (c) branch (record at integration, not launch). |
| **(b) Parakeet transducer** | `hotwordsFile` + `hotwordsScore` + `modified_beam_search` | Transducers have **no soft prompt** — the med lexicon is injected as a hotwords file (one phrase per line), scored up at decode. Build the file from the **89-entry curated EU ADHD stimulant catalog** (the same lexicon the extractor keys on — [memory: medication-catalog-source]). This is the *only* in-model bias for (b); P0.2.6 already warns "validate med-recall extra hard" for the Parakeet branch. |

### init / decode / unload lifecycle — mirroring iOS

| iOS (`WhisperKitTranscriptionService`) | Android bridge | Contract preserved |
|---|---|---|
| `actor` isolation | `Mutex` (a) / mutex-guarded recognizer (b/c) | serialized access to a non-thread-safe context |
| `loadModel()` — guard on `modelLoadingTask` + `whisperKit == nil` ([:49](../app-four/Services/WhisperKit/WhisperKitTranscriptionService.swift#L49)) | `loadModel()` — `if (handle != 0L) return` under lock | idempotent, no double-init |
| `transcribe()` lazy-loads if `nil`, yields "Setting up…"/"Transcribing…" progress ([:101-128](../app-four/Services/WhisperKit/WhisperKitTranscriptionService.swift#L101)) | `flow { emit(progress…) }`, lazy `nativeInit` | same UX: first-run setup message, then live status |
| **`unloadModel()` called BEFORE `continuation.finish()`** for RAM ([:172-177](../app-four/Services/WhisperKit/WhisperKitTranscriptionService.swift#L172)) | `unloadModel()` before the final flow completion; also in `.catch` | native model memory freed the instant transcription ends, not lingering into extraction |
| `unloadModel()` sets `whisperKit = nil` ([:216](../app-four/Services/WhisperKit/WhisperKitTranscriptionService.swift#L216)) | `nativeFree(handle); handle = 0L` (a) / `recognizer.release()` (b/c) | explicit native free, not GC-deferred |
| `cancelTranscription()` cancels the active task ([:221](../app-four/Services/WhisperKit/WhisperKitTranscriptionService.swift#L221)) | coroutine cancel + `whisper` `abort_callback` (a) / drop+unload (b/c) | user can abort; offline decode (b/c) is not mid-flight cancellable |
| error path yields an `isError` segment then finishes ([:186-201](../app-four/Services/WhisperKit/WhisperKitTranscriptionService.swift#L186)) | `.catch { unload; emit(isError) }` | failures surface as a UI-visible error segment, model still freed |

The `TranscriptionSegment` DTO mirrors the iOS `TranscriptionSegmentDTO` (`text`, `isFinal`, `isError`, optional timings/confidence — [Protocols.swift:48](../app-four/Services/Protocols.swift#L48)); `TranscriptionService` mirrors the iOS protocol (`transcribe` / `cancelTranscription` / `loadModel` — Android shortens the cancel to `cancel()` — with `unloadModel` promoted to the interface since Android must free native memory explicitly).

### Exit criteria (binary)

The workstream is **done** only if all hold for the P0.2-winning branch on a real API 28+ device:

1. **End-to-end parity:** a 16 kHz mono PCM check-in fed through the bridge/adapter produces text **signal-equivalent to the standalone P0.2 harness** output for the same clip — byte-identical with `n_threads` pinned for the parity run only, or within a stated edit-distance at the library-default thread count (multithreaded ggml float reduction is not bit-reproducible). Proves the integration didn't perturb the engine.
2. **jbyteArray, no `NewStringUTF` (branch a):** `grep -R NewStringUTF app/src/main/cpp` returns nothing in our bridge, **and** a unit test of the `jbyteArray` decode path feeds a synthetic UTF-8 byte array containing a supplementary-plane codepoint through the Kotlin-side decode without corruption or VM abort (a live STT engine won't *emit* such a char — test the marshalling path directly). (Branch b/c: the AAR's internal `NewStringUTF` deviation is *recorded* as an accepted risk, not fixed.)
3. **Thrown errors, never `""`:** pointing the service at a missing model file surfaces `SttNativeException` to Kotlin; no code path emits an empty-string transcript as success.
4. **Mutex serialization:** two concurrent `transcribe()` calls serialize with no crash/data race (stress test); single-context invariant holds.
5. **Direct ByteBuffer:** PCM crosses via `GetDirectBufferAddress` (non-null) with zero array copy; `GetFloatArrayElements` absent from the bridge (branch a).
6. **Unload frees memory:** process RSS returns to within an owner-set tolerance (MB, fixed at kickoff) of the pre-load baseline after `transcribe()` completes, confirming `unloadModel()` ran *before* stream completion (mirrors iOS RAM behavior).
7. **16 KB alignment:** every `.so` in the APK (`libsttbridge.so` + `libc++_shared.so`, or the sherpa/ONNX/QNN `.so`s) reports `ALIGNED (16384)` via `check_elf_alignment.sh` (reuses the P0.1 gate).
8. **Vocab injection active:** med-name recall on the med-dense golden clips is **strictly greater** with prompt/hotwords ON vs OFF, **or** the passed prompt/hotwords params are logged as reaching the engine (equal recall alone proves nothing — the lever must be shown wired, not silently ignored; the (c) `initial_prompt` check lives here).
9. **Cancel reaches native (branch a):** `cancel()` mid-decode makes `whisper_full` return within a bounded interval via `abort_callback`, surfaced as "cancelled" not an error; `isDecoding` reflects live decode state. (Branch b/c: cancel is *recorded* as abandon-between-queue-items, not mid-utterance abort — see Rule 7 and Risks.)

### Risks & effort

| Risk | Branch | Impact | Mitigation |
|---|---|---|---|
| **QNN blob 16 KB alignment** — Qualcomm `libQnn*.so` are prebuilt; we can't relink them | (c) | Launch blocker if 4 KB | Verify with `check_elf_alignment.sh` **before** committing to (c); escalate to a QNN-SDK version shipping 16 KB blobs — no in-house fix |
| **Stock sherpa AAR has no QNN** — (c) forfeits (b)'s no-source-build advantage | (c) | Extra build + SDK acquisition work | Needs a from-source `SHERPA_ONNX_ENABLE_QNN=ON` build + Qualcomm QNN blobs; fold into the (c) effort estimate |
| **`initial_prompt` not exposed on the QNN Whisper path** | (c) | Loses the only vocab lever | Confirm at integration (exit criterion 8); if absent, record as a (c)-branch quality flag |
| **sherpa AAR returns a Java `String` (internal `NewStringUTF`)** — rule 1 deviation we don't own | (b)/(c) | VM-abort risk on supplementary chars | Near-zero exposure (speech transcripts carry no emoji/supplementary planes); **record as accepted deviation**; if ever hit, build sherpa from source and patch the JNI to jbyteArray |
| **sherpa `numThreads` default = 1** contradicts the audited "library default" rule | (b)/(c) | Default tanks RTF; P0.2 gate assumes swept threads | **Deviate deliberately:** pass the P0.2-winning thread count (sweep was 4/6, [P0.2.4](ANDROID_PHASE0.md)); the audited rule was written for whisper.cpp (default = min(4,nproc), sane), so honoring it literally on sherpa would fail the gate. Flag in the report. |
| **q8_0 RTF without arm dotprod/i8mm** | (a) | Misses achievable RTF | Set `GGML_CPU_ARM_ARCH=armv8.2-a+dotprod+i8mm` at build (above) |
| **whisper.cpp/ggml static-link symbol collisions or missing `libomp`** | (a) | Link/load failure | Static `BUILD_SHARED_LIBS=OFF`; enumerate the APK's `lib/arm64-v8a/` and load-test on device, not just build success (P0.1 §6) |
| **Model path resolution across delivery mechanisms** | all | Wrong path → init throws | Base module for whisper 264 MB; **install-time asset pack** for Parakeet ≈640 MB / QNN blobs — resolve the extracted on-disk path at runtime (Phase 1 delivery task) |

**Effort (assumes G0 passed and the winner is known):**
- **Branch (a) whisper.cpp — 3–4 d.** ~1 d native build + 16 KB flags; 1–1.5 d the audited JNI (jbyteArray/mutex/ByteBuffer/thrown errors) + Kotlin service; 0.5–1 d prompt wiring + exit-criteria verification. The JNI is the fiddly part (`UnsatisfiedLinkError`, buffer lifetimes).
- **Branch (b) sherpa Parakeet — ~2 d.** No JNI to write; AAR adapter + hotwords file from the lexicon + service contract + alignment verify. Fastest branch **if** the release AAR is already 16 KB-aligned; **+1–2 d** if we must build sherpa from source for alignment.
- **Branch (c) Whisper-on-QNN — (b) + 3–4 d.** QNN SDK acquisition, QNN blob alignment audit, `provider="qnn"` wiring, `initial_prompt` verification, device-gen compatibility. The highest-variance branch; some risks are un-mitigable by us.

### Cross-phase dependencies & assumptions

- **Blocked by P0.1** (toolchain + the 16 KB build/verify gate this workstream reuses wholesale) and **P0.2** (which engine — this section has no single implementation until the fork resolves; a P0.2 *no-go* deletes it entirely).
- **Blocked by Phase 1 step 4 (audio):** consumes **16 kHz mono float PCM in `[-1,1]` as a `FloatArray`** — Phase 1 P1-D commits this directly (float sink tapped pre-encode, no AAC round-trip; [ANDROID_PHASE1.md](ANDROID_PHASE1.md)); any Int16→Float32 conversion is owned in P1-D, not this bridge. For retry/deferred paths the same P1-D pipeline decodes the persisted `.m4a` back to PCM (`MediaExtractor`/`MediaCodec`) before calling `transcribe(pcm)`.
- **Blocked by Phase 1 model delivery (P2-B):** the `modelPath`/asset path is produced by the install-time Play asset-pack plumbing (mandatory for Parakeet ≈640 MB, optional for whisper 264 MB) — this workstream assumes a resolved on-disk path, not the packaging itself.
- **Feeds Phase 2 step 6 (extractor, P2-C):** emits the transcript the shared Swift extractor consumes; the **STT→extractor style-divergence** flagged in [P0.2.7](ANDROID_PHASE0.md) (transducer casing/punctuation vs Whisper) becomes a real normalization task there if (b) won — the extractor was tuned on WhisperKit output.
- **Assumes shared-core reuse:** `SharedCore.adhdPrompt` (the exact iOS prompt string, [WhisperKitTranscriptionService.swift:22](../app-four/Services/WhisperKit/WhisperKitTranscriptionService.swift#L22)), `SharedCore.cleanTranscript` (the non-speech-marker scrub, [:39-46](../app-four/Services/WhisperKit/WhisperKitTranscriptionService.swift#L39)), and the 89-entry med lexicon are exposed from the shared Swift package (Phase 1 step 1) and **not** reimplemented in Kotlin — reimplementation would drift the med-recall behavior the extractor depends on.
- **Assumes the audited jbyteArray/mutex/ByteBuffer/thrown-error standard is fully enforceable only on branch (a)** (we own the C). On (b)/(c) it is a *service-layer* contract plus two recorded deviations (internal `NewStringUTF`; `numThreads` override) — this is a real, owner-acknowledgeable gap between the plan's audited standard and the AAR reality, not a defect in this workstream (surfaced in Consolidated).
- **`TranscriptionService`/`TranscriptionSegment` are the Android mirrors** of [Protocols.swift:69](../app-four/Services/Protocols.swift#L69); keeping the surface identical is what lets the UI (Phase 2 step 7) and extractor wiring be platform-shared.

---

## P2-B — Model packaging & delivery

Ships the P0.2-winning STT model to the device via an **install-time Play asset pack**, extracts/loads it into the native engine, and exposes an explicit unload API mirroring iOS. Carries the P0.2 winner fork — only the pack *contents and size* differ between whisper and Parakeet; the delivery mechanism is identical. The native-engine seam it feeds is **the P2-A bridge contract** (this workstream supplies the *path/fd* and drives its unload; P2-A owns the handle lifecycle and transcript marshaling). Every external claim carries a cited URL; repo claims carry `file:line`.

### Goal

Get the STT model bytes onto the device **at install time, with no first-run network dependency**, make them accessible to the native whisper.cpp / sherpa-onnx engine as a real file path (or mmap-able fd), and manage the load→resident→unload lifecycle within a mid-tier RAM budget. The model is load-bearing (P0.2 is the kill gate) and there is no server fallback — so delivery reliability is a correctness property, not a nicety. Install-time delivery is chosen deliberately over on-demand: the model is present the instant the app opens, first-run works in airplane mode, and there is no download-progress UX to build or fail.

### The P0.2 size fork (264 vs 640 MB → base vs pack)

| P0.2 winner | On-disk size | Fits 500 MB base module? | Delivery |
|---|---|---|---|
| whisper-small **q8_0** (candidate a) | **264 MB** ([official quant](https://huggingface.co/ggerganov/whisper.cpp/tree/main)) | Yes (fits, ~236 MB headroom) | Install-time asset pack anyway — keeps base lean, separates model lifecycle |
| Parakeet TDT v3 **int8** (candidate b) | **≈640 MB** (sherpa-onnx int8 dir) | **No — exceeds the 500 MB base cap** | Install-time asset pack **MANDATORY** |

- Play per-module base cap = **500 MB compressed download** ([Play size limits](https://support.google.com/googleplay/android-developer/answer/9859372)). Parakeet's ≈640 MB cannot live in the base module or a dynamic feature module (also 500 MB) — an asset pack (per-pack cap **1.5 GB**) is the only in-bundle home for it.
- **Design ruling: use an install-time asset pack for either winner.** A single code path regardless of P0.2 outcome. If whisper survives, the pack is 264 MB and the store-listing/install footprint is materially kinder; if Parakeet survives, the pack is mandatory at ≈640 MB. Nothing downstream branches on the winner except the pack directory contents and the recorded size numbers.
- Asset packs hold **data, not code** — they are ABI-agnostic, so the model needs no per-ABI split even though the app itself is `arm64-v8a`-only (P0.1). The native engine `.so`s (whisper.cpp / sherpa-onnx) travel in the base module's `jniLibs`, not the pack.

### Install-time asset pack setup (Gradle module + delivery type)

The Skip Fuse app's Gradle project is generated by `skip init` (plan Phase 1 §2). Add one asset-pack module to it — three edits:

**1. `settings.gradle(.kts)` — include the pack module:**
```kotlin
include(":app")
include(":stt_model")            // asset pack module
```

**2. Base app `app/build.gradle(.kts)` — declare the pack:**
```kotlin
android {
    // ...
    assetPacks += listOf(":stt_model")   // link the install-time pack to the base
}
```

**3. `stt_model/build.gradle(.kts)` — the asset pack module itself:**
```kotlin
plugins {
    id("com.android.asset-pack")
}

assetPack {
    packName = "stt_model"                 // becomes the pack/dir name at runtime
    dynamicDelivery {
        deliveryType = "install-time"      // delivered atomically with the base APK
    }
}
```
(Canonical AGP DSL is `packName` + `dynamicDelivery { deliveryType }`; some older/Play-Core docs show a simplified `name`/`type` form — use the AGP form above. Confirmed against the asset-delivery build guide, [developer.android.com/guide/playcore/asset-delivery](https://developer.android.com/guide/playcore/asset-delivery).)

**4. Drop the model into the pack's assets dir** — for whisper: `stt_model/src/main/assets/models/ggml-small-q8_0.bin`; for Parakeet the sherpa-onnx int8 model directory (encoder/decoder/joiner + tokens) under `stt_model/src/main/assets/models/parakeet/`.

**What install-time delivery gives us** ([PAD delivery-types doc](https://developer.android.com/guide/playcore/asset-delivery)):
- Delivered **atomically with the base APK as split APKs** — available at first launch, no `AssetPackManager.fetch()` call, no download state machine.
- **Merged into the app's assets** — reachable via the standard `context.assets` / NDK `AAssetManager`, exactly like a bundled asset.
- Updated automatically as part of a base-app update; the user cannot delete them.
- **Counts toward the app's Play-Store-listed size** (unlike on-demand/fast-follow, which don't) — the deliberate tradeoff we accept for zero-network first-run.

### Runtime model access (path / mmap)

Install-time pack assets are **merged into the app's asset namespace**, so at runtime they are opened via `AssetManager` (Kotlin) / `AAssetManager` (native) — *not* via `AssetPackManager.getPackLocation()` (that API is only for fast-follow/on-demand packs) ([integrate-java](https://developer.android.com/guide/playcore/asset-delivery/integrate-java)). But both engines load from a **filesystem path**, so an asset inside an APK (a zip entry, not a real path) needs handling. ⚠ **RAM caveat (do not conflate on-disk with runtime):** whisper.cpp/GGML mmaps its weights, so its resident footprint tracks the 264 MB file. **sherpa-onnx/ONNX Runtime does not memory-map weights the way whisper.cpp/GGML does** — a reporter measured Parakeet-0.6B int8 at **≈1.23 GB runtime RSS vs its ≈640 MB on-disk size, roughly 2×** ([sherpa-onnx #2626](https://github.com/k2-fsa/sherpa-onnx/issues/2626) — measured on iOS/Xcode; treat the ~2× as an ONNX-Runtime property to re-verify on Android; the materialize-into-working-memory mechanism is our explanation, not the issue's). This is the binding constraint on mid-tier devices (often 4–6 GB total, with aggressive `onTrimMemory` kills) — budget against ~1.2 GB for Parakeet, not 640 MB, and treat it as a P0.2 device-viability input. Two model-access strategies:

**Strategy 1 — extract-to-filesDir (default, recommended).** On first launch copy the model out of assets into internal storage, then load the engine from the real path. This is what the official whisper.cpp Android examples do (models copied to `assets/models`, then read out). Kotlin:
```kotlin
private fun provisionModel(context: Context): File {
    val dest = File(context.filesDir, "models/ggml-small-q8_0.bin")
    if (dest.exists() && dest.length() == EXPECTED_BYTES) return dest   // idempotent
    dest.parentFile?.mkdirs()
    val tmp = File(dest.parentFile, dest.name + ".tmp")
    context.assets.open("models/ggml-small-q8_0.bin").use { input ->
        tmp.outputStream().use { output -> input.copyTo(output, 1 shl 16) }
    }
    check(tmp.length() == EXPECTED_BYTES) { "model copy truncated" }     // fast pre-check
    check(tmp.sha256() == EXPECTED_SHA256) { "model copy corrupt" }      // integrity gate (checksum, not just length)
    tmp.renameTo(dest)                                                   // atomic publish
    return dest
}
```
Then hand `dest.absolutePath` across the **P2-A** JNI bridge to `whisper_init_from_file_with_params` (the audited bridge contract; plan Phase 2 §5); on the sherpa branch, hand the extracted model **directory** to the path-based `OfflineRecognizer(cfg)` (the P2-A adapter) — the engine never reads the compressed asset namespace on either branch. Cost: the model exists **twice on disk** — once in the un-deletable install-time split, once in `filesDir` (264 MB or ≈640 MB extra, persistent). Robust, storage-heavy.

**Strategy 2 — mmap-in-place via file descriptor (whisper/GGML-only optimization).** ONNX Runtime does not mmap (⚠ RAM caveat above) — it materializes weights into the session arena regardless, so mmap-in-place saves **no runtime RAM for Parakeet**, only the on-disk duplicate; the strategy's rationale holds for the whisper/GGML branch only. Avoid the duplicate copy by mmap-ing the model straight out of the APK. Requires the asset be stored **uncompressed** — `AAsset_openFileDescriptor64()` returns `< 0` if the asset is compressed ([NDK Asset ref](https://developer.android.com/ndk/reference/group/asset)) — and returns an fd + offset + length into the APK zip that native code mmaps at that offset:
```kotlin
// Gradle: keep the model uncompressed so a file descriptor is obtainable
android {
    androidResources { noCompress += listOf("bin", "onnx") }
}
```
```c
// native: fd points at the APK; offset/length locate the blob within it
AAsset* a = AAssetManager_open(mgr, "models/ggml-small-q8_0.bin", AASSET_MODE_UNKNOWN);
off64_t start, len;
int fd = AAsset_openFileDescriptor64(a, &start, &len);   // < 0 if compressed → fail loudly
void* base = mmap(NULL, len, PROT_READ, MAP_PRIVATE, fd, start & ~(pageSize - 1));
// feed base(+intra-page delta) to whisper_init_from_buffer_with_params (whisper/GGML branch only)
```
Constraints that make this the *second* choice, not the default:
- The engine must accept a **buffer/fd**, not just a path (`whisper_init_from_buffer_with_params` exists — the non-`_with_params` form is `WHISPER_DEPRECATED`, per Rule 6; sherpa-onnx is out of scope for this strategy — no RAM win, see above).
- Uncompressed storage inflates the on-disk pack (no zip compression on the weights).
- The blob's offset within the zip must land on a **16 KB page boundary** for mmap to succeed on 16 KB-page devices — the same 16 KB regime P0.1 enforces for `.so`s (API 35+, [page-sizes](https://developer.android.com/guide/practices/page-sizes)) — and AGP does not guarantee page-alignment for arbitrary uncompressed assets. This is the concrete footgun.

**Ruling:** ship Strategy 1 (extract) for v1 — proven, engine-agnostic, no alignment gamble. Treat Strategy 2 as a follow-up spike only if the duplicate-on-disk footprint proves unacceptable on low-storage mid-tier devices.

### Load / RAM / unload lifecycle

- **RAM at load — engine-dependent (see the ⚠ RAM caveat above).** **whisper.cpp/GGML mmaps its weights** — demand-paged, file-backed, evictable clean pages under memory pressure — so peak RSS ≈ resident weight pages + KV/compute scratch + mel buffer, near its **264 MB** on-disk size (q8 ≈ 1 byte/param, ~244 M params). **Parakeet under ONNX Runtime does NOT mmap** — initializers materialize into the session arena, so peak RSS is **≈1.2 GB (~2× the ≈640 MB on-disk)** ([sherpa-onnx #2626](https://github.com/k2-fsa/sherpa-onnx/issues/2626)). On a 4–6 GB mid-tier device Parakeet is by far the tighter fit and **cannot rely on clean-page eviction** the way whisper can. The extract copy (Strategy 1) is a streaming 64 KB buffer — it is **2× disk, not 2× RAM**.
- **Cold load** = first `initModel` after process start or after an unload: mmap + page-in of the weights, storage-bound → sub-second to a few seconds scaling with model size and flash speed. Mirrors iOS `loadModel`.
- **Warm load** = handle already held → effectively free; reuse the resident context.
- **Load-once, hold the handle.** The **P2-A** JNI bridge (the audited contract; plan Phase 2 §5) owns the mutex-guarded native context; Kotlin keeps one instance across check-ins. Do not init per-transcription.
- **Explicit unload API — mirrors iOS.** iOS `unloadModel()` simply drops the reference: `whisperKit = nil` + a log line ([WhisperKitTranscriptionService.swift:216](../app-four/Services/WhisperKit/WhisperKitTranscriptionService.swift#L216)). Android equivalent: the **P2-A** bridge's JNI `nativeFree(handle)` that calls `whisper_free()` / releases the sherpa recognizer, then nulls the Kotlin handle. Call it on memory-pressure callbacks (`onTrimMemory(TRIM_MEMORY_*)`) and when leaving the check-in flow, so a mid-tier device reclaims **≈264 MB (whisper, via `munmap`) / ≈1.2 GB (Parakeet, freeing ONNX Runtime working memory)** when STT is idle. Re-load is a cold load.

### First-launch provisioning UX

- **Install-time ⇒ the model is on the device the moment the app opens** — no download, no spinner, no network. This is the whole point of choosing install-time over on-demand.
- **Strategy 1 (extract):** first launch performs a **one-time copy** (264 / ≈640 MB, disk-bound → a few seconds). Surface a brief, non-blocking **"Preparing transcription…"** state on the first check-in only; subsequent launches skip it (idempotent size check). Write-to-temp + atomic rename guards a copy interrupted by a kill; on next launch the truncated `.tmp` is ignored and the copy re-runs. **Checksum-verify** (byte-length as the fast pre-check only) before first load — length catches truncation, not bit-corruption of a 264/640 MB weight file.
- **Strategy 2 (mmap-in-place):** **zero provisioning** — open the fd and load. No "Preparing…" state at all.
- **Update race (rare):** on a base-app update the model updates atomically with the base (install-time semantics), so the fast-follow/on-demand "binary updated before assets patched" hazard largely doesn't apply — but still **verify model presence before load** and show a graceful retry rather than crashing if assets are momentarily unavailable ([PAD updates note](https://developer.android.com/guide/playcore/asset-delivery)).

### Play limit compliance

| Limit ([Play size limits](https://support.google.com/googleplay/android-developer/answer/9859372)) | Value | Our worst case (Parakeet) | Headroom |
|---|---|---|---|
| Base module | 500 MB | base ≈ tens of MB (no model in base) | ✓ |
| Per asset pack | 1.5 GB | ≈640 MB | ✓ >850 MB |
| **Cumulative install-time** (base + all install-time packs) | **4 GB** | ≈640 MB + base | ✓ far under |
| On-demand / fast-follow cumulative | 30 GB | 0 (not used) | n/a |
| Total app | 34 GB | ≈700 MB | ✓ |

- Both winners clear every limit with wide margin. whisper (264 MB) could even fit the base module, but the pack is still preferred for lifecycle separation.
- **Install-time disk requirement:** installing/updating needs **≥ 2× the total size of all install-time asset packs** in free space ([PAD delivery-types](https://developer.android.com/guide/playcore/asset-delivery)) → ≈**1.3 GB free** for Parakeet, ≈**530 MB** for whisper. This is the plan's "~2× free space at install" risk (2× figure per plan Budget §4 — confirm against the primary PAD install-requirements doc before relying on the 1.3 GB / 530 MB budgets). Strategy 1 then adds a further model-size of *persistent* internal storage on top of the un-deletable pack.
- Install-time packs **count toward the store-listed app size**; on-demand would not. Accepted tradeoff — see Risks.

### Exit criteria (binary)

The workstream is **green** only if ALL hold on a real API 28+ mid-tier device:

1. **AAB builds with the model in an install-time asset pack** — `bundletool`/Play Console shows `stt_model` as an install-time pack contributing to the base install (not a separate download).
2. **Fresh install in airplane mode → app opens → model loads → one check-in transcribes** — proving zero network dependency at first run. (Strategy 1: the one-time "Preparing…" copy completes and verifies; Strategy 2: fd opens and mmap succeeds.)
3. **Explicit unload works** — the Android `unloadModel()`/`nativeFree` releases the native context; measured RSS drops by ≈ the engine's runtime footprint (**~264 MB whisper / ~1.2 GB Parakeet**); a subsequent re-load transcribes correctly.
4. **Peak RSS over 5 consecutive check-ins recorded and within the peak-RSS ceiling (MB) fixed with the owner at kickoff for the target device** — no OOM / low-memory kill (whisper: mmap pages evict cleanly under pressure; Parakeet: ONNX-arena RAM does **not** evict — budget against its ~1.2 GB peak).
5. **16 KB compliance intact** — every `.so` in the base module is 16 KB-aligned (carries the P0.1 gate); if Strategy 2 is used, the weights blob is uncompressed and `AAsset_openFileDescriptor64` returns a valid fd on a 16 KB-page device.

### Risks & effort

| Risk | Impact | Mitigation |
|---|---|---|
| **2× disk at install + persistent duplicate (Strategy 1)** on low-storage mid-tier devices | Provisioning failure / user can't install | Check `filesDir` free space before extract; surface a clear storage error; the pack itself can't be deleted, so budget conservatively. Pursue Strategy 2 if it bites. |
| **mmap-in-place (Strategy 2) needs uncompressed + 16 KB-aligned blob** — AGP won't page-align arbitrary assets | `AAsset_openFileDescriptor64` fails / mmap `EINVAL` on 16 KB devices | Default to Strategy 1; treat Strategy 2 as a separate, verified spike, not a v1 assumption. |
| **Parakeet 640 MB inflates store listing + install footprint** (counts toward listed size) | Lower install conversion; big install on metered/low-storage devices | Surfaced already in P0.2 (accuracy vs size). If whisper survives, pack is 264 MB — materially better. If store size becomes a conversion problem, revisit on-demand/fast-follow (adds download UX — out of current scope). |
| **Engine can't init from buffer/fd** (Strategy 2 path) | Forces Strategy 1 | Verified acceptable — Strategy 1 is the default; buffer init is only needed for the optimization. |
| **Interrupted first-run copy** (process kill mid-extract) | Corrupt/truncated model → load crash | Write-to-`.tmp` + atomic rename + byte-length/checksum gate; re-extract on mismatch. |
| **Present-but-corrupt model / repeated engine-init failure** | Infinite-retry `.failed` loop that can never succeed | On repeated `nativeInit`/recognizer-init failure, invalidate the extracted copy and re-provision (re-extract + checksum); if init still fails, surface a distinct terminal "transcription unavailable" state, not a retry button. |

**Effort: ~2–3 days**, gated on P0.1 (native `.so` load + 16 KB) and P0.2 (winner → model + engine + whether buffer init exists). Breakdown: ~1 d Gradle pack module + AAB assembly + `bundletool` verification; ~1 d on-device provisioning (extract + integrity + "Preparing…" state) and the unload/RSS lifecycle; ~0.5 d airplane-mode first-run + 5-check-in RSS exit-criteria run. **+1–2 d** only if Strategy 2 (mmap-in-place) is pursued.

### Cross-phase dependencies & assumptions

- **Depends on P0.1** (native `.so` packaging + 16 KB page-alignment regime) — the engine `.so`s ride the base module; the 16 KB gate also governs Strategy-2 mmap.
- **Depends on the P0.2 winner** — determines model + on-disk size + engine, and therefore whether the pack is merely-preferred (whisper 264 MB) or mandatory (Parakeet ≈640 MB), and whether buffer/fd init is available.
- **Couples to P2-A (STT JNI bridge, Phase 2 §5)** — the bridge owns the mutex-guarded native context and is where `initModel(path)` and `nativeFree(handle)`/`unloadModel()` live. This workstream supplies the *path/fd*; **P2-A** supplies the *handle lifecycle and transcript marshaling*.
- **Assumes install-time delivery** per the plan ruling (standalone, local-only v1). On-demand/fast-follow (`AssetPackManager.fetch()`, `getPackLocation()`, download UX, 30 GB pool) is explicitly **not** built here; it is the escape hatch if store-listed size hurts conversion.
- **Assumes the engine loads from a filesystem path** (`whisper_init_from_file_with_params`; sherpa-onnx model dir) — true for both P0.2 candidates; this is what makes Strategy 1 engine-agnostic.
- **Assumes single-ABI `arm64-v8a`** app (P0.1). The asset pack is data, not code — ABI-agnostic, no per-ABI model split.
- **Assumes the `skip init`-generated Gradle project** (plan Phase 1 §2) is the host into which the `:stt_model` module is added — not a hand-rolled AGP shell.
- **iOS parity anchor:** the Android unload API mirrors iOS `unloadModel()` = drop reference ([WhisperKitTranscriptionService.swift:216](../app-four/Services/WhisperKit/WhisperKitTranscriptionService.swift#L216)); iOS baseline model is `openai_whisper-small` ([AIModelServiceImpl.swift:116](../app-four/Services/AIModelServiceImpl.swift#L116)), the size/quality reference the Android pack is measured against.

---

## P2-C — Extractor wired end-to-end + parity

**Phase 2 (Core loop), step 6** of [ANDROID_PORT_PLAN.md](ANDROID_PORT_PLAN.md#L38). This workstream takes the STT transcript produced by P2-A (the P0.2-winning engine), runs it through the *existing* Swift `NoteExtraction` extractor compiled natively for Android (the P1 shared core), maps the result to the persistence DTO, and writes it to Kotlin/Room across the P1-E seam. The standing correctness guarantee is the P0.4 golden-fixture suite executed against every Android build; the one genuinely new piece of code is the **STT-output normalization layer** surfaced by P0.2's Day-4 end-to-end check.

### Goal

Reproduce the iOS record→transcribe→**extract**→persist loop on Android with **no re-implementation of the extractor** — the same Swift algorithm runs on both platforms, so signal output is a property of the shared build, not of a re-tested rewrite ([ANDROID_PHASE0.md](ANDROID_PHASE0.md#L907), P0.4 §1). Concretely, for a check-in recorded on Android: transcript → (normalize) → `NLNoteExtractor.extract` → `SummaryResult` field-split → Room row, such that (a) the golden-fixture parity gate stays green on every build, and (b) the residual signal divergence caused by Parakeet-vs-WhisperKit transcript *style* (not WER) is measured, bounded, and accepted at G0. Anything the extractor emits that iOS persists, Android must persist identically for the same transcript.

### Extractor I/O contract (repo grounding)

The extractor is a pure, synchronous, value-type function — the cleanest possible thing to port. All citations verified against the working tree 2026-07-22.

- **Interface.** `protocol NoteExtractor: Sendable { func extract(from transcript: String) -> NoteExtraction }` ([NoteExtraction.swift:199-201](../app-four/Services/NoteExtraction/NoteExtraction.swift#L199)). The production conformer is `public nonisolated struct NLNoteExtractor: NoteExtractor, Sendable` ([NLNoteExtractor.swift:11](../app-four/Services/NoteExtraction/NLNoteExtractor.swift#L11)), constructed with a lexicon: `public init(lexicon: Lexicon = Lexicon())` ([NLNoteExtractor.swift:41](../app-four/Services/NoteExtraction/NLNoteExtractor.swift#L41)).
- **Input.** A single `String` transcript. `extract` trims `.whitespacesAndNewlines` and short-circuits empty input to `NoteExtraction(title: "Empty Note")` ([NLNoteExtractor.swift:101-105](../app-four/Services/NoteExtraction/NLNoteExtractor.swift#L101)); otherwise it splits into sentences and aggregates per-sentence. **No I/O, no clock, no network** — the only environmental inputs are the compiled-in lexicon and (today) Apple-NL tagging, which P0.4 fences.
- **Output.** `struct NoteExtraction: Sendable, Codable, Equatable` ([NoteExtraction.swift:4](../app-four/Services/NoteExtraction/NoteExtraction.swift#L4)) — 27 stored fields: scalar signals (`mood: String?`, `energy/focus: …Level?`), `[String]` cue arrays (emotions, activities, wins, overwhelm, executiveDysfunction, appointments, …), structured regex extractions (`extractedDose: String?`, `sleepHours: Double?`, `onsetMinutes: Int?`, `durationHours: Double?`, `crashTime/intakeContext: String?`), plus `medications: [MedEvent]` and `sleep: SleepNote?`. `MedEvent` carries `name/dose/time/timeLabel/taken/quantity/change/durationHours` ([NoteExtraction.swift:139-159](../app-four/Services/NoteExtraction/NoteExtraction.swift#L139)); `MedEvent.time` is the `HH:mm` value produced by the `NSDataDetector`/`Calendar.current` path that P0.4 flags as ICU/TZ-dependent ([NoteExtraction.swift:142](../app-four/Services/NoteExtraction/NoteExtraction.swift#L142); [ANDROID_PHASE0.md](ANDROID_PHASE0.md#L929)).
- **Level enums.** `MoodLevel/EnergyLevel/FocusLevel/SleepLevel` live in the leaf SPM package `SquirlSignals` (`Levels.swift`), pure `Foundation` value types — already the shared grain ([ANDROID_PHASE0.md](ANDROID_PHASE0.md#L891)).
- **Adapter seam (what the app actually calls).** ViewModels never call `extract` directly; they call `SummarizationService.summarize(rawTranscription:) async throws -> SummaryResult`. The production conformer `NLSummarizationService` ([NLSummarizationService.swift:5](../app-four/Services/NLSummarizationService.swift#L5)) runs `extract` off the main actor via `Task.detached(priority: .userInitiated)` ([NLSummarizationService.swift:24-29](../app-four/Services/NLSummarizationService.swift#L24)), then **enriches** the raw `NoteExtraction` into a `SummaryResult`: derives `topics` ([NLSummarizationService.swift:33-42](../app-four/Services/NLSummarizationService.swift#L33)), synthesizes `SleepEvent`/`SleepLevel` from sleep fields ([NLSummarizationService.swift:49-75](../app-four/Services/NLSummarizationService.swift#L49)), filters side-effect keywords ([:77-85](../app-four/Services/NLSummarizationService.swift#L77)), and packs everything incl. the full `noteExtraction` ([NLSummarizationService.swift:87-102](../app-four/Services/NLSummarizationService.swift#L87)). Callers: [ProcessingViewModel.swift:73](../app-four/ViewModels/ProcessingViewModel.swift#L73), [RecordingDetailViewModel.swift:140](../app-four/ViewModels/RecordingDetailViewModel.swift#L140), [PendingTranscriptionServiceImpl.swift:74](../app-four/Services/PendingTranscriptionServiceImpl.swift#L74). **The port must preserve this whole adapter, not just `extract`** — `topics`/`sleepLevel`/side-effect derivation are part of what persistence keys off, and re-doing them in Kotlin would be a second drift surface.

### The transcript → extract → DTO → persist path

Native Swift owns everything up to a flat DTO; Kotlin/Room only stores. This maximizes the parity-guaranteed shared-Swift surface and minimizes re-implemented Kotlin.

1. **Transcript in.** P2-A's JNI bridge returns the transcript as a UTF-8 `jbyteArray` decoded on the Kotlin side ([ANDROID_PORT_PLAN.md](ANDROID_PORT_PLAN.md#L37), P0.1 §3.6a warns `NewStringUTF` corrupts supplementary chars). The Kotlin transcript string crosses **back** into shared Swift for extraction — do not extract in Kotlin.
2. **Normalize (new — see next section).** `normalize(transcript)` runs in shared Swift *before* `extract`, transforming transducer output toward the WhisperKit style the lexicon/regex were tuned on. On iOS this is a no-op/identity (WhisperKit already produces that style); on Android it is the real transform. **It sits outside the golden-fixture parity gate** (that gate feeds canned transcripts), so it needs its own fixture set (§ normalization).
3. **Extract + enrich.** Call `NLSummarizationService.summarize(rawTranscription:)` on the normalized text — identical code path to iOS, producing a `SummaryResult` (incl. the full `NoteExtraction`, topics, sleepEvent, sleepLevel).
4. **Field-split to DTO (port `applySummary`'s split logic into shared Swift).** iOS persistence does **not** store the whole `NoteExtraction` blob. In `Recording.applySummary` the scalar-duplicated fields are nulled — `mood/energy/focus/emotions/sideEffects/sleepHours` live in dedicated scalar columns (source of truth) — and only the *residual* is JSON-encoded into `noteExtractionJSON: String?` ([Recording.swift:256-267](../app-four/Models/Recording.swift#L256), field decl [:41](../app-four/Models/Recording.swift#L41)). Bullets/emotions/sideEffects/sleepEvent/topics each get their own column/JSON ([Recording.swift:248-289](../app-four/Models/Recording.swift#L248)). **Port this exact split into a shared-Swift mapper onto the Phase-1 `JournalRecordingDTO`** (the `SquirlModelDTO` 29-field mirror, JSON columns carried as `String?` — see ANDROID_PHASE1.md §DTO layer), persisted via `JournalRepository.upsert` (P1-E). Keep the `applySummary` split; do **not** mint a second parallel DTO type — that would defeat the Phase-1 field-count guard. Doing the split in Swift keeps the "which field is a column vs. a blob" decision single-sourced with iOS; re-encoding it in Kotlin would reintroduce exactly the drift P0.4 exists to kill.
5. **Cross the P1-E seam.** The DTO crosses to Kotlin as flat primitives + JSON strings (SkipBridge marshals value types; a flat DTO minimizes bridge surface vs. marshalling nested `MedEvent`/`SleepNote` graphs). Kotlin Room maps the DTO onto the persistence schema from Phase 1 step 3 — 29 `Recording` stored fields / 3 relationships, `@Upsert`, `@Index` on FK child columns, Date↔Long converters ([ANDROID_PORT_PLAN.md](ANDROID_PORT_PLAN.md#L32)). Room stores; it does not interpret the JSON.
6. **Read-back.** Reconstruction mirrors iOS's computed `noteExtraction` decode from the JSON column ([Recording.swift:190-191](../app-four/Models/Recording.swift#L190)) — Room hands the stored JSON string + scalar columns back to a shared-Swift decode, so display code sees the same `NoteExtraction`.

> **Encoder caveat to carry.** Production persistence uses a **bare `JSONEncoder()`** ([Recording.swift:263](../app-four/Models/Recording.swift#L263)) — insertion-ordered, *not* the canonical `.sortedKeys` encoder the P0.4 fixture suite uses ([ANDROID_PHASE0.md](ANDROID_PHASE0.md#L996)). Within one platform this is fine (write and read agree). It only bites if a persisted `noteExtractionJSON` is ever compared across platforms — which is the sync case, and **sync (038) is out of scope for Android v1** ([ANDROID_PORT_PLAN.md](ANDROID_PORT_PLAN.md#L7)). Recommendation: switch the persistence encoder to the canonical config now (cheap, forward-compatible with the versioned `JournalArchive` interchange hedge), but it is **not** a P2-C blocker.

### STT-output normalization layer (the P0.2-Day-4 task)

**Why it exists.** P0.4 proves the extractor is byte-identical *on identical input text*; P0.2 proves transcript *quality*. Nothing connects them — and the P0.2-winning engine's transcript **style differs from WhisperKit's**: sherpa-onnx Parakeet TDT (the likely survivor per [ANDROID_PORT_PLAN.md](ANDROID_PORT_PLAN.md#L22)) is a transducer that emits different casing, **punctuation density**, and **number formatting** than whisper-small. The lexicon/regex extractor was tuned on WhisperKit output, so signals can diverge **at equal WER and perfect extractor parity** — this is the explicit Day-4 finding ([ANDROID_PHASE0.md](ANDROID_PHASE0.md#L605)).

**Where the divergence actually bites (grounded in the extractor):**
- **Punctuation → sentence boundaries.** `splitSentences` uses `NLTokenizer(unit: .sentence)` ([NLNoteExtractor.swift:332](../app-four/Services/NoteExtraction/NLNoteExtractor.swift#L332)) — an Apple-NL API (ICU sentence segmenter) that the P0.4 `LinguisticProvider` fence replaces with a deterministic portable sentence tokenizer, **not** a naive terminator split; the normalizer must target that portable tokenizer's segmentation ([ANDROID_PHASE0.md](ANDROID_PHASE0.md#L955)). Transducers routinely under-punctuate; a run-on transcript collapses into one "sentence", changing per-sentence mood/tense aggregation (present-tense-wins mood policy, [NLNoteExtractor.swift:110-116](../app-four/Services/NoteExtraction/NLNoteExtractor.swift#L110)) even though every word is correct. **This is the highest-impact style axis.**
- **Number/unit formatting → regex extractions.** The dose/sleep/onset/duration/crash regexes ([NLNoteExtractor.swift:944-1032](../app-four/Services/NoteExtraction/NLNoteExtractor.swift#L944)) and `extractPreciseTime`/`extractSleepHours` parse specific numeral+unit shapes. `"10 mg"` vs `"ten milligrams"` vs `"10mg"`, or `"half a pill"` vs `"0.5"`, changes `extractedDose`/`quantity`/`sleepHours`/`onsetMinutes`. Whisper spells numbers one way; Parakeet another.
- **Casing → mostly absorbed.** Cue matching folds to `lowercased()` and regexes are `(?i)`, so casing is largely neutral — **do not** over-invest here.

**Design — a deterministic, source-controlled normalizer between STT and extractor.** Preferred approach, in order:
1. **Punctuation/sentence restoration.** Prefer the STT engine's own capability if it produces punctuation; else run sherpa-onnx's optional punctuation-restoration model as a post-STT pass (sherpa-onnx ships add-punctuation models, https://k2-fsa.github.io/sherpa/onnx/punctuation/index.html). Trade-off: a model reintroduces version-sensitivity — pin it and fixture-lock its output, same discipline as P0.4's tokenizer.
2. **Number/unit standardization.** A small, checked-in, deterministic rule pass (number-words→digits, unit spacing/abbreviation canonicalization) tuned to move Parakeet's distribution onto WhisperKit's. Rule-based (not model) so it is byte-deterministic and reviewable.
3. **Do the minimum.** Every transform is a divergence risk of its own; normalize only the axes the Day-4 measurement shows actually move signals, not cosmetically.

**Critical scoping facts:**
- The normalizer is **Android-side / asymmetric**. iOS keeps feeding raw WhisperKit text to `extract`; Android inserts `normalize` before `extract`. That is *correct* — parity is defined per-identical-input, and the two platforms legitimately have different STT front-ends. The golden-fixture suite (canned transcripts) is unaffected because it bypasses STT entirely.
- Therefore the normalizer needs its **own gate**, distinct from the P0.4 fixture suite: the P0.2 Day-4 corpus — feed the winning engine's golden-clip transcripts through `normalize → extract` and compare emitted signals (med events, mood/energy/focus, dose/sleep) against the iOS reference (`whisper-small transcript → extract`) per clip ([ANDROID_PHASE0.md](ANDROID_PHASE0.md#L605)). Residual divergence must sit under the tolerance the owner accepts at G0.
- **Fixture-generation is an itemized task, not assumed:** record/reuse ≥20 golden clips (the P0.2 corpus), run the winning engine to produce transcripts, run the iOS reference path to produce expected-signal JSON per clip, check both in. The G0 tolerance is a **post-normalizer target strictly below the pre-normalizer Day-4 divergence baseline** (equal to the baseline would be trivially met and prove the normalizer does nothing); if the target proves unreachable, the fallback is an explicit owner sign-off on the higher residual divergence, or a re-scope — not silent acceptance.
- Do **not** confuse this with the P0.2 **scoring** normalizer (OpenAI Whisper `EnglishTextNormalizer`/`BasicTextNormalizer`, [ANDROID_PHASE0.md](ANDROID_PHASE0.md#L476)). That one normalizes hypotheses+references for **WER measurement** only; it never touches the production extraction path. The P2-C normalizer is a **production runtime component** with different goals (match a distribution, not strip to a canonical scoring form).

### Golden-fixture parity in the build

The P0.4 suite is the standing parity guarantee; P2-C's job is to make it **build-gating**, not one-shot.

- **Artifact.** `Tests/ExtractorFixtures/` — 40–60 `NNN-slug.txt` (raw transcript) + `NNN-slug.json` (canonical `NoteExtraction` JSON via `.sortedKeys, .withoutEscapingSlashes`), the iOS extractor being the reference generator ([ANDROID_PHASE0.md](ANDROID_PHASE0.md#L983)). Assertion is **byte-equality** `Data == Data`, not `NoteExtraction ==`, to catch encoding drift ([ANDROID_PHASE0.md](ANDROID_PHASE0.md#L1008)).
- **iOS side.** `swift test` over all cases (host).
- **Android side.** No `swift test` for the Android triple; P0.4 built a `fixture-runner` executable (`swift build --swift-sdk aarch64-unknown-linux-android28`, `adb push` binary+fixtures to `/data/local/tmp`, `adb shell` run), checked in as `scripts/android/run-fixtures.sh` ([ANDROID_PHASE0.md](ANDROID_PHASE0.md#L1019)).
- **P2-C wiring (the new work).** Phase 1 step 2 stands up the Android CI job that cross-compiles the Swift core + assembles a debug APK on every push ([ANDROID_PORT_PLAN.md](ANDROID_PORT_PLAN.md#L31)). P2-C makes `run-fixtures.sh` a **required, build-failing check** in that job (device or emulator target), so byte-parity is re-proven on every commit — "this *is* the parity guarantee that Option B's rewrite was supposed to buy" ([ANDROID_PORT_PLAN.md](ANDROID_PORT_PLAN.md#L38)). Adding a fixture covers both platforms automatically. The normalizer fixture set (previous section) is a **second** required check in the same job.

### P0.4 fences that must land first (dependency on Phase 1 / P0.4)

P2-C cannot wire anything until the shared extractor core actually compiles and runs deterministically on the Android triple. These are P0.4 exit items ([ANDROID_PHASE0.md](ANDROID_PHASE0.md#L1036)) landed as Phase 1 shared-core extraction (step 1); P2-C consumes them:

1. **`LinguisticProvider` fence.** All Apple-`NaturalLanguage` sites A–F behind the protocol with a working `PortableLinguisticProvider` (deterministic word/sentence tokenizer, POS, lemma); dead `import NaturalLanguage` deleted; other imports repointed to the shim ([ANDROID_PHASE0.md](ANDROID_PHASE0.md#L936)).
2. **Static inflection tables.** `canonicalInflections` + `cueLemmas` populated from the committed offline generator, byte-identical on both platforms, runtime `NLTagger` lemma/POS dead on Android ([ANDROID_PHASE0.md](ANDROID_PHASE0.md#L966); currently `canonicalInflections = [:]`, CueMatcher.swift:124).
3. **Lexicon compiled-in / hard-failing.** The `Bundle.main` loader must not silently fall back to the smaller hardcoded `defaultX` arrays (medications 56 vs 89, etc.) — both platforms resolve identical lexicon bytes ([ANDROID_PHASE0.md](ANDROID_PHASE0.md#L895)).
4. **Non-NL Foundation fences.** `NSDataDetector`+`Calendar.current` (`MedEvent.time`) pinned to fixed locale/UTC/Gregorian or replaced with a deterministic time parser; `NSRegularExpression` verified on the Android SDK or migrated to Swift `Regex`; both fixture-guarded ([ANDROID_PHASE0.md](ANDROID_PHASE0.md#L928)).
5. **`SquirlSignals` resolves for the Android triple** (iOS-26 platform pin relaxed; verify the *actual* resolution blocker empirically — the pin is likely not it) ([ANDROID_PHASE0.md](ANDROID_PHASE0.md#L1023)).

If P0.4's §8 escape hatch was invoked (deterministic tokenizer made authoritative on iOS too), P2-C inherits the re-baselined goldens and the persisted-JSON migration is a *separate* named Phase 1 task, not P2-C's ([ANDROID_PHASE0.md](ANDROID_PHASE0.md#L1055)).

### Exit criteria (binary)

P2-C is done iff **all** hold:

1. **End-to-end loop works on device.** A check-in recorded on Android (real STT, not a canned string) produces a persisted Room row whose read-back `NoteExtraction` + scalar columns decode to exactly what the shared extractor emitted for that transcript.
2. **DTO split mirrors iOS.** The shared-Swift `SummaryResult → JournalRecordingDTO` mapping reproduces `Recording.applySummary`'s scalar-column-vs-residual-JSON split ([Recording.swift:256-289](../app-four/Models/Recording.swift#L256)) — no field double-stored, none dropped, no new DTO type minted; topics/sleepLevel/side-effect derivation come from shared Swift, not re-implemented in Kotlin.
3. **Golden-fixture suite is build-gating and green.** `scripts/android/run-fixtures.sh` runs in the Android CI job on every commit and **fails the build** on any byte-diff; identical corpus green on iOS `swift test`.
4. **Normalizer landed + its own gate green.** The STT-output normalization layer is in the Android extract path (asymmetric; iOS unchanged), source-controlled, with its own fixture set in CI (≥20-clip corpus, itemized generation task above). On the P0.2 Day-4 corpus, Android(`STT→normalize→extract`) signal divergence vs iOS(`whisper-small→extract`) is ≤ the owner-accepted G0 tolerance — defined as a **post-normalizer target strictly below the pre-normalizer Day-4 baseline** (metric + value fixed with the owner at kickoff), measured and recorded.
5. **All five P0.4 fences (above) landed and verified on the Android triple** — extractor core + `SquirlSignals` compile for `aarch64-unknown-linux-android28`, deterministic, byte-parity holding.

Miss any one → not done. The sharpest single failures are (4) normalizer under/over-shooting (a genuinely new algorithm with no shared-code parity backstop) and (1) a DTO/Room mapping that quietly drops or double-counts a field.

### Risks & effort

| Risk | Impact | Mitigation |
|---|---|---|
| **Normalizer is the one un-parity-guaranteed component.** It is new Android-side code with no iOS twin to diff against byte-for-byte; its own fixture set is the only guard. Over-normalizing injects divergence; under-normalizing leaves the Day-4 style gap. | Signals diverge from iOS at equal WER — the exact failure Day-4 named. | Normalize only axes the Day-4 measurement proves move signals (punctuation first, numbers second, casing not at all). Rule-based where possible for determinism; if a punctuation model is used, pin + fixture-lock it. Freeze its fixture tolerance at G0, not post-hoc. |
| **DTO/Room mapping drift.** 29 stored fields, 3 relationships, a scalar-vs-JSON split, nested `MedEvent`/`SleepNote`. | A silently mis-mapped field renders wrong or loses data. | Do the split in shared Swift (the `SummaryResult → JournalRecordingDTO` mapper), not Kotlin; flat-primitive DTO across the seam; round-trip test in exit criterion 1. |
| **Bridge marshalling cost / correctness (SkipBridge).** Crossing `SummaryResult`/DTO Swift→Kotlin. | Perf or correctness bug at the seam. | Cross flat primitives + JSON strings, not object graphs; keep enrichment in Swift so only leaf values bridge. |
| **Encoder mismatch (bare vs canonical).** Production `JSONEncoder()` ≠ fixture `.sortedKeys`. | Only bites cross-platform (sync), which is v1-out-of-scope. | Switch production to canonical encoder opportunistically; not a blocker now; keeps `JournalArchive` interchange hedge intact. |
| **Fixture-runner flakiness in CI** (adb/device/emulator). | Parity gate becomes ignorable if it flaps. | Treat runner failures as red; run on a pinned emulator ABI in CI (`x86_64-unknown-linux-android28`) with a device pass before release. |

**Effort.** This is an *integration* workstream sitting on top of a de-risked extractor, so most cost is the normalizer and the DTO seam, not the extractor.
- **Normalizer:** the real work — measurement-driven design + fixtures + (optional) punctuation model integration. **~3–5 d**, dominated by the Day-4 measure/iterate loop and whether a punctuation model is needed.
- **DTO split + Room mapping + seam:** port `applySummary` split to shared Swift, flat DTO, Kotlin Room mapping, round-trip test. **~2–3 d.**
- **CI wiring of the two fixture gates:** **~1 d** (assumes Phase 1 step 2 already stood up the Android CI job).
- **Total P2-C: ~6–9 engineer-days**, gated on P0.4 fences (Phase 1) being landed and the P2-A STT winner being callable. The normalizer is the schedule risk; everything else is mechanical.

### Cross-phase dependencies & assumptions

- **Depends on P0.4 (Phase 0) → landed in Phase 1 shared-core extraction (step 1):** the `LinguisticProvider` fence, static inflection/cueLemma tables, compiled-in lexicon, `NSDataDetector`/`Calendar`/`NSRegularExpression` fences, and `SquirlSignals` Android-triple resolution must all be green before P2-C wires anything. P2-C does not itself port the extractor — it consumes the ported extractor.
- **Depends on P2-A (STT integration, Phase 2 step 5):** the JNI bridge must return a decodable UTF-8 transcript and expose the *identity of the winning engine* (Parakeet vs whisper vs QNN), because the normalizer is tuned to that engine's output distribution. A different P0.2 winner → a different normalizer.
- **Depends on P0.2 Day-4 measurement + G0 decision sheet:** the normalizer's target axes and its accepted divergence tolerance are set by the Day-4 signal-divergence numbers and the owner's G0 sign-off — not chosen inside P2-C. Assumes those numbers exist and a tolerance was frozen (P0.2.0 pre-registration discipline).
- **Depends on P0.3 persistence fork:** exit criterion 2 assumes **Room** (the plan's DTO split). If P0.3 picked **SkipSQL**, the seam changes — the DTO lands in a shared-Swift SQL layer instead of crossing to Kotlin, and P1-E is a different seam. The extract→DTO logic is unchanged; only step 5 (persist) differs.
- **Depends on Phase 1 step 2 (Android CI):** the parity gate is only "standing" if CI exists to run it every commit. Phase 0 has no CI ([ANDROID_PHASE0.md](ANDROID_PHASE0.md#L1085)); P2-C assumes the Phase 1 CI job is the host for `run-fixtures.sh` + the normalizer fixtures.
- **Assumes sync (038) stays out of scope for v1** ([ANDROID_PORT_PLAN.md](ANDROID_PORT_PLAN.md#L7)): this is what makes the bare-`JSONEncoder()` cross-platform-byte question non-blocking. If Android v2 adds sync, canonical encoding on both platforms + the normalizer's asymmetry both become first-class correctness concerns for the interchange format.
- **Assumes the adapter (`NLSummarizationService`), not just `extract`, is in the shared core:** topics/sleepLevel/side-effect derivation are load-bearing for persistence and must not be re-implemented in Kotlin.
- **Feeds Phase 2 step 7 (UI build-out, P2-D):** recording-detail (027 layout) and day-card rendering read the persisted `NoteExtraction`; P2-C's read-back path (exit criterion 1) is their data source.

---

## P2-D — UI build-out (SkipFuseUI)

> **⚠ Supersedes P0.3 assumption.** P0.3 (Phase 0) recorded the signal glyphs as **SF Symbols** with an easy `Image(systemName:)` + bundled-vector Android path, and framed a custom-`Shape` port as merely optional (for live morphing). **That premise is wrong for the shipped code.** Verified in the working tree (§Glyph approach), **four of the five signal glyphs are drawn with SwiftUI `Canvas`**, which SkipUI does **not** support — so the bundled-vector path is *not free* and the glyph port is real rewrite work, the single largest fidelity risk in this workstream. Where this section conflicts with P0.3 §3c / fork F2, **P2-D's grounded finding governs.** Plan of record: port the four `Canvas` glyphs to composed `Shape`s in `SquirlDesignSystem` and adopt them on iOS too (Option A) — a shared-core upgrade, not a fork. Carried into Consolidated.

**Basis.** This section expands step 7 of Phase 2 in [ANDROID_PORT_PLAN.md](ANDROID_PORT_PLAN.md#L39) ("UI build-out … check-in flow → day card/calendar → recording detail (027 layout) → settings (minimal). HTML-mockup-first rule applies per screen where the Android layout diverges from iOS"). It inherits the three forks resolved (or scoped) by the P0.3 spike ([ANDROID_PHASE0.md §P0.3](ANDROID_PHASE0.md#L628)) and turns them into per-screen build plans.

**Source-of-truth ordering.** Where DESIGN.md and the shipped SwiftUI disagree, the **code wins** (project rule *mockups-source-of-truth*: reproduce UI from SwiftUI, not the mockup dirs, which have drifted). One such drift is load-bearing here and is corrected in §Glyph approach. External claims cite a URL; repo/design claims cite `file:line` or a DESIGN.md section.

**SkipUI support-matrix snapshot.** All matrix statuses below were re-verified live against the current `skiptools/skip-ui` README on **2026-07-22** ([raw README](https://raw.githubusercontent.com/skiptools/skip-ui/main/README.md); the human-readable matrix is [github.com/skiptools/skip-ui](https://github.com/skiptools/skip-ui)). The matrix's governing rule is *"Anything not listed here is likely not supported"* — so **"not listed" is treated as a red gap, not an unknown**.

---

### Goal

Build the four core-loop surfaces natively from the **shared Swift/SwiftUI source** via SkipFuseUI → SkipUI (Compose), at fidelity acceptable against the shipping iOS app, on a real arm64 Android device:

1. **Check-in flow** — idle hub → recording → saved (the signature capture surface).
2. **Calendar + day card** — collapsible week↔month strip over the folding `DayCard`.
3. **Recording detail** — the **spec-027** layout (info cards + pencil toolbar + visible delete), *not* the older DESIGN.md §Recording-detail bullet.
4. **Settings (minimal)** — native grouped `List`, trimmed to the Android-v1 in-scope surface.

The binary bar is *not* "does it compile" but **"how much of each screen stays in the shared Swift core vs. leaks into per-platform Compose/asset fallback"** ([ANDROID_PHASE0.md §P0.3.8](ANDROID_PHASE0.md#L860)). Each screen carries an erosion budget (Exit criteria).

---

### The P0.3 forks this workstream inherits

P0.3 is the architecture spike that resolves three forks P2-D must consume as *decisions*, not re-open ([ANDROID_PHASE0.md §P0.3.1](ANDROID_PHASE0.md#L634)):

| Fork | P0.3 disposition | What P2-D does with it |
|---|---|---|
| **F1 — Persistence (what the UI reads/writes)** | SkipSQL (shared Swift core) vs Room-behind-SkipBridge (platform split). P0.3 proves the **SkipSQL round-trip under `mode: 'native'`** and delivers a cost sheet; the owner calls it at G0 ([§P0.3.5](ANDROID_PHASE0.md#L801)). SkipSQL is Skip's grain; SwiftData is unsupported on Android. | The UI reads a `Recording`-like row via whichever backing won. **All four screens are written against a persistence *protocol* (DTO in/out), never a concrete store**, so the fork is invisible above the data layer. If SkipSQL won: `@Query`-style live reads are replaced by an observable store wrapper the views subscribe to (SwiftData `@Query` is iOS-only). |
| **F2 — Glyphs (bundled SF-Symbol vector vs custom Shape)** | P0.3 tests **both** paths and recommends. **Correction inherited: `Image(systemName:)` works on Android** via bundled same-named SF-Symbol vector assets ([skip-ui README §Symbols](https://github.com/skiptools/skip-ui#symbols) — "add same-named vector symbols manually, so that code like `Image(systemName: \"folder.fill\")` … will use your included folder.fill.svg vector asset on Android"); custom Shape is a *design* choice for live morphing, not a necessity. | **But the shipped code already moved off SF Symbols for signals** — see §Glyph approach and the ⚠ callout above. This changes F2 materially: the "bundle 5 vectors" path is **not** free here, because the current glyphs are `Canvas` drawings, not `Image(systemName:)`. P2-D must pick a concrete glyph strategy per §Glyph approach. |
| **F3 — Typography (Roboto vs bundled Inter)** | Default **Roboto** (each platform's system sans; identity lives in layout/color/glyphs, not the face — the 023 reversal). Escalate to bundled **Inter** only if side-by-side QA of the check-in screen fails the owner-signed row-9 bar ([§P0.3.6](ANDROID_PHASE0.md#L824)). | Every `Typography.*` role maps to the Roboto weight ladder by default; Inter is the ready fallback (already the project's SF stand-in in Figma — memory *figma-native-build*). No SF bundling (licensing + non-native). |

**Tokens carry for free.** `Packages/SquirlDesignSystem` (`NewLook`, `Palette`, `Radius`, `Spacing`, `Typography`) is the **same Swift** under Fuse — `Color(lightHex:darkHex:)` ([NewLook.swift:13](../Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/NewLook.swift#L13)) maps to Compose `Color`, `Radius`/`Spacing` numerics map to `dp` 1:1 ([§P0.3.6](ANDROID_PHASE0.md#L832)). **Confirm sRGB not P3** so the mood ramp `#DA7A2A…#2E8B57` doesn't diverge across wide-gamut iOS vs sRGB Android. P0.3 §Step-4 must report whether the package compiles unmodified under Fuse or needs the copy-in workaround; P2-D assumes the tokens resolve.

---

### Per-screen specs

Legend for the construct→matrix column: ✅ supported · 🟡 caveat (renders, deviates — measure) · 🔴 not listed → treat as unsupported, assign a fallback. Fallback ladder (P0.3 §4, preference order): **1 Simplify** (drop to a supported construct preserving intent) → **2 Static/bundled-vector asset** → **3 Per-screen Compose** (last resort; each use erodes the shared core and counts against the erosion budget).

---

#### Screen 1 — Check-in flow

iOS source: [CheckInView.swift](../app-four/Views/CheckIn/CheckInView.swift), [CrescentRing.swift](../app-four/Views/CheckIn/CrescentRing.swift), [TextCheckInComposer.swift](../app-four/Views/CheckIn/TextCheckInComposer.swift). DESIGN.md §Screen Specs "Check-in — three states" + §New Look. Three states share one anchored `ZStack` so the crescent grows in place: **idle hub** (breathing ring + Speak / Log meds / Type note) → **recording** (prompt card + timer + Stop & save) → **saved** (check disc pop + "Captured." + Done).

| Construct (repo ref) | SkipUI | Fallback / note |
|---|---|---|
| `ZStack`/`VStack`/`HStack`, `Spacer`, `padding`, `frame(maxWidth:)` | ✅ | core layout |
| `Image(systemName:)` chrome — `mic.fill`, `square.and.pencil`, `checkmark`, `Icons.medication` ([CheckInView.swift:210,199,440,195](../app-four/Views/CheckIn/CheckInView.swift#L195)) | ✅ `init(systemName:)` | auto-maps only a small subset to Material; **bundle same-named SF vectors** for exact match ([skip-ui README §Symbols](https://github.com/skiptools/skip-ui#symbols)) |
| Speak/Stop/Done pills — `.background(Theme.meadowGreen, in: Capsule())` ([:216](../app-four/Views/CheckIn/CheckInView.swift#L216)) | ✅ `Capsule`, `fill` | — |
| `CheckInPrimaryButtonStyle` — `LinearGradient([checkInGreen, checkInGreenSoft])` ([Buttons.swift:29](../Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/Buttons.swift#L29)) | ✅ `LinearGradient` | ring gradient endpoints/direction must match (P0.3 row 3) |
| `.newLookCardShadow()` two-layer `.shadow` ([NewLook.swift:62](../Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/NewLook.swift#L62)) | 🟡 shadow supported but **"place before .background/.overlay"**; `newLookCard` applies `.background` *then* `.shadow` | measure elevation both modes; if wrong, reorder modifiers or simplify to single-layer (P0.3 row 5) |
| `promptProgressBar` — `GeometryReader { Capsule fill width * progress }` ([:304](../app-four/Views/CheckIn/CheckInView.swift#L304)) | 🟡 `GeometryReader` (GeometryProxy limits; local/global coords only) — measure | measure the fraction-width layout on Compose |
| **`CrescentRing`** — `Circle().stroke(meadowGreen)` + `.rotationEffect`/`.scaleEffect`/`.opacity` + `.animation(...repeatForever)` ([CrescentRing.swift:26](../app-four/Views/CheckIn/CrescentRing.swift#L26)) | 🟡 rotation/scale/opacity ✅; **`repeatForever` = medium** ("true spring animations cannot repeat", workarounds exist) | the breathe/spin are linear/easeInOut, not spring → should repeat; **verify empirically** (this is the signature idle motion). Honor Reduce Motion → static (already coded) |
| Prompt transitions — `.transition(.move+.opacity)`, `withAnimation(.easeInOut)` ([:329](../app-four/Views/CheckIn/CheckInView.swift#L329)) | ✅ subset (move/opacity are listed animatables) | no custom `Transition` used → safe |
| `TextCheckInComposer` — `TextField`/`TextEditor` glyph-pickers-first (Layout A) | ✅ `TextField`; 🟡 `TextEditor` (`.font/.lineSpacing` no-op) | if transcript/note styling matters, wrap or accept default |
| `.sheet` (med log, composer), `.alert` (mic, disk) ([:34,46](../app-four/Views/CheckIn/CheckInView.swift#L34)) | ✅ `sheet`, ✅ `alert` | mic-permission + FGS-microphone is P2-C/Phase-1 audio work, not UI |
| `AccessibilityNotification.Announcement`, a11y labels/traits | 🔴 `Announcement` unsupported (P3-B resolves it → `ComposeView` fallback for the live prompt-advance announcement); labels/traits ✅ | TalkBack pass is Phase 3; keep the labels in shared source |

**Signal glyphs on this screen:** the idle/recording/saved states use **SF-Symbol chrome only** — the *signal* glyphs (Sprout/Bolt/Aperture) do **not** appear in the capture flow; they surface in Type-note (Layout A pickers), day card, and recording detail. So the check-in flow's glyph risk is limited to SF-Symbol bundling, **not** the `Canvas` problem. That makes it the correct P0.3 first screen (lowest glyph risk, highest layout signal).

**Divergence from iOS → HTML mockup?** **No.** The layout is 1:1 portable; nothing here diverges structurally. Build directly from the SwiftUI. The only open item is empirical (`repeatForever` crescent + shadow ordering), settled by side-by-side QA, not a redesign.

---

#### Screen 2 — Calendar + day card

iOS source: [CalendarLibraryView.swift](../app-four/Views/Library/CalendarLibraryView.swift), [CalendarHeaderView.swift](../app-four/Views/Components/CalendarHeaderView.swift), [DayCard.swift](../app-four/Views/Components/DayCard.swift), [FoldedDayCardHeader.swift](../app-four/Views/Components/FoldedDayCardHeader.swift). DESIGN.md §Screen Specs "Calendar — **Unchanged** … do not redesign without explicit ask" + §New Look. A collapsible week↔month header (`DragGesture`) sits above a `LazyVStack` of folding `DayCard`s; each card is a mood-tinted folded header that expands to check-in rows.

| Construct (repo ref) | SkipUI | Fallback / note |
|---|---|---|
| `DayCard` — `RoundedRectangle(cornerRadius: Radius.newLookCard)`, `.background(NewLook.card)`, `.clipShape`, `.newLookCardShadow()` ([DayCard.swift:14,35](../app-four/Views/Components/DayCard.swift#L14)) | ✅ `RoundedRectangle`, `fill`, `clipShape`; 🟡 shadow ordering | supported; shadow caveat as Screen 1 |
| Folded header tint band — `.background(level?.blockTint)` mood-ramp fill ([FoldedDayCardHeader.swift:62](../app-four/Views/Components/FoldedDayCardHeader.swift#L62)) | ✅ flat fill | ramp hexes ΔE<3 (P0.3 row 4); ramps are **flat fills, not AngularGradient** → the AngularGradient gap does not bite |
| **Summary chips — `FlowLayout: Layout`** ([FoldedDayCardHeader.swift:83](../app-four/Views/Components/FoldedDayCardHeader.swift#L83); def [TagFlowView.swift:32](../app-four/Views/Components/TagFlowView.swift#L32)) | 🔴 **custom `Layout` protocol NOT listed** | **Fallback 1 — Simplify**: reflow chips with a wrapping `HStack`/`WrappingHStack` built from supported primitives, or a fixed-column grid. Custom `Layout` conformance is the concrete gap here |
| **Signal glyphs in chips** — `SignalGlyph(.energy/.focus/.medication/.sleep)` ([FoldedDayCardHeader.swift:89](../app-four/Views/Components/FoldedDayCardHeader.swift#L89)) | 🔴 4/5 use `Canvas` (see §Glyph approach) | per §Glyph approach — the day card is the **densest glyph surface** and the primary consumer of the glyph decision |
| Concatenated per-run `Text` (mood word + weekday, per-run font/color) ([:72](../app-four/Views/Components/FoldedDayCardHeader.swift#L72)) | 🟡 verify | styled `Text` interpolation may not carry every per-run attribute; measure the "Great · MON" title |
| Collapsible header — `DragGesture(minimumDistance:24)` ([CalendarHeaderView.swift:117](../app-four/Views/Components/CalendarHeaderView.swift#L117)) | ✅ `DragGesture` (per Gestures section) | verify the week↔month interpolation; if it uses `matchedGeometryEffect` it is 🔴 not listed |
| Container — `ScrollView { header + LazyVStack }` ([CalendarLibraryView.swift:118,127](../app-four/Views/Library/CalendarLibraryView.swift#L118)) | 🟡 **`LazyVStack` "must be the only child" of a `ScrollView`** | the current ScrollView holds header **and** LazyVStack → **restructure**: move the header out of the scroll (pin above) or make the whole thing one `List`/lazy container. Fallback 1 |

**Divergence from iOS → HTML mockup?** **Yes — mockup-first for the container + chip reflow.** The calendar is owner-locked as a design ("do not redesign"), but its **implementation** must change on Android in two places (LazyVStack-only-child restructuring; FlowLayout → supported reflow). Because those touch layout, produce an **HTML mockup of the reflowed day-card summary + the pinned-header calendar** before writing SwiftUI, confirming the visual is unchanged even though the construct tree isn't. The week↔month collapse animation is the highest-risk interaction — mock its two end states.

---

#### Screen 3 — Recording detail (spec 027 layout)

iOS source: [RecordingDetailView.swift](../app-four/Views/RecordingDetailView.swift). **Ground-truth correction:** the shipped layout is **spec 027** (memory *spec-027-state*: 4 info cards + pencil toolbar + visible delete), **not** the older DESIGN.md §Recording-detail bullet (which says "no back button, pencil removed, Edit-check-in button"). Build to the code. Top-to-bottom: title + meta → signal hero strip (`newLookCard`) → `ADHDSummarySection` → collapsible transcript card → audio card (last) → destructive "Delete check-in"; nav bar carries the date (principal) + a pencil edit button (trailing) + `.confirmationDialog` delete.

| Construct (repo ref) | SkipUI | Fallback / note |
|---|---|---|
| `ScrollView { VStack(spacing) }` page ([RecordingDetailView.swift:26](../app-four/Views/RecordingDetailView.swift#L26)) | ✅ `ScrollView` | not a LazyVStack → no only-child caveat |
| `.newLookCard()` × 3 (hero, transcript, audio) | 🟡 shadow ordering | as Screen 1 |
| **Signal hero strip** — `SignalGlyph(kind, level:, size:30)` ([:141](../app-four/Views/RecordingDetailView.swift#L141)) | 🔴 `Canvas` glyphs | §Glyph approach — **must render at 30 pt with level distinction intact** (the hero is the largest glyph in the app) |
| `levelBar` — `GeometryReader { Capsule fill * fraction }` ([:157](../app-four/Views/RecordingDetailView.swift#L157)) | 🟡 `GeometryReader` (GeometryProxy limits) — measure | measure the fraction-width layout on Compose |
| Collapsible transcript — `Button` + `withAnimation(.easeInOut)` + chevron `.rotationEffect` ([:190,199](../app-four/Views/RecordingDetailView.swift#L190)) | ✅ rotationEffect, easeInOut | supported |
| Status pills — `.background(color.opacity(0.15), in: .capsule)` ([:258](../app-four/Views/RecordingDetailView.swift#L258)) | ✅ `Capsule`, fill | — |
| `AudioPlayerView` (last card) | 🟡 platform | **audio playback is P2-C/Phase-1** (Android `MediaPlayer`/`AudioTrack`); the UI slot is shared, the player backing is per-platform — a legitimate seam, not a glyph fallback |
| Toolbar — `ToolbarItem(.principal)` date + `.topBarTrailing` pencil; `.navigationBarTitleDisplayMode(.inline)`; `.toolbarBackground(NewLook.screen)` ([:44-70](../app-four/Views/RecordingDetailView.swift#L44)) | ✅ `toolbar`, `ToolbarItem`, `navigationBarTitleDisplayMode` | verify `.principal` placement + `toolbarBackground` tint on Compose top-app-bar |
| `.confirmationDialog` delete, `.sheet(item:)` edit ([:80,72](../app-four/Views/RecordingDetailView.swift#L80)) | ✅ `confirmationDialog`, `sheet` | — |
| `.medicationBarOverlay()` (floating Paper & Pollen bar) ([:41](../app-four/Views/RecordingDetailView.swift#L41)) | depends on its internals | the med bar fill uses gradients/shape — audit separately; it rides above multiple screens |
| `pendingDelete` + `.onDisappear` delete pattern (memory *feedback-delete-model-pattern*) | 🟡 | the SwiftData-detach reason is iOS-specific; under SkipSQL the constraint differs — keep the deferred-delete UX regardless |

**Divergence from iOS → HTML mockup?** **No structural divergence** — the page ports 1:1 except the glyph rendering (covered globally) and the audio-player backing (a known seam). No mockup needed; the spec-027 layout is already the target. Flag only that the **DESIGN.md recording-detail bullet is stale** — do not "fix" the code toward it.

---

#### Screen 4 — Settings (minimal)

iOS source: [SettingsView.swift](../app-four/Views/SettingsView.swift). DESIGN.md Decisions Log 2026-06-24: Settings deliberately uses **native grouped-`List` chrome** (system section headers/rows/footers) — the most Android-portable screen by design, and it should map to Compose's native list idioms cleanly.

| Construct (repo ref) | SkipUI | Fallback / note |
|---|---|---|
| `List { …sections… }` + `.listStyle(.insetGrouped)` ([SettingsView.swift:48,65](../app-four/Views/SettingsView.swift#L48)) | ✅ `List`, ✅ `.listStyle` | maps to Compose grouped list |
| `.scrollContentBackground(.hidden)` + `.listRowBackground(NewLook.card)` ([:66](../app-four/Views/SettingsView.swift#L66)) | 🟡 verify | reveals `NewLook.screen` under white inset cards; confirm the background override lands on Compose |
| `ScrollViewReader` + `proxy.scrollTo` (top / My-Medication focus) ([:47,81](../app-four/Views/SettingsView.swift#L47)) | 🟡 verify | programmatic scroll for the App-Intent focus — but **App Intents are out of Android v1 scope** ([plan L8](ANDROID_PORT_PLAN.md#L8)); the `router.shouldFocusMyMedication` path can be dropped on Android |
| `.sheet`, `.alert`, `.confirmationDialog` (debug, clear-data) ([:91-100](../app-four/Views/SettingsView.swift#L91)) | ✅ all three | — |
| **`.fileExporter` + `UTType` (encrypted journal export)** ([:102](../app-four/Views/SettingsView.swift#L102)) | 🔴 **`fileExporter` NOT listed** | **Fallback 3 — per-platform**: Android Storage Access Framework (`ACTION_CREATE_DOCUMENT`) via a bridged Kotlin seam. Keep the `JournalArchive` export *format* (versioned, `formatVersion` — plan L7) shared; only the file-picker is per-platform |
| `ICloudSyncSection`, `YourDataSection` (sync 038 UI) ([:60,59](../app-four/Views/SettingsView.swift#L60)) | — | **Cut on Android v1**: sync (038) is OUT of scope ([plan L7](ANDROID_PORT_PLAN.md#L7)). Remove the iCloud section; keep local data controls |
| Med / dose-guard / day-card / accessibility sections | ✅ List rows | standard rows — port as-is |

**Divergence from iOS → HTML mockup?** **Light-yes for the trimmed section set.** Structurally `List` ports natively, but the **section inventory changes** (iCloud sync removed; App-Intent focus removed; file-export re-plumbed). Produce a one-screen **HTML mockup of the Android Settings section list** so the owner signs off on what's cut before code — a content decision, not a layout one.

---

#### Screen 5 — Foreground-service notification (Android-only, mandatory)

Any foreground service this loop runs — the P1-D `microphone` capture FGS, and the STT decode while it completes inside that same FGS window (P2-E §3) — **MUST post a persistent ongoing notification** (small icon + title + text), with the matching `foregroundServiceType` (`FOREGROUND_SERVICE_TYPE_MICROPHONE`) declared in the manifest and passed at `startForeground`, on a pre-created notification channel ([FGS service types](https://developer.android.com/develop/background-work/services/fgs/service-types)). There is **no iOS twin** — this is a new Android-only UI surface P2-D owns. Spec: small icon = the app monochrome mark; title **"Recording…"** / **"Transcribing…"** per phase; one-line body copy per phase; tap target → the check-in hub. Mockup-required (table below); cross-links P2-E §Recovery item 3.

---

### Glyph approach (the P2-D critical path)

**Correction to the inherited premise.** DESIGN.md §60/§183 and P0.3 §3c state the app renders signals with **SF Symbols** (`sparkles`/`bolt.fill`/`target`/`bed`/`pills.fill`) and that a custom-`Shape` port is "open, unstarted." **The repo has moved past that.** Verified in the working tree:

- `SignalGlyph` ([SignalGlyph.swift:30](../Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/SignalGlyph.swift#L30)) routes to five **custom Views**, not `Image(systemName:)`.
- **Four of the five draw with `Canvas`** — `SproutGlyph` ([SproutGlyph.swift:12](../Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/Glyphs/SproutGlyph.swift#L12)), `BoltGlyph` ([BoltGlyph.swift:11](../Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/Glyphs/BoltGlyph.swift#L11)), `ApertureGlyph` ([ApertureGlyph.swift:12](../Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/Glyphs/ApertureGlyph.swift#L12)), `BedIcon` ([BedIcon.swift:9](../Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/Glyphs/BedIcon.swift#L9)) — each using `GraphicsContext.fill/stroke/scaleBy/translateBy` and level-encoded geometry.
- Only `CapsuleGlyph` is `Canvas`-free (`GeometryReader`+`ZStack`+`Capsule`+`Rectangle`, [CapsuleGlyph.swift:8](../Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/Glyphs/CapsuleGlyph.swift#L8)).

**`Canvas` is NOT in the SkipUI matrix** (verified 2026-07-22, [skip-ui README](https://raw.githubusercontent.com/skiptools/skip-ui/main/README.md); *"anything not listed is likely not supported"*). **So the four signal glyphs do not port as-is** — this is the single largest fidelity risk in P2-D, and it is *worse* than P0.3's framing (which assumed an easy `Image(systemName:)` + bundled-vector path). The bundled-vector path is **not free**, because the code is no longer emitting `Image(systemName:)` for signals.

**Decision matrix for the port (choose per glyph, cheapest acceptable first):**

| Option | Mechanism | Cost | Keeps level morphing? | Verdict |
|---|---|---|---|---|
| **A — `Canvas` → `Shape`/`Path` composition** | Rewrite each glyph's `GraphicsContext` drawing as composed `Path`/`Shape` fills + strokes (fill ✅, stroke ✅ per matrix; these glyphs are **decorative**, so the `.stroke`-gesture-hit-mask caveat does not bite). Level stays a parameter of `path(in:)`. | Medium — one rewrite per glyph, **shared** (the iOS app can adopt the same `Shape` glyphs, retiring `Canvas` on both platforms — a net simplification, not a fork) | **Yes** | **Recommended.** Turns a blocker into a shared-core upgrade; the `Shape` mechanism is exactly what P0.3's lightning-`Shape` spike proves |
| **B — Per-level static vector assets** | Export 5 levels × 3 self-state glyphs (+ bed/capsule) to SVG/vector-drawable, select by level. | Low build, high asset count (17+ assets); **loses live morphing**; two sources of truth (drawing + assets drift) | No (discrete) | Acceptable only for the **fixed** glyphs (sleep/medication) if A is deferred |
| **C — `Image(systemName:)` + bundled SF vectors** | Revert signals to SF Symbols and bundle same-named vectors ([skip-ui README §Symbols](https://github.com/skiptools/skip-ui#symbols)). | Requires **undoing the shipped custom-glyph design** — an owner-level product regression, not a port tactic | No | **Rejected** unless the owner re-opens the glyph identity |

**Plan of record:** adopt **Option A** — port the four `Canvas` glyphs to composed `Shape`s in `SquirlDesignSystem`, verified on Android under Fuse, and let iOS inherit the same `Shape`s (removing `Canvas` app-wide). `CapsuleGlyph` and the `EmptySignalGlyph` dashed `Circle().strokeBorder` ([SignalGlyph.swift:70](../Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/SignalGlyph.swift#L70)) already avoid `Canvas` and should port directly. **Live level-to-level *animated* morph** (custom `Animatable`/`Transition`) stays 🔴 unsupported on Android — but the glyphs today morph by *discrete level*, not animated transition, so nothing is lost.

**Because Option A is a shape-geometry rewrite that touches the design system, gate it behind an HTML/side-by-side visual mockup per glyph** (aperture is the stress case — concentric dashed rings; lightning/sprout are the common cases), signed against the P0.3 §4 pre-committed bar before the SwiftUI lands.

**Typography (F3).** Default **Roboto**; map the `Typography` weight ladder (SF semibold headings → Roboto Medium/Bold). Escalate to bundled **Inter** only on a failed owner-signed side-by-side of the check-in screen. Native platform font preserves Android font-scale ↔ iOS Dynamic Type.

---

### HTML-mockup-first rule (per divergent screen)

Per project rule (CLAUDE.md §Process; DESIGN.md HTML-before-SwiftUI): **mockup only where the Android layout/implementation diverges from iOS.** Applied:

| Screen | Diverges? | Mockup required before SwiftUI? |
|---|---|---|
| Check-in flow | No (1:1 port; only empirical crescent/shadow QA) | **No** |
| Calendar + day card | Yes — LazyVStack-only-child restructuring + `FlowLayout` chip reflow | **Yes** — reflowed summary + pinned-header container, proving the visual is unchanged |
| Recording detail (027) | No (structural 1:1; glyph + audio seams are global) | **No** (flag: DESIGN.md bullet is stale, build to code) |
| Settings | Yes — section inventory changes (iCloud/App-Intent cut, file-export re-plumbed) | **Yes** — trimmed Android section list for owner sign-off |
| FGS notification (Android-only) | Yes — no iOS equivalent | **Yes** — icon + Recording…/Transcribing… copy + tap target (Screen 5) |
| Provisioning states (Android-only) | Yes — no iOS equivalent: P2-B first-run "Preparing transcription…" + insufficient-storage/provisioning-failed → retry | **Yes** — copy + placement (check-in hub, first entry) |
| Signal glyphs (cross-screen) | Yes — `Canvas` → `Shape` rewrite | **Yes** — per-glyph side-by-side against the P0.3 pre-committed bar |

---

### Exit criteria (binary, per screen)

A screen is **green** iff all its rows hold on a **physical arm64 Android device** (emulator for the build loop only — shadow, gradient banding, font rasterization, dark mode do not transfer from x86, per [§P0.3.7](ANDROID_PHASE0.md#L841)):

- **E1 Check-in** — idle/recording/saved all navigable from shared source; Speak→record→Stop→Saved round-trips and persists a row via the F1 backing; crescent breathe+spin render (or Reduce-Motion static); **0 rows fall to Fallback 3**.
- **E2 Calendar+day card** — week↔month collapse works via `DragGesture`; day cards fold/expand; summary chips reflow without `FlowLayout`; the tint bands + chip glyphs match iOS side-by-side within the pre-committed bar; **container respects the LazyVStack-only-child rule**; ≤1 row at Fallback 3.
- **E3 Recording detail (027)** — full page scrolls; hero strip renders all present signals at 30 pt with level distinction; transcript collapses; delete-confirm + edit-sheet work; audio slot present (player backing may be the per-platform seam, not counted as erosion); ≤1 row at Fallback 3.
- **E4 Settings** — grouped `List` renders with `NewLook.card` rows on `NewLook.screen`; in-scope sections present, out-of-scope (iCloud/App-Intent) cut per the signed mockup; file-export either works via the SAF seam or is explicitly deferred; **0 glyph/layout rows at Fallback 3**.
- **E5 Glyph (cross-cutting gate)** — all five `SignalGlyph` kinds render on Android via the Option-A `Shape` port (or an owner-approved static-asset fallback for the fixed glyphs), recognizably identical at 24–30 pt, level distinction intact in grayscale.
- **E6 Aggregate erosion cap** — mirroring [§P0.3.7 rule 2b](ANDROID_PHASE0.md#L843): **across all four screens, ≤ N elements may land on Fallback 3 (per-platform Compose), N fixed with the owner at G0 *before* screen 1 lands** (the per-screen caps above sum to ≤2 — a cap set after the fact is not a gate). Exceeding it scores P2-D **red-for-rescope** — "death by a thousand non-blocking fallbacks" is not a pass; it means the Fuse shared-UI premise isn't holding on the core loop.

---

### Risks & effort

**Effort (indicative, solo dev + agent; gated on G0 green and P2-C STT/persistence landing):** the plan budgets Phase 2 at 4 weeks total across STT (step 5), extractor wiring (step 6), and this UI build-out (step 7) ([plan L35](ANDROID_PORT_PLAN.md#L35)). P2-D's own share, rough:

- **Glyph `Shape` port (Option A)** — 2–3 d (4 glyphs × rewrite + dual-platform verify; the biggest single item, and the P0.3 lightning spike front-loads the mechanism) **+ iOS visual-regression QA across every glyph surface + App-Store resubmission timing at the 1.0 milestone** (the iOS half of the shared rewrite is not free).
- **Check-in flow** — 2 d (highest layout density, but 1:1 port; crescent/shadow QA).
- **Calendar + day card** — 3 d (the two restructurings + chip reflow + collapse interaction are the fiddliest).
- **Recording detail** — 1.5 d (1:1 port; audio seam is P2-C).
- **Settings** — 1 d (native `List`; the work is *removing* scope, not adding).
- **Mockups** (calendar, settings, per-glyph) — 1 d, front-loaded per screen.

**Top risks, in order:**
1. **`Canvas` glyphs (E5).** The core-loop's signature visual language is `Canvas`-drawn and `Canvas` is unsupported — mitigated by the Option-A `Shape` rewrite, which is a shared-core upgrade but is real work and must clear the pre-committed fidelity bar. This is the item most likely to slip.
2. **`FlowLayout` custom `Layout` (E2).** Chip reflow + chip groups (emotions/side-effects/meds) all lean on `FlowLayout` — a single unsupported construct with app-wide reach; needs one shared supported-primitive replacement.
3. **LazyVStack-only-child (E2).** A structural constraint on the calendar container; low-severity fix but touches the owner-locked screen, so mockup-gated.
4. **Shadow ordering + `repeatForever` crescent.** Fidelity-not-function; likely resolvable by modifier reorder / animation tweak; measure, don't pre-fix.
5. **F1 persistence read model.** If SkipSQL won, `@Query`-driven live updates need an observable-store shim; if Room won, the DTO seam doubles the surface. Either way the views are written against a protocol so the blast radius stays at the data layer.

---

### Cross-phase dependencies & assumptions

**Depends on (upstream):**
- **G0 green** — the whole workstream is unscheduled until all four P0 spikes pass ([plan L26](ANDROID_PORT_PLAN.md#L26)); a red **P0.2** parks the port entirely.
- **P0.3 forks resolved** — F1 (SkipSQL vs Room) *decided by owner at G0*, F2/F3 recommendations in hand. P2-D cannot start screen 1's save path until F1 is called.
- **P0.1 toolchain** — Fuse scaffold (`skip.yml` `mode: 'native'`), 16 KB-aligned build, `libc++_shared.so` packaging ([§P0.1](ANDROID_PHASE0.md#L31)).
- **P0.4 extractor** — recording detail renders `NoteExtraction` output (signal hero strip, transcript, `ADHDSummarySection`); the byte-identical extractor (Phase 2 step 6) must be wired before E3 shows real signals.
- **Phase 1** — shared-core SPM split (`SquirlDesignSystem`, DTOs), Android scaffold + CI, persistence schema, and **audio capture** (`AudioRecord`/`MediaCodec`/`MediaMuxer`) ([plan L28-33](ANDROID_PORT_PLAN.md#L28)).
- **P2-C (sibling)** — STT integration (step 5) and the **audio player backing** for recording detail's audio card (the one legitimate per-platform seam on that screen).

**Feeds (downstream):**
- **Phase 3 hardening** — TalkBack/accessibility pass (a11y labels are authored in shared source now, verified later), empty/edge states, thermal/storage guardrails, Play readiness ([plan L41-45](ANDROID_PORT_PLAN.md#L41)).
- **The erosion measurement (E6)** is the empirical input to the plan's "how much stays in the shared core" question — it either validates or challenges the Fuse route post-hoc.

**Assumptions (flag if any breaks):**
- `SquirlDesignSystem` tokens compile under Fuse (or via the P0.3 copy-in) and resolve **sRGB**, so ramps don't diverge on wide-gamut.
- **Gate (owner sign-off required, not an assumption): the Option-A `Shape` glyph rewrite is adopted on iOS too.** The owner must approve the Canvas→`Shape` port *on iOS* **before** P2-D touches `SquirlDesignSystem` — this rewrites the shipping app's signal glyphs app-wide, which the project rule ("don't deviate without explicit approval") forbids doing silently, and it lands against the 1.0-upload milestone. Absent approval, glyphs fork and every glyph surface doubles.
- **Sync (038), widgets/Live Activities, App Intents are out of Android v1** ([plan L7-8](ANDROID_PORT_PLAN.md#L7)) — Settings and any App-Intent-driven navigation are trimmed accordingly; do not port the iCloud UI.
- **Code, not DESIGN.md, is the fidelity target** where they drift (recording-detail bullet is stale; glyphs are custom Views not SF Symbols) — QA against the shipping iOS build, not the design doc.
- Recording-detail deferred-delete UX is kept even though its SwiftData-specific rationale doesn't apply under SkipSQL.

---

## P2-E — Core-loop integration & state

**Provenance.** iOS grounding is `file:line` against the live tree on `feat/038-icloud-sync` (verified 2026-07-22). External claims carry cited URLs. This workstream is the *integration* seam: it owns no new engine (STT = P2-A, extractor = P2-C, persistence = P1-C, UI = P2-D, audio = P1-D, the Swift↔Kotlin bridge = P1-E) — it wires them into one loop that survives process death, mirroring the iOS architecture 1:1. Its cancellation/transcript-marshaling ride **the P2-A bridge contract** (§Concurrency).

### Goal

Wire the full check-in loop end-to-end on Android and make it **crash-durable**:

> record (P1-D `AudioRecord`) → transcribe (P2-A on-device STT) → extract (P2-C shared Swift extractor) → persist (P1-C Room/SkipSQL) → display (P2-D SkipFuseUI).

Concretely, port the iOS three-part write architecture:
1. the **`CheckInViewModel` state machine** (idle → recording → processing → done) that owns capture, save-retry, and background transcription hand-off,
2. the composed **`ProcessingViewModel`** post-transcription pipeline (extract → apply → persist), whose *only* source of truth is the persisted row status, not in-memory state,
3. the **`PendingTranscriptionService`** recovery drain — a serialized actor that re-runs the exact transcribe→extract path for any recording captured before the model was ready, or left unfinished by a kill.

Binary success = a check-in recorded, then the app killed at every stage boundary, always converges to either `completed` or `failed` (never a permanent "Transcribing…"), and no capture is ever lost.

### iOS flow to mirror (repo grounding)

**The live write path.** `CheckInViewModel` (`@Observable @MainActor`, [CheckInViewModel.swift:6-8](../app-four/ViewModels/CheckInViewModel.swift#L6)) owns two state surfaces that are deliberately separate:

- **In-memory UI state** — `var state: RecordingState` ([CheckInViewModel.swift:9](../app-four/ViewModels/CheckInViewModel.swift#L9)), enum `idle | recording | paused | processing | done` ([AppEnums.swift:18-24](../app-four/Models/AppEnums.swift#L18)). This drives the *check-in screen* only and is transient — it is never persisted and does not survive relaunch.
- **Persisted pipeline state** — `Recording.status: RecordingStatus` ([AppEnums.swift:5-15](../app-four/Models/AppEnums.swift#L5)): `recorded | transcribing | pendingTranscription | completed | failed | placeholder`, plus `Recording.summaryStatus: SummaryStatus` (`notGenerated | generating | completed | failed`, [AppEnums.swift:92-97](../app-four/Models/AppEnums.swift#L92)). **This is the single source of truth the rest of the app (day card, detail, library) observes.** `ProcessingViewModel`'s doc comment states it explicitly: "Progress is reflected on the persisted `Recording.summaryStatus` … not on in-memory state" ([ProcessingViewModel.swift:6-7](../app-four/ViewModels/ProcessingViewModel.swift#L6)).

That split is the load-bearing design decision for the whole port: **UI state is throwaway; durability lives entirely in the persisted row.** Process death is survivable precisely because no pipeline progress is held in a ViewModel.

**Stage-by-stage (the exact iOS transitions):**

1. **Record.** `startRecording()` guards re-entry (`state == .idle || .done`, [CheckInViewModel.swift:105](../app-four/ViewModels/CheckInViewModel.swift#L105)), checks disk + mic permission, then `audioService.startRecording()` and `state = .recording` ([:132-134](../app-four/ViewModels/CheckInViewModel.swift#L132)). Crucially it **preloads the STT model off-actor while the user speaks** — `modelPreloadTask = Task.detached(priority: .utility) { try await transcriptionService.loadModel() }` ([:144-150](../app-four/ViewModels/CheckInViewModel.swift#L144)) so the post-stop transcription doesn't pay a cold-load.
2. **Stop → save (never lose a capture).** `stopRecording()` sets `state = .processing`, captures `priorTranscription = transcriptionTask` (the *previous* recording's still-running job), then `audioService.stopRecording()` yields a file URL held in a **retry buffer BEFORE the save**: `pendingSave = PendingSave(fileURL:duration:)` ([:174](../app-four/ViewModels/CheckInViewModel.swift#L174)). `attemptSave()` persists via `storageService.saveRecording` + `store.addRecording`, flips `state = .done`, clears the buffer ([:188-198](../app-four/ViewModels/CheckInViewModel.swift#L188)). On failure it **keeps the buffer and raises `saveFailed`** (state stays `.processing`, inline retry surface stays up) — never a silent reset to idle ([:215-221](../app-four/ViewModels/CheckInViewModel.swift#L215)). `retrySave()` / `discardFailedCapture()` are the two exits ([:224-244](../app-four/ViewModels/CheckInViewModel.swift#L224)).
3. **Model-not-ready fork.** If `aiModelService.localPath(for: .whisper) == nil`, the recording is persisted `status = .pendingTranscription` and transcription is **skipped** — capture stays "Captured.", never `.failed` ([:203-207](../app-four/ViewModels/CheckInViewModel.swift#L203)). The drain service picks it up later.
4. **Background transcription.** Otherwise `transcriptionTask = Task { await priorTranscription?.value; await transcribeInBackground(recording) }` — it **awaits the prior job first** so the single STT engine never runs two inferences at once, and back-to-back check-ins never cancel each other's work ([:209-214](../app-four/ViewModels/CheckInViewModel.swift#L209)). `transcribeInBackground` consumes an `AsyncStream<TranscriptionSegmentDTO>` ([Protocols.swift:73](../app-four/Services/Protocols.swift#L73)) under a **90 s timeout** via `withThrowingTaskGroup` racing a `Task.sleep` ([:299-330](../app-four/ViewModels/CheckInViewModel.swift#L299)); each streamed segment writes `fullTranscriptText` + `status = .transcribing` + `store.save()` ([:308-317](../app-four/ViewModels/CheckInViewModel.swift#L308)). Every segment re-checks `store.recordings.contains(where: id)` because the user can delete the row mid-stream (never mutate a freed `@Model`, [:310](../app-four/ViewModels/CheckInViewModel.swift#L310)).
5. **Extract → persist.** On stream completion: `status = .completed`, then hand to the composed `ProcessingViewModel.processRawTranscription(...)` ([:258-266](../app-four/ViewModels/CheckInViewModel.swift#L258)). `ProcessingViewModel.run` re-fetches the row by `audioFileName`, sets `summaryStatus = .generating` + save, `await summarizationService.summarize(...)`, then `applySummary` + `setMedicationEvents` + save; on throw it sets `summaryStatus = .failed` and surfaces "Tap to retry" (never echoes the raw transcript) ([ProcessingViewModel.swift:49-92](../app-four/ViewModels/ProcessingViewModel.swift#L49)).

**The recovery drain.** `PendingTranscriptionServiceImpl` is an `actor` ([PendingTranscriptionServiceImpl.swift:17](../app-four/Services/PendingTranscriptionServiceImpl.swift#L17)) that drains `.pendingTranscription` rows through the identical transcribe→summarize→apply path. Key properties:
- `drainIfModelReady()` no-ops unless the model is present, and an `isDraining` flag coalesces concurrent/re-entrant calls into one pass — necessary because actor reentrancy at `await` points would otherwise start an overlapping inference ([:37-52](../app-four/Services/PendingTranscriptionServiceImpl.swift#L37)).
- Rows are selected **oldest-first by `createdAt`**, and only the `id` crosses the actor hop — each row is re-resolved on the `@MainActor` at drain time, so a row deleted meanwhile is simply not found ([:54-63](../app-four/Services/PendingTranscriptionServiceImpl.swift#L54)). (The code sorts by `createdAt`; a Kotlin DAO must use `ORDER BY created_at ASC` — an `ORDER BY id` on v4 UUIDs is **not** chronological.)
- It mirrors the streaming write (`.transcribing` while in flight, guard-on-each-segment) then `applyResult` → `.completed` ([:87-134](../app-four/Services/PendingTranscriptionServiceImpl.swift#L87)).
- **Triggered from three lifecycle points** ([SquirlApp.swift:133-137, 169](../app-four/App/SquirlApp.swift#L133)): app launch (`.task`), every foreground (`onChange(of: scenePhase) .active`), and download-completion (after the model lands).

**The orphan sweep (the other half of crash recovery).** `RecordingStore.recoverOrphanedTranscriptions()` runs in `init` ([RecordingStore.swift:14, 25-36](../app-four/Store/RecordingStore.swift#L25)): any row still `.transcribing` at launch **cannot** have a live task (the process died mid-job), so it is swept to `.failed` with a "Transcription was interrupted. Tap to retry" message. It is **scoped to `.transcribing` only** — `.pendingTranscription` is legitimately waiting and must not be swept ([:22-24](../app-four/Store/RecordingStore.swift#L22)). These two mechanisms partition the post-kill recovery space:

| Status at kill | Meaning | Recovery mechanism | Terminal state |
|---|---|---|---|
| `.pendingTranscription` | captured, model wasn't ready | drain service (relaunch/foreground/download-done) | `.completed`/`.failed` |
| `.transcribing` | job was mid-flight, now orphaned | orphan sweep in store `init` | `.failed` (retryable) |
| `.completed` w/ `summaryStatus=.generating` | transcript done, extractor died | — (gap; see Risks) | needs re-drive |
| *(no row; audio file on disk)* | killed between stop and save (`pendingSave` is in-memory) | disk-orphan audio sweep at store init (item 5 below) | adopted as `.pendingTranscription`, or deleted if unreadable |

### The Android core-loop state machine

Two state planes, exactly as iOS. Persist **only** the row status; keep UI state ephemeral.

```
                         CHECK-IN UI STATE (ephemeral, ViewModel-only — NOT persisted)
   ┌────────┐  tap rec   ┌───────────┐  stop / cap-hit   ┌────────────┐  save ok   ┌──────┐
   │  idle  ├───────────►│ recording ├──────────────────►│ processing ├───────────►│ done │
   └───▲────┘            └─────┬─────┘                    └─────┬──────┘            └──┬───┘
       │  cancel/discard       │ cancel                        │ save FAIL            │ (auto→idle
       └───────────────────────┴───────────────────────────────┘ (stay processing,   │  on next start)
                                                                   retry/discard)
────────────────────────────────────────────────────────────────────────────────────────────
                         PERSISTED ROW STATE (Recording.status — the source of truth)

    save ok, model ready                    stream segs           stream done        summarize ok
 ── ──────────────────► [recorded] ──────► [transcribing] ──────► [completed] ─────► summaryStatus:
   \                                            │  │                  │  generating ──► completed
    \ save ok, model NOT ready                  │  │                  │
     └────────────────► [pendingTranscription]  │  │                  └─(fillOnly text check-in skips STT)
                          │   ▲                  │  │
      drain (model lands) │   │ (never swept)    │  └─ timeout(90s) / stream error / cancel-by-next
                          └───┘                  │        │
                          ▼                      ▼        ▼
                     (re-enters transcribe) ── [failed] ◄─┘   ◄── orphan sweep on relaunch
                                                 ▲               (any .transcribing at launch → failed)
                                                 │
                                          summarize throw → summaryStatus=.failed (row stays .completed,
                                                             "tap to retry" in detail)
```

**Transition table (Android, Kotlin/Swift responsibilities):**

| From | Event | Guard | To | Side effects |
|---|---|---|---|---|
| `idle`/`done` | start tapped | disk ok, mic granted, FGS started | `recording` | begin `AudioRecord` (P1-D FGS `microphone`); detached model-preload (P2-A `loadModel`) |
| `idle`/`done` | start tapped | **FGS start denied** (Android 14+ bg-start) or mic denied | `idle` (stay) | surface an explicit "couldn't start recording" error — a failed guard must never no-op silently |
| `recording` | **mic permission revoked mid-record** | — | `processing` | stop capture, buffer the partial file, proceed to save; surface a mic-lost notice (P3 hardens; P2 must not fail silently) |
| `recording` | stop / 8-min cap | — | `processing` | capture prior transcribe job handle; stop `AudioRecord`; buffer file URL **before** save |
| `processing` | save ok, model ready | — | `done` + row `recorded`→`transcribing` | insert row; enqueue transcription awaiting prior job |
| `processing` | save ok, model absent | `localPath==nil` | `done` + row `pendingTranscription` | persist, skip STT (drain later) |
| `processing` | save fail | — | `processing` (stay) | keep buffer, raise `saveFailed`; retry/discard exits |
| row `transcribing` | segment | row still exists | `transcribing` | write `fullTranscriptText` + save |
| row `transcribing` | stream done | row exists | `completed` → extractor | `ProcessingViewModel`-equiv: `generating`→apply→`completed` |
| row `transcribing` | timeout/err/cancel | — | `failed` | cancel STT; retry message |
| row `pendingTranscription` | model lands | drain trigger | `transcribing`→… | drain actor re-runs full path |
| row `transcribing` @ launch | process was killed | — | `failed` | orphan sweep in store init |

**Android mapping of the two planes:**
- **UI state plane** → the shared Swift `CheckInViewModel` compiles natively under Skip Fuse and continues to hold `state: RecordingState`. Under SkipUI this maps to Compose state — **but SkipUI deliberately excludes SwiftUI state from Android `Activity` restoration** (see concurrency/lifecycle below). That is *fine and intended*: UI state is ephemeral on iOS too; a config-change/kill simply lands the user back on the hub with the durable row already persisted.
- **Persisted plane** → P1-C schema. `RecordingStatus`/`SummaryStatus` become Room enum columns (`@TypeConverter` string ↔ enum) or SkipSQL columns. The orphan sweep and oldest-first pending query become the equivalent DAO queries run in the store's init/`@ModelActor`-equivalent.

### Recovery / pending-transcription drain across process death

The invariant to preserve: **every recording converges to a terminal, non-lying status regardless of when the OS kills the process.** Android kills are *more* aggressive than iOS (background process death, low-memory reaping, and — new failure mode — config changes recreating the Activity), so this is the highest-value part of the port, not a nicety.

Port both halves:

1. **Orphan sweep — on store construction (relaunch).** Any row `.transcribing` at cold start had no live task; sweep → `.failed` (retryable). Room/SkipSQL DAO:
   ```kotlin
   // P1-C DAO — mirrors RecordingStore.recoverOrphanedTranscriptions() (RecordingStore.swift:25)
   @Query("UPDATE recording SET status = 'failed', " +
          "fullTranscriptText = CASE WHEN fullTranscriptText = '' " +
          "THEN 'Transcription was interrupted. Tap to retry.' ELSE fullTranscriptText END " +
          "WHERE status = 'transcribing'")
   suspend fun recoverOrphanedTranscriptions(): Int   // run once in store init, off main
   ```
   Scope to `transcribing` ONLY — never touch `pendingTranscription`. **Converter-encoding coupling:** the raw-SQL literals `'failed'`/`'transcribing'` must equal the exact strings the `@TypeConverter` persists, or the sweep silently matches nothing — assert the persisted string form against the literals in a test (or filter via the same converter).

2. **Pending drain — the serialized Swift actor, unchanged.** `PendingTranscriptionServiceImpl` is UI-free Swift; it compiles natively under Fuse and ports **as-is** (SwiftData `store` calls become the Phase-1 `JournalRepository` seam — P1-E's name, not a new "store facade"). The three iOS triggers map to Android lifecycle:
   | iOS trigger ([SquirlApp.swift](../app-four/App/SquirlApp.swift#L133)) | Android equivalent |
   |---|---|
   | launch `.task` | `Application.onCreate` / first composition → `lifecycleScope.launch { drainIfModelReady() }` |
   | `scenePhase == .active` | `ProcessLifecycleOwner … Lifecycle.State.RESUMED` (`ON_START`) observer |
   | download-complete | STT model asset-pack install callback (P2-A) → drain |

   Keep the `isDraining` coalescing flag and oldest-first-by-`createdAt` selection verbatim ([PendingTranscriptionServiceImpl.swift:39-63](../app-four/Services/PendingTranscriptionServiceImpl.swift#L39)) — Android fires all three triggers close together on a cold resume, so coalescing is *more* necessary here.

   Android adds a **fourth drain trigger — resource recovered**: P3-A's thermal governor defers work (its `TranscriptionOutcome.Deferred` / `DEFERRED_THERMAL`) and must re-drain when thermal status drops back to ≤ LIGHT (or storage is freed). Thermally-deferred rows **reuse `.pendingTranscription`** — already excluded from the `.transcribing`-only orphan sweep, so a deferred row is never mis-swept to `.failed`; P3-A's `DEFERRED_THERMAL` outcome maps onto this partition without a new status column. Note the sherpa-branch consequence from Rule 7: thermal defer there means *finish (or unload) the in-flight utterance, defer the rest of the queue* — never a mid-utterance abort.

3. **Long-STT continuation across background (ties to P1-D FGS + P2-A).** iOS transcription runs in a detached `Task` while the app is foreground/backgrounded briefly; the 90 s timeout bounds it. Android will suspend/kill a backgrounded process far sooner. Decision for v1: **transcription completes inside the existing P1-D `microphone` FGS window**, bounded by the 90 s timeout — the decode is kicked off before the service stops and finishes within its lifetime (RTF ≤ 1.0 per the P0.2 gate makes this arithmetic hold). We do **not** start a second decode-only FGS (Android 14+ forbids FGS start from the background exactly when the app may be backgrounded) and do **not** promote to `shortService` (~3 min, non-extendable). A decode continued under a `microphone`-typed FGS *after the mic is released* is a policy risk we avoid by keeping the decode inside the live capture window. If the FGS is nonetheless killed mid-job, the row is `.transcribing` and the **orphan sweep catches it on relaunch** — so background-kill degrades to "retry", never to data loss. FGS type + background-start rules per [FGS service types](https://developer.android.com/develop/background-work/services/fgs/service-types) (Android 14+ needs the declared type + granted `RECORD_AUDIO`, cannot start from background).

4. **Close the extractor-orphan gap that iOS leaves.** iOS has no sweep for a row that reached `.completed` but died with `summaryStatus == .generating` (extractor crashed/killed). On iOS this is rare (extraction is fast, on-device NL). On Android, make the drain also pick up `status == .completed && summaryStatus == .generating` and re-run *only* the extract step (the transcript is already persisted). Cheap, closes the one hole in the state partition.

5. **Disk-orphan audio sweep — on store construction.** `pendingSave` is in-memory only; a kill in the stop→`attemptSave` window leaves the audio file on disk with **no owning row** — recoverable by neither the `.transcribing`-only orphan sweep nor the `.pendingTranscription`-only drain. At store init, enumerate the capture directory for files with no owning row and **insert a `.pendingTranscription` row for each** (or delete the file if unreadable/zero-length). This is what makes the "no capture is ever lost" goal literally true across the stop→save kill window.

### Concurrency model across the bridge

**iOS today:** end-to-end Swift Concurrency — `@MainActor` ViewModels (`CheckInViewModel`, `ProcessingViewModel`), an `actor` for the drain, `async/await` throughout, `AsyncStream` for transcript segments, structured `withThrowingTaskGroup` for the timeout race, `Task.detached(.utility)` for model preload. All `@Model` mutation happens on `@MainActor` (SwiftData `ModelContext` is main-actor-bound here).

**Under Skip Fuse the shared Swift core runs *natively* on Android** (not transpiled) on the official Swift 6.3 Android SDK — so `async/await`, actors, `@MainActor`, `AsyncStream`, and `TaskGroup` **execute as real Swift concurrency on Android**, not as Kotlin translations ([skip.dev modes doc](https://skip.dev/docs/modes/); `skip.yml` must set Fuse mode explicitly — it defaults to transpiled). This is the single biggest reason the loop ports cheaply: the entire state machine above is *the same Swift code*. The bridge work is confined to the edges:

- **Swift `@MainActor` ↔ Android main thread.** Swift's main executor must be pinned to the Android main `Looper` so `@MainActor` hops land on the UI thread that owns Compose/Room-main-access. This is Skip Fuse runtime behavior (SkipFuseUI drives it); the persisted-state writes that iOS does on `@MainActor` land on the Android main thread — keep DB writes *off* it by routing the P1-C store's actual SQL through a background dispatcher inside the `JournalRepository` implementation (Room `suspend` DAO on `Dispatchers.IO`), while the Swift-visible API stays `@MainActor async`.
- **STT engine boundary (P1-E / P2-A JNI).** The STT engine (whisper.cpp / sherpa-onnx) is C/C++ behind JNI, not Swift. The Swift `TranscriptionService.transcribe` → `AsyncStream<TranscriptionSegmentDTO>` contract ([Protocols.swift:73](../app-four/Services/Protocols.swift#L73)) is preserved: the P1-E bridge wraps the native engine's segment callbacks (marshaled per **P2-A's audited JNI contract** — UTF-8 `jbyteArray`, mutex-guarded context) and **yields them into the same `AsyncStream`** the Swift loop already consumes. So `transcribeInBackground`'s `for await segment in stream` ([CheckInViewModel.swift:309](../app-four/ViewModels/CheckInViewModel.swift#L309)) is unchanged; only the stream's *producer* is new. Transcript bytes cross the JNI boundary as a **UTF-8 `jbyteArray`** decoded Swift-side, never `NewStringUTF` (Modified-UTF-8 corrupts emoji/non-Latin — per [ANDROID_PHASE0.md §3.6a](ANDROID_PHASE0.md) and [ANDROID_PORT_PLAN.md §Phase 2 step 5](ANDROID_PORT_PLAN.md)).
- **Cancellation across the bridge.** iOS `transcriptionService.cancelTranscription()` ([CheckInViewModel.swift:493](../app-four/ViewModels/CheckInViewModel.swift#L493)) and `Task.cancel()` must reach the native engine. The bridge exposes a cancel entry that flips the engine's abort flag; Swift `Task` cancellation is cooperative, so the `AsyncStream` producer must check the abort flag between segments and finish the stream. Mirror the mutex-guarded context handle from the P2-A JNI standard ([ANDROID_PORT_PLAN.md §Phase 2 step 5](ANDROID_PORT_PLAN.md)).
- **Kotlin coroutines only at the Compose/lifecycle rim.** The only Kotlin-native async is the lifecycle glue (drain triggers, FGS): `lifecycleScope.launch { }` calling into the Swift `async` drain via the Fuse bridge. Everything below the ViewModel API is Swift.

**Activity restoration (the one genuinely new lifecycle rule).** SkipUI states: *"SwiftUI relies on its own mechanisms to save and restore Activity UI state, such as @AppStorage and navigation path bindings. It is not compatible with Android's Activity UI state restoration."* — [skiptools/skip-ui README](https://github.com/skiptools/skip-ui). SkipUI's remedy is to wrap SwiftUI content in `rememberSaveableStateHolder().SaveableStateProvider(key)` and remove the state after composition via a `SideEffect`, so SwiftUI is **excluded** from Android's `savedInstanceState`/process-death restoration. Consequence for this workstream: **do not attempt to restore the ephemeral `CheckInViewModel.state` across an Activity recreation** — it isn't restorable and doesn't need to be. All durability is in the persisted row; a config-change or kill lands the user on the hub (`idle`) with the correct row status already on disk and the drain/orphan-sweep reconciling any in-flight job. Any nav-path or `@AppStorage`-style persistence Squirl relies on must be re-expressed through Compose-saveable or the DB, not assumed to survive via SwiftUI's mechanism ([README](https://github.com/skiptools/skip-ui); [Compose state-saving](https://developer.android.com/develop/ui/compose/state-saving)).

### Exit criteria (binary)

Loop is **green** only if ALL hold on a real API 28+ mid-tier device:

1. **Happy path.** A voice check-in records → transcribes → extracts → persists → renders in day card + detail, row ending `status=.completed` / `summaryStatus=.completed`. Text check-in (`fillOnly`, skips STT) lands `.completed` via the extractor path.
2. **Kill mid-transcription → orphan sweep.** Force-kill the app while a row is `.transcribing`; on relaunch the row is `.failed` with the interrupted-retry message, detail offers retry, and no row is stuck on "Transcribing…".
3. **Capture-before-model → drain.** With the STT model absent, a capture persists `.pendingTranscription` (UI shows "Captured.", not failed); after the model asset-pack installs, the drain (on relaunch OR foreground OR install-callback) transcribes+extracts it to `.completed`, oldest-first, with no double-inference.
4. **Save failure is recoverable.** Inject a save error; the buffered audio is retained, `saveFailed` surfaces, `retrySave()` completes without re-recording, `discardFailedCapture()` cleanly returns to idle and deletes the file.
5. **Back-to-back check-ins serialize.** Two recordings stopped in quick succession both reach `.completed`; the second's transcription awaits the first (single engine, no cancel of the first's work) — mirrors [CheckInViewModel.swift:209-214](../app-four/ViewModels/CheckInViewModel.swift#L209).
6. **Timeout bound.** A transcription exceeding the 90 s bound lands `.failed` (timeout message), not a hung UI.
7. **Config-change safety.** Rotating / backgrounding mid-record does not corrupt the persisted row; the loop still converges (state-restoration exclusion verified not to lose data).
8. **No main-thread DB stalls.** Transcript-segment saves and drains do not block the Android main thread (no ANR under a long check-in).
9. **Parity.** The golden-fixture extractor output for a fixed transcript is byte-identical to iOS (inherited from P0.4/P2-C, asserted at the integration seam).
10. **Kill between stop and save → no lost audio.** Force-kill in the stop→`attemptSave` window; on relaunch the disk-orphan sweep adopts the file into a `.pendingTranscription` row and the drain converges it to `.completed`.

### Risks & effort

| Risk | Impact | Mitigation |
|---|---|---|
| **`@MainActor`↔main-`Looper` pinning + DB-on-main.** If Fuse routes `@MainActor` writes to the UI thread and the store does SQL synchronously, long check-ins ANR. | Jank / ANR / Play vitals hit. | Keep Swift API `@MainActor async` but push actual SQL to `Dispatchers.IO` inside the P1-C facade (Room `suspend` DAO). Verify no main-thread I/O with StrictMode. |
| **Android kills earlier than iOS.** Background/low-mem death mid-STT is common, not exceptional. | Rows stranded if recovery incomplete. | Three-mechanism recovery (orphan sweep + drain + disk-orphan audio sweep) already covers it; run STT inside the P1-D FGS to extend runway; the `completed+generating` gap fix closes the last hole. |
| **Activity-restoration mismatch.** Assuming SwiftUI state survives recreation → lost check-in-in-progress or nav glitches. | Confusing UX; possible perceived data loss. | Treat UI state as ephemeral by design; `rememberSaveableStateHolder` exclusion per SkipUI; durability only in the row. Test rotation/background explicitly (exit #7). |
| **Cancellation not reaching native engine.** Swift `Task.cancel()` is cooperative; a C engine won't stop unless the bridge signals it. | Wasted battery, double-inference, stuck stream. | P2-A cancel entry flips engine abort flag; `AsyncStream` producer checks it between segments and finishes; mutex-guarded handle (JNI standard). |
| **Drain re-entrancy under 3 near-simultaneous Android triggers.** launch+resume+install-callback fire together on cold resume. | Overlapping inference on the single engine. | Keep `isDraining` coalescing verbatim ([:39-41](../app-four/Services/PendingTranscriptionServiceImpl.swift#L39)); it is *more* load-bearing on Android. |
| **Fuse concurrency-runtime maturity.** Real Swift `TaskGroup`/actor/`AsyncStream` on the no-platform-owner Android toolchain (Phase 0 §6). | Subtle scheduler bugs, self-support only. | Pin toolchain (P0.1); add an integration smoke that runs the timeout `TaskGroup` race + actor drain on-device in CI. |
| **FGS-type compliance for the decode.** A decode-only FGS started from background, or decode continued under a `microphone` FGS after mic release, risks Play policy / Android-14 restrictions. | Play rejection or runtime `ForegroundServiceStartNotAllowedException`. | Keep the decode inside the live mic-FGS window (90 s bound); never start a decode-only FGS from background; if killed anyway, the row degrades to the orphan-sweep retry path. |

**Effort: ~5–7 engineer-days** (assumes P1-C store, P1-D audio/FGS, P1-E bridge, P2-A STT, P2-C extractor, P2-D UI all landed):
- 1.5 d — port `CheckInViewModel` + `ProcessingViewModel` state machine onto the P1-C/P2-A/P2-C facades (mostly wiring; the Swift ports natively).
- 1 d — orphan sweep DAO + drain lifecycle triggers (3 Android hooks) + `completed+generating` gap fix.
- 1 d — `@MainActor`/main-thread + DB-off-main dispatcher plumbing; StrictMode verification.
- 1 d — cancellation + timeout across the JNI bridge (with P1-E/P2-A).
- 1–1.5 d — the 9 exit-criteria device tests incl. kill-at-every-boundary matrix.
- Slip driver: Fuse concurrency/main-thread surprises → budget +1 d.

### Cross-phase dependencies & assumptions

**Hard dependencies (this workstream cannot start until these land):**
- **P1-C Persistence (Room/SkipSQL).** Provides `Recording` row + `status`/`summaryStatus` enum columns, `addRecording`/`save`/oldest-first-pending query/orphan-sweep DAO. The persisted plane *is* the source of truth — no P1-C, no durability. Persistence fork (Room vs SkipSQL) is decided at **P0.3**; either works, the `JournalRepository` API (P1-E) is identical.
- **P1-D Audio capture + FGS.** Provides the record stage and the foreground service whose lifetime this workstream extends to cover long STT. FGS type `microphone` + Android-14 background-start rules ([FGS types](https://developer.android.com/develop/background-work/services/fgs/service-types)).
- **P1-E Swift↔Kotlin bridge seam.** The JNI/Fuse interop this workstream's cancellation, transcript-`jbyteArray`, and lifecycle-drain triggers ride on.
- **P2-A STT integration.** Provides `TranscriptionService.transcribe → AsyncStream<segment>` + `loadModel`/`cancelTranscription`/`localPath`, and the model asset-pack install callback that fires the drain.
- **P2-C Extractor wired.** Provides `summarizationService.summarize` (native shared Swift). The `ProcessingViewModel` half is a no-op shell without it.
- **P2-D UI build-out.** Consumes the ephemeral `state` + the persisted row status to render check-in/day-card/detail. Owns the `rememberSaveableStateHolder` integration at the SkipFuseUI boundary.

**Depends-on gate:** all of **Phase 0** (G0). Specifically P0.2 (STT viable at RTF ≤ 1.0 — a red there parks the port and voids this workstream) and P0.3 (Fuse UI + persistence fork).

**Assumptions (flag if false):**
- **Skip Fuse runs the shared core natively**, so Swift concurrency (actors/`@MainActor`/`AsyncStream`/`TaskGroup`) executes as real Swift on Android — the entire state machine ports as-is, not re-authored in Kotlin ([skip.dev modes](https://skip.dev/docs/modes/)). *If Fuse's concurrency runtime proves unstable on the no-owner Android toolchain, the drain actor + timeout `TaskGroup` are the first things to break — mitigated by the on-device CI smoke.*
- **UI state is ephemeral and need not survive Activity recreation** — true on iOS (never persisted) and enforced by SkipUI's state-restoration exclusion. All recovery rides the persisted row.
- **The single-engine serialization constraint holds on Android** (whisper.cpp/sherpa-onnx context is not concurrently re-entrant) — the `await priorTranscription?.value` chaining and drain `isDraining` flag both assume it. True for the P0.2 candidate engines.
- **Transcript crosses JNI as UTF-8 `jbyteArray`**, never `NewStringUTF` — carried from the P2-A JNI standard, non-negotiable for non-Latin/emoji correctness.
- **Sync (038), widgets, App Intents are OUT** ([ANDROID_PORT_PLAN.md scope rulings](ANDROID_PORT_PLAN.md)) — this loop is standalone/local-only; the only hedge is the versioned `JournalArchive` export format, which this workstream does not touch.
- **iOS parity is the acceptance bar**, not iOS-behavior-plus-improvements — the one deliberate addition (the `completed+generating` extractor-orphan sweep) is additive and safe; everything else mirrors the cited iOS transitions 1:1.

---

## Consolidated risks & sequencing

**Intra-phase run order.** The five workstreams are not independent — the native seam gates the loop:

1. **P2-A (STT JNI) + P2-B (model delivery) go first.** They are the two halves of one native seam: P2-A defines the **single bridge contract** (jbyteArray / mutex-guarded context / direct ByteBuffer / thrown errors / unload-before-finish) and owns the handle lifecycle + transcript marshaling; **P2-B supplies the model path/fd and drives that bridge's unload.** Both inherit the P0.1 16 KB gate wholesale. Nothing downstream can call a real engine until this pair lands. **Their exit criteria are jointly verified** — P2-A's parity/unload/alignment gates require P2-B's delivered model; neither workstream greens alone.
2. **P2-C (extractor wiring) gates on P2-A/P2-B** — it needs a callable engine *and the winner's identity* (the normalizer is tuned to the winning engine's output distribution) — plus the P0.4 fences landed in Phase 1.
3. **P2-D (UI) runs in parallel** with P2-A/P2-B/P2-C — it depends on the P0.3 forks + Phase 1 scaffold/tokens, **not** on the STT seam, with two exceptions on the recording-detail screen only: real-signal render needs P2-C wired, and the audio-player backing is a per-platform seam owned with P2-C/Phase 1.
4. **P2-E (integration & state) is the capstone** — it wires all of the above into the crash-durable loop and cannot start until P1-C/D/E + P2-A/C/D have landed.

Practical sequence: **P2-A + P2-B (native seam) → P2-C ∥ P2-D behind them → P2-E converges everything.**

**Phase-1 outputs P2 hard-depends on — verify before scheduling (not mid-workstream):**
- `SquirlDesignSystem` tokens' compile result under Fuse (or the copy-in workaround decision) — gates P2-D.
- The PCM sample format actually delivered by P1-D (float `[-1,1]` `FloatArray`, per its commitment) — gates P2-A.
- The Android CI job's existence (Phase 1 step 2) — gates P2-C's build-gating fixture suites.

**⚠ The glyph supersession (carry into execution).** P0.3's premise — signal glyphs are **SF Symbols** with an easy `Image(systemName:)` + bundled-vector Android path — is **superseded by P2-D's grounded finding**: four of the five signal glyphs are drawn with SwiftUI `Canvas`, which SkipUI does **not** support. This is presented as the truth in P2-D (⚠ callout) and is the single largest UI-fidelity risk in the phase; it is real rewrite work, not a bundling task. **Plan of record: port the four `Canvas` glyphs to composed `Shape`s in `SquirlDesignSystem` and adopt them on iOS too** (Option A) — a shared-core upgrade, not a fork. **This is gated on explicit owner sign-off before the shared rewrite lands** (it changes the shipping iOS app's glyphs app-wide at the 1.0-upload milestone and carries iOS visual-regression QA + resubmission timing). If the owner insists iOS keeps `Canvas`, glyphs fork and every glyph surface doubles.

**Top cross-phase risks (highest severity first):**

1. **P0.2 is still unresolved and terminal.** None of P2-A…P2-E exists if P0.2 is a no-go — a red there parks the whole port ([ANDROID_PHASE0.md §P0.2](ANDROID_PHASE0.md#L414)). Everything in this document is conditional on the STT gate passing on a real mid-tier device.
2. **Audited-standard deviations forced by the STT winner (P2-A).** The plan's audited jbyteArray/thread JNI standard is fully enforceable **only on branch (a) whisper.cpp** (we own the C). If the winner is **sherpa** (branch b/c), its official AAR internally returns the result as a Java `String` via **`NewStringUTF`** (a rule-1 deviation we cannot fix without building sherpa from source; near-zero exposure for speech, **recorded as accepted**), and it **defaults `numThreads = 1`** (a rule-5 deviation we must **deliberately override** to the P0.2-swept thread count, or RTF fails the gate). Both are owner-acknowledgeable gaps between the plan's standard and the AAR reality, not defects.
3. **QNN 16 KB blob wall (P2-A branch c).** Candidate (c)'s Qualcomm `libQnn*.so` are **prebuilt binary blobs we cannot relink**; if any ships 4 KB-aligned, (c) is **blocked at Play upload** pending a QNN-SDK version that ships 16 KB blobs — un-mitigable by us. Verify with `check_elf_alignment.sh` *before* betting on (c). **Decision rule at G0: P0.2 is green only if the winning engine also clears the 16 KB blob-alignment check — a (c)-win with 4 KB QNN blobs is a no-go, not a pass.** Run the blob check *inside* the P0.2/G0 gate, not at P2-A integration.
4. **Normalizer is the one un-parity-guaranteed component (P2-C).** New Android-only code with no iOS twin to diff byte-for-byte; over-normalizing injects divergence, under-normalizing leaves the Day-4 style gap. Its own fixture gate + a G0-frozen tolerance are the only guards.
5. **Fuse concurrency-runtime maturity on the no-owner Android toolchain (P2-E).** The loop ports cheaply *because* Swift actors / `TaskGroup` / `AsyncStream` run natively on Android — but that toolchain is community-stewarded with no platform owner (Phase 0 §6), so scheduler bugs are self-support. Pin the toolchain (P0.1); add an on-device CI smoke that exercises the timeout `TaskGroup` race + actor drain.
6. **Persistence fork still open (P0.3).** SkipSQL vs Room changes P2-C's DTO seam and P2-D's read model. Both are written against a persistence *protocol*, so the blast radius stays at the data layer whichever way the owner calls it at G0.
7. **Aggregate UI erosion (P2-D E6).** "Death by a thousand non-blocking Fallback-3 (per-platform Compose) elements" scores P2-D **red-for-rescope** — the shared-UI premise failing quietly on the core loop.

**Total effort.** Summing the workstream budgets honestly (eng-days):

| Workstream | Eng-days | Note |
|---|---|---|
| P2-A STT JNI | **2–7** | branch-dependent: ~3–4 whisper.cpp (a) / ~2 sherpa-Parakeet (b) / (b)+3–4 QNN (c); +1–2 if sherpa built from source for alignment |
| P2-B Model delivery | **2–3** | +1–2 only if Strategy 2 (mmap-in-place) is pursued |
| P2-C Extractor wiring | **6–9** | normalizer (~3–5) dominates; DTO/Room seam ~2–3; CI wiring ~1 |
| P2-D UI build-out | **10–12** | glyph `Shape` port 2–3, check-in 2, calendar 3, detail 1.5, settings 1, mockups 1 |
| P2-E Integration & state | **5–7** | +1 slip driver for Fuse concurrency/main-thread surprises |
| **Total** | **~25–38 eng-days** (≈31 midpoint) | |
| *Toolchain contingency* | *+15–25% phase-wide* | the phase runs on a self-support, no-platform-owner toolchain (risk 5); this rework buffer is distinct from the wall-clock caveat below |

**Wall-clock vs labor sum.** The plan budgets Phase 2 at **4 weeks (≈20 working days)** ([ANDROID_PORT_PLAN.md](ANDROID_PORT_PLAN.md)). The summed labor (~25–38 eng-days) **exceeds a single engineer's 4-week wall-clock by roughly 25–90%.** The 4 weeks is therefore only achievable as a *parallel-execution* wall-clock — the **P2-A + P2-B / P2-C ∥ P2-D** overlap above plus agent assistance — **not** as the labor sum. For a lone engineer with no parallelism, budget **~6–8 weeks** and treat "4 weeks" as the compressed-with-parallelism target, flagging the slip risk honestly. Gated on **G0 + Phase 1**; a red P0.2 voids the phase entirely.
