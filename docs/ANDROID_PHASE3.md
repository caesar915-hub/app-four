<!-- Created: 2026-07-22 01:35 WEST · Updated: 2026-07-22 11:00 WEST -->
# Android Port — Phase 3 (Hardening → closed beta) → builds on Phase 2

**Scope.** This document expands the **Hardening → closed beta** phase (Phase 3) of [ANDROID_PORT_PLAN.md](ANDROID_PORT_PLAN.md) (v1.1) into five execution-ready workstream specs, across a **3-week** window: resilience & edge states (P3-A), accessibility (P3-B), test strategy (P3-C), Play compliance & readiness (P3-D), and release engineering & closed-beta ops (P3-E). Phase 3 **builds on Phase 2 and is conditional on Phase 2 being complete** — nothing here ships until the core loop (record → transcribe → extract → journal → calendar → detail → settings) runs on a real device. Its job is to turn that working build into a **signed, policy-compliant AAB on a Google Play closed-testing track** in front of ≥12 real testers, with a triage loop and a defensible path toward production. Everything upstream (toolchain, STT go/no-go, Skip Fuse UI, extractor parity) is assumed resolved at **G0** ([ANDROID_PHASE0.md](ANDROID_PHASE0.md)); Phase 1/2 assumed built.

**Provenance.** Each of the five workstreams was drafted by a dedicated **Opus/MAX** engineer-agent, grounded to the project sourcing standard — external claims carry an inline cited URL (verified **2026-07-22**); repo claims carry `file:line`. This document is the **assembled** result of those five sections, stitched into the [ANDROID_PHASE0.md](ANDROID_PHASE0.md) house style with cross-workstream reconciliations applied: the closed-testing **policy (P3-D) vs ops (P3-E)** split, the **thermal-guardrail → Phase-2 STT-bridge** dependency, the corrected **`onTrimMemory`** Android-14/15 delivery model, and the **SkipUI accessibility gaps** carried into Consolidated. It was then **independently reviewed by three Opus/MAX adversarial agents** (Lens A accuracy — verified all 11 policy/date/technical claims live and correct, incl. Vitals crash 1.09%/ANR 0.47% thresholds, the 12-tester/14-day gate, targetSdk 36; Lens B executability/gate-rigor; Lens C repo-grounding/cross-phase), and the **load-bearing findings were merged in**: the invented 30th `Recording` field was removed (it broke Phase 1's 29-field DTO guard) in favour of the existing `status: RecordingStatus`/`.pendingTranscription`; the tester count was corrected to the **≥12 floor**; and the thermal-guardrail dependency on the Phase-2 STT abort seam is stated explicitly. **Round 2 (2026-07-22):** three further Opus adversarial reviewers (round-1 leftovers, cross-doc consistency vs Phases 1–2, source verification) plus a Fable merger applied the outstanding items — including the previously catalogued deterministic thermal injection and the `RUNNING_CRITICAL` exit-test fix — reconciled the STT abort seam to P2-A's `transcribe(pcm16kMono:)` + push-style `cancel()` contract and glyph a11y to P2-D Option A (shared `Shape` glyphs), and hardened four citations; only low-severity Lens-B staffing/gate-tone notes remain catalogued in the review files.

---

## Workstreams at a glance

| Workstream | Owns | Eng-budget | Binary exit criterion | Depends on |
|---|---|---|---|---|
| **P3-A — Resilience & edge states** | 10-row error-surface catalog, the **net-new** thermal guardrail (abort + preserve audio), storage/memory-pressure gates, `onTrimMemory` model-unload, six empty/edge states | **~5 d** (1 eng-week) | Audio-durability property test 100% green; thermal abort verified on-device with zero recordings lost; disk-full/`onTrimMemory` handled; all 10 surfaces + 6 empty states wired | Phase 1 §4 audio pipeline, **Phase 2 STT bridge (`cancel()`/`isDecoding`/`unloadModel`)**, P2-E recovery drain, P0.3 persistence fork |
| **P3-B — Accessibility** | TalkBack / Dynamic Type / AA-contrast / Reduce-Motion parity with iOS, through the SkipFuseUI → SkipUI mapping; per-screen `ComposeView` fallbacks for the SkipUI gaps | **~4–5 d** (up to 7 if grouping fallbacks balloon) | A blind TalkBack pass of the core loop meets all 7 criteria (no unlabeled control, combined rows read as one stop, state/role announced, live prompt-advance works, font-scale ≥ 2.0×, reduce-motion honored, contrast) | P0.3 `ComposeView` boundary, Phase 1 shared-core (`signalAccessibilityLabel`), Phase 2 UI build-out |
| **P3-C — Test strategy** | 4-layer pyramid: shared-core parity (`swift test` + `fixture-runner` + `skip test`), Android JUnit/Robolectric, Compose UI/nav, on-device smoke (the release gate) | **~4–6 d** net-new (layer 1 inherited from P0.4) | 7 criteria green on the integrated build: golden fixtures byte-identical on both paths, `skip test` parity, JUnit/Compose suites, instrumented encode, smoke 100% owner-signed, CI blocks on red | P0.1, P0.4, P0.3, Phase 1.3/1.4, Phase 2.7, **P1-B (Android CI)** |
| **P3-D — Play compliance & readiness** | Data-safety form, **Health apps declaration** (no iOS analogue), privacy-policy wiring, `minSdk 28`/`targetSdk 36`, final 16 KB re-verify, **closed-testing policy** (12/14/account gate) | **~2–3 d** paperwork (wall-clock **3+ wks** by the tester gate) | All 7: data-safety + Health declaration accepted, policy live/generalized, release AAB 16 KB-aligned, account-deletion N/A recorded, closed-testing gate met (production access granted or pending ≤7-day review), all console declarations clean | P0.1 (16 KB), P0.2 (STT libs/host), Phase 1.4/2.5 permissions, existing iOS App Store readiness |
| **P3-E — Release engineering & beta ops** | Signed/tagged AAB pipeline (Play App Signing), `versionCode`/`git tag` discipline, closed-track **ops** (invites, 14-day clock, staged-rollout playbook), Play Vitals + PLR + triage loop | **~3–4 d** setup + **14+ calendar days** clock | Signed AAB from a tagged commit (16 KB green) installs via `bundletool`; live on closed track to ≥12 opted-in testers; 14-day clock running/monitored; Vitals+PLR read with a documented triage loop; tagging rule in force | P0.1 (16 KB gate), P0.2 (model size), **P1-B CI**, **P3-D (policy)**, Phase 2 core loop |

**Cross-workstream couplings to hold in mind:**
- **Closed-testing gate is split by design:** **P3-D owns the policy** (12 testers / 14 consecutive days / personal-account-created-after-2023-11-13 condition + the production-access application); **P3-E owns the ops** (recruiting, opt-in, keeping the 14-day clock unbroken, staged rollout). They share one closed track and cite the same numbers — see Consolidated.
- **The thermal guardrail (P3-A) is net-new Android code**, not a port: iOS captures `thermalState` diagnostically but never throttles compute (ANE, not CPU). It rides **Phase 2 P2-A's push-style `cancel()`** (flips the native atomic whisper's `abort_callback` polls) plus the existing `unloadModel()`; **`isDecoding` is a net-new additive ask on P2-A** — flag it to Phase 2.
- **SkipUI a11y gaps (P3-B):** `.accessibilityHint`, `.accessibilityElement(children:)`, and `AccessibilityNotification.Announcement` are unsupported by SkipUI — each degrades the mirrored iOS AX posture and needs a `ComposeView` fallback. Glyph a11y needs none — per Phase 2 P2-D the glyphs are shared `Shape`s in `SquirlDesignSystem` whose a11y modifiers map directly.
- **16 KB re-verify moves downstream:** P0.1 owns the primary gate on the bring-up APK; **P3-D §5 / P3-E re-verify on the release AAB** because the STT engine's `.so`s (absent at P0.1) are a known r27 alignment risk.
- **Persistence fork (P0.3) sets P3-C's DB-test shape:** Room ⇒ Android-native JUnit/Robolectric; SkipSQL ⇒ the DB tests collapse into shared-core Swift Testing.

---

## P3-A — Resilience & edge states

Phase 3 hardening workstream. Owns everything that happens when the happy path doesn't: every error surface, every empty state, and the two failure classes that are *new to Android* because STT moved from Apple's ANE to a sustained CPU decode — **thermal throttling** and **native-memory / storage pressure from a 264–640 MB model + accumulating m4a files**.

### Goal

Make the core loop (record → transcribe → extract → journal) degrade safely on real mid-tier hardware:

- **Never lose the user's recording.** The recorded `.m4a` and its DB row are durable *before* transcription starts; any downstream failure (thermal abort, OOM unload, crash, disk-full-on-decode) discards only in-flight compute, never captured audio. This is the single non-negotiable — it mirrors the iOS "transcription runs silently in the background; results land in Calendar/Insights later" contract ([DESIGN.md:91](../DESIGN.md#L91), check-in Saved state).
- **Every failure has one calm, named surface** and a defined recovery, reusing the iOS error vocabulary (`RecordingError`, `ModelDownloadFailure`, `ModelStatus`) so the two apps behave identically.
- **Thermal guardrail:** abort transcription on sustained thermal pressure and re-drain it when the SoC cools — the guardrail iOS never needed (iOS only *records* `thermalState` for diagnostics; it never throttles compute — see below).

**Key asymmetry vs iOS.** On iOS, thermal state is captured but purely diagnostic: `ProcessInfo.processInfo.thermalState` is snapshotted into `SessionSnapshot` ([SessionSnapshot.swift:11,23,34](../app-four/Diagnostics/SessionSnapshot.swift#L11)) and shown in the bug reporter ([IssueReportView.swift:89](../app-four/Views/Feedback/IssueReportView.swift#L89)) — there is **no compute-abort guardrail anywhere in the iOS codebase**, because WhisperKit runs on the Apple Neural Engine and doesn't cook the SoC. Android's CPU/int8 decode is a sustained all-core load that *does* throttle (P0.2 §"Latency / thermal failure": "whisper-small CPU decode is a sustained all-core load … the SoC thermally throttles"). So the thermal guardrail below is **net-new Android code with no iOS analogue to port** — it must be designed here, not mirrored.

---

### Error-surface catalog

Each condition maps to (a) the reused enum case, (b) the user-facing surface (Paper & Pollen: quiet, non-judgmental, "relief then permission" — [DESIGN.md:16](../DESIGN.md#L16)), and (c) recovery. The iOS column cites the pattern being mirrored.

| # | Condition | Enum (reuse) | User-facing surface | Recovery | iOS pattern mirrored |
|---|---|---|---|---|---|
| 1 | **Mic permission denied** | `RecordingError.permissionDenied` ([AppEnums.swift:28](../app-four/Models/AppEnums.swift#L28)) | Check-in idle hub shows an inline "Microphone access needed" card with a **Settings deep-link** button (not a raw system toast). Record button disabled. | User grants in system settings → returns → gate re-checks on `onResume`. | `CheckInViewModel.permissionDenied` flag drives inline UI ([CheckInViewModel.swift:13,128](../app-four/ViewModels/CheckInViewModel.swift#L13)) |
| 2 | **Model missing / not yet installed** | `ModelStatus.notInstalled` / `.downloading` / `.installing` ([AppEnums.swift](../app-four/Models/AppEnums.swift)) | If install-time asset pack: never hit (model ships with APK). If on-demand pack: a one-time "Preparing transcription (264 MB)" progress card gates first check-in; record is still allowed (audio captured, transcription deferred). | Play Asset Delivery fetch; on success drain deferred recordings (ties P2-E). | `AIModelServiceImpl.download` progress stream ([AIModelServiceImpl.swift:22](../app-four/Services/AIModelServiceImpl.swift#L22)); `ModelStatus` |
| 3 | **Model corrupted** (bad unzip, truncated pack, failed checksum) | `ModelStatus.corrupted` ([AppEnums.swift](../app-four/Models/AppEnums.swift)) | "Transcription needs a repair" card → **Re-download / re-verify** action. Audio still captured meanwhile. | Delete + re-fetch pack; validate model dir before load (mirror `findWhisperModelFolder` file-existence checks, [AIModelServiceImpl.swift:133-147](../app-four/Services/AIModelServiceImpl.swift#L133)). | `ModelStatus.corrupted`; folder validation at [AIModelServiceImpl.swift:141-147](../app-four/Services/AIModelServiceImpl.swift#L141) |
| 4 | **Transcription failed** (engine returned empty / JNI error / init null) | throw to Kotlin (never `""`) — plan Phase 2 step 5 standard | Recording saves normally; detail view transcript card shows "Couldn't transcribe this one" + **Retry** (audio player still works — audio is the source of truth). | Retry re-runs decode on the persisted file; repeated failure leaves the entry as audio-only. | `conversionFailed("Transcription engine not initialized")` on nil context ([WhisperKitTranscriptionService.swift:116-117](../app-four/Services/WhisperKit/WhisperKitTranscriptionService.swift#L116)); `"No transcription result"` on empty ([:158-159](../app-four/Services/WhisperKit/WhisperKitTranscriptionService.swift#L158)) |
| 5 | **Disk full — before record** | `RecordingError.deviceDiskFull` ([AppEnums.swift:31](../app-four/Models/AppEnums.swift#L31)) | Record button → "Not enough space to record" sheet with a **Manage storage** button (`ACTION_MANAGE_STORAGE`). | User frees space → re-check via `getAllocatableBytes`. | Pre-record floor `availableStorage() < 20_000_000` → `throw .deviceDiskFull` ([AudioRecordingServiceImpl.swift:60-61](../app-four/Services/Audio/AudioRecordingServiceImpl.swift#L60)) |
| 6 | **Disk full — during record/encode** (`ENOSPC`/`IOException` from `MediaMuxer`) | `RecordingError.storageFull` ([AppEnums.swift:30](../app-four/Models/AppEnums.swift#L30)) | Recording stops gracefully; **partial audio up to the failure is finalized and kept** if the muxer flushed ≥1 segment; else the temp file is cleaned. "Recording stopped — storage full." | Same as #5; the saved partial is transcribable. | `classify()` maps `NSFileWriteOutOfSpaceError`/`ENOSPC` → out-of-space ([AIModelServiceImpl.swift:78-82](../app-four/Services/AIModelServiceImpl.swift#L78)) |
| 7 | **Disk full — model download/unpack** (on-demand pack) | `ModelDownloadFailure.insufficientSpace` ([Protocols.swift:144](../app-four/Services/Protocols.swift#L144)) | "Need ~600 MB free to set up transcription" + Manage storage. Record still allowed (deferred transcription). | Free space → resume Play Asset Delivery. | `ModelDownloadFailure.insufficientSpace`; `classify` ENOSPC branch ([AIModelServiceImpl.swift:82](../app-four/Services/AIModelServiceImpl.swift#L82)) |
| 8 | **Thermal abort** (`THERMAL_STATUS_SEVERE`+ during decode) | `RecordingError.interruption(.systemOverload)` ([AppEnums.swift:32,40](../app-four/Models/AppEnums.swift#L32)) | **No error to the user for the recording** — audio is safe. Detail shows a soft "Transcript will finish when your phone cools down" state. | Deferred → P2-E recovery drain retries when status ≤ `LIGHT`. | New (no iOS analogue). `InterruptionType.systemOverload` case already exists ([AppEnums.swift:40](../app-four/Models/AppEnums.swift#L40)) |
| 9 | **Audio interruption** (call / audio-focus loss / app backgrounded past FGS grace) | `RecordingError.interruption(.phoneCall / .appBackgrounded)` ([AppEnums.swift:39,41](../app-four/Models/AppEnums.swift#L39)) | Recording auto-pauses; on transient loss (Siri, brief call, route blip) it resumes; on hard loss it saves what it has. | Resume or save-partial per policy. | Pure decision fn `interruptionResponse(...)` ([AudioRecordingServiceImpl.swift:186-225](../app-four/Services/Audio/AudioRecordingServiceImpl.swift#L186)) — port to `AudioManager.OnAudioFocusChangeListener` |
| 10 | **No network** (on-demand pack only; transcription itself is fully offline) | `ModelDownloadFailure.noNetwork` ([Protocols.swift:143](../app-four/Services/Protocols.swift#L143)) | Only during first-run model fetch: "Connect to Wi-Fi to finish setup." Never blocks recording or (once model present) transcription. | Auto-retry on connectivity. | `classify` URLError branch ([AIModelServiceImpl.swift:66-74](../app-four/Services/AIModelServiceImpl.swift#L66)) |

**Design rule for all ten:** the recording is never the thing that fails. Every surface above either (a) blocks *before* capture with a clear fix (#1, #5, #7), or (b) fails *after* capture leaving audio intact and transcription retryable (#2, #3, #4, #6, #8). No surface ever puts the user's spoken check-in at risk.

---

### Thermal guardrail — abort transcription, preserve audio

**Ordering invariant (this is what makes abort safe).** Transcription may only start once the audio artifact is durable:

1. `AudioRecord` → `MediaCodec` (AAC) → `MediaMuxer(MUXER_OUTPUT_MPEG_4)` writes `.m4a`; on `stopRecording` the muxer is **stopped, released, and the file fd fsync'd/closed**.
2. A `Recording` row is inserted with the **existing** `status = .pendingTranscription` ([AppEnums.swift:5](../app-four/Models/AppEnums.swift#L5)) via `@Upsert` (never REPLACE+CASCADE — plan Phase 1 §3) **before** any decode is enqueued. (No new persisted field — the port reuses `RecordingStatus`, so Phase 1's 29-field DTO guard holds.)
3. Only then is the persisted file path handed to the STT service.

Because of (1)+(2), an abort at step 3 discards *only* GPU/CPU decode work. The file and row survive a process death, an OOM, or a thermal abort.

**Detection.** Register a thermal listener at foreground-service start and poll headroom around each decode. `getThermalHeadroom(seconds)` returns a normalized float where **≥ 1.0 == entering `THERMAL_STATUS_SEVERE` throttling** ([Android Thermal API](https://developer.android.com/games/optimize/adpf/thermal)); it returns **`NaN` if polled more than once per second** ([PowerManager](https://developer.android.com/reference/android/os/PowerManager)). `addThermalStatusListener` is API 29, `getThermalHeadroom` is API 30 — both ≥ our minSdk 28 floor, so **guard for API 29/30** on API 28 devices (fall back to status listener only, and to `dumpsys`-parity behavior: proceed but watch RTF drift).

```kotlin
// THERMAL_STATUS_* : NONE=0 LIGHT=1 MODERATE=2 SEVERE=3 CRITICAL=4 EMERGENCY=5 SHUTDOWN=6
// https://developer.android.com/reference/android/os/PowerManager
class ThermalGovernor(context: Context) {
    private val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
    private val executor = ContextCompat.getMainExecutor(context)

    /** True once the SoC is at/over SEVERE — decode must abort and defer. */
    @Volatile var shouldAbort: Boolean = false
        private set

    /** Wired to SttBridge::cancel() — push-style abort (flips P2-A's native atomic, polled by whisper's abort_callback). */
    var onAbort: (() -> Unit)? = null

    private val listener = PowerManager.OnThermalStatusChangedListener { status ->
        // SEVERE+ means throttling is active; anything ≤ MODERATE is workable.
        val nowAbort = status >= PowerManager.THERMAL_STATUS_SEVERE
        if (nowAbort && !shouldAbort) onAbort?.invoke()   // fire cancel() once on the SEVERE transition
        shouldAbort = nowAbort
        Log.i("Thermal", "status=$status abort=$shouldAbort")
    }

    fun start() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {          // API 29
            pm.addThermalStatusListener(executor, listener)
            shouldAbort = pm.currentThermalStatus >= PowerManager.THERMAL_STATUS_SEVERE
        }
    }
    fun stop() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) pm.removeThermalStatusListener(listener)
    }

    /** Pre-flight: don't even start a batch if we're forecast to throttle. Poll ≤1 Hz (else NaN). */
    fun safeToStartDecode(): Boolean {
        if (shouldAbort) return false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {          // API 30
            val headroom = pm.getThermalHeadroom(10)                    // 10 s forecast
            if (!headroom.isNaN() && headroom >= 0.95f) return false    // >0.95 ≈ MODERATE band; conservative margin below the 1.0 SEVERE line
        }
        return true
    }
}
```

**Abort mechanism — engine-specific, cooperative (never kill the JNI thread mid-write).**

- **whisper.cpp:** the P2-A bridge already wires `whisper_full_params.abort_callback` to poll a native atomic; **calling `sttBridge.cancel()` flips that atomic** (ANDROID_PHASE2.md:260,1023). whisper.cpp checks it between decode steps and unwinds cleanly, so the mutex-guarded context handle (plan Phase 2 step 5) stays valid for the next run. The governor's only job is to call `cancel()` when SEVERE fires — no new bridge surface.
- **sherpa-onnx (Parakeet/Whisper-QNN):** the offline recognizer is a **single-shot decode per utterance — `cancel()` cannot abort mid-utterance**. The thermal fallback on this branch is coarser: let the in-flight utterance finish (or `unloadModel()` if the process must shed), **defer the remaining queue** as `TranscriptionOutcome.Deferred`, and never start the next utterance while `governor.shouldAbort` holds. Never claim mid-decode abort on Parakeet.

```kotlin
suspend fun transcribeGuarded(rec: Recording, governor: ThermalGovernor): TranscriptionOutcome {
    if (!governor.safeToStartDecode())
        return TranscriptionOutcome.Deferred(rec.id, reason = DeferReason.THERMAL)   // audio already safe on disk

    // Push-style abort: governor.onAbort → sttBridge.cancel() flips the native atomic whisper's
    // abort_callback polls (ANDROID_PHASE2.md:260,1023) — transcribe() takes no abort parameter.
    // The persisted .m4a is decoded to PCM by the Phase-1 audio decoder (P1-D owns m4a→PCM, MediaCodec).
    governor.onAbort = { sttBridge.cancel() }
    val result = withContext(Dispatchers.Default) {
        val pcm = audioDecoder.decodeToPcm16kMono(rec.audioPath)
        sttBridge.transcribe(pcm)
    }
    return when {
        governor.shouldAbort  -> TranscriptionOutcome.Deferred(rec.id, DeferReason.THERMAL) // requeue, don't error
        result.text.isBlank() -> TranscriptionOutcome.Failed(rec.id)                          // catalog #4
        else                  -> TranscriptionOutcome.Success(rec.id, result.text)
    }
}
```

On `Deferred`, the row's `status` stays `.pendingTranscription` (the thermal-defer *reason* is held transiently in-memory, not persisted as a new column) and the **P2-E recovery drain** re-attempts when the listener reports status back down to ≤ `LIGHT`. This is the "abort + preserve audio" guardrail end-to-end: the SoC cools, the queue drains, the transcript lands silently — matching the iOS deferred-results model ([DESIGN.md:91](../DESIGN.md#L91)).

**Battery guardrail (secondary).** The same governor also respects `PowerManager.isLowPowerMode` / `isDeviceIdleMode`: in Low Power Mode, defer non-active-check-in transcription to the drain rather than decoding immediately (a check-in "shouldn't cost visible battery" — P0.2 §Thermal/battery). This mirrors nothing on iOS (again ANE), but reuses the same defer-and-drain machinery.

---

### Storage-pressure & large-file behavior

Three storage consumers: **the model** (264 MB whisper-small q8_0 / ~640 MB Parakeet int8 — plan P0.2), **accumulating `.m4a` files** (~0.5–1 MB/min AAC mono 16 kHz), and **DB rows** (negligible). Use `StorageManager`, **not `File.getUsableSpace()`** — `getAllocatableBytes()` can legitimately return *more* than free space because the OS will clear other apps' reclaimable caches to satisfy the allocation ([app-specific storage](https://developer.android.com/training/data-storage/app-specific)).

```kotlin
// Mirrors iOS pre-record floor: availableStorage() < 20_000_000 → throw .deviceDiskFull
//   AudioRecordingServiceImpl.swift:60-61
private const val RECORD_FLOOR_BYTES = 20_000_000L   // 20 MB, byte-identical to iOS availableStorage() < 20_000_000 (AudioRecordingServiceImpl.swift:60)

fun ensureSpaceToRecord(context: Context): Boolean {
    val sm = context.getSystemService(StorageManager::class.java)
    val uuid = sm.getUuidForPath(context.filesDir)
    val allocatable = sm.getAllocatableBytes(uuid)          // may exceed free space (clearable caches)
    return if (allocatable >= RECORD_FLOOR_BYTES) {
        sm.allocateBytes(uuid, RECORD_FLOOR_BYTES)          // reserve up front so a long record can't ENOSPC mid-stream
        true
    } else {
        false // → RecordingError.deviceDiskFull → catalog #5 surface (ACTION_MANAGE_STORAGE)
    }
}
```

- **Pre-record gate (#5):** the block above, before `AudioRecord.startRecording()`.
- **During-record (#6):** wrap `MediaMuxer.writeSampleData` — an `IOException`/`ENOSPC` stops capture, finalizes the flushed segments if any, and surfaces `RecordingError.storageFull`. Classify exactly as iOS does (`ENOSPC` → out-of-space, [AIModelServiceImpl.swift:78-82](../app-four/Services/AIModelServiceImpl.swift#L78)).
- **Model install (#7):** for an **install-time asset pack**, Play guarantees space at install and there is *no runtime download surface* — this is simpler than iOS (WhisperKit downloads at runtime). For an **on-demand/fast-follow pack**, gate the Play Asset Delivery fetch on `getAllocatableBytes ≥ ~1.3 GB` (model + unpack headroom; plan risk #4 notes install-time packs need ~2× free space). Failure → `ModelDownloadFailure.insufficientSpace`.
- **Large-file cap:** port the iOS max-duration timer (`startMaxDurationTimer`, [AudioRecordingServiceImpl.swift:251](../app-four/Services/Audio/AudioRecordingServiceImpl.swift#L251)) so a runaway recording can't fill the disk; long clips are chunked for decode (whisper `carry_initial_prompt`, plan P0.2 candidate a).
- **Manage-storage surface:** the `ACTION_MANAGE_STORAGE` intent (catalog #5/#7) is the single user-facing recovery for all disk-full paths.

---

### Low-memory / `onTrimMemory` for model + STT

The resident model is the one large native allocation (264–640 MB mapped off-heap by the C/C++ runtime — invisible to the Java heap, so it's `onTrimMemory`, not `OutOfMemoryError`, that governs it).

**Register `ComponentCallbacks2` at the Application level and only handle the two levels Android still delivers.** Beginning **Android 14 the system no longer delivers the legacy `TRIM_MEMORY_RUNNING_*` / `_MODERATE` / `_COMPLETE` constants, and they were formally deprecated in Android 15** — handle **only `TRIM_MEMORY_UI_HIDDEN` and `TRIM_MEMORY_BACKGROUND`** ([Manage your app's memory](https://developer.android.com/topic/performance/memory)).

```kotlin
class SquirlApp : Application(), ComponentCallbacks2 {
    private val stt: SttEngine by inject()   // owns the native context handle + its mutex

    override fun onTrimMemory(level: Int) {
        when (level) {
            // The only two levels delivered on Android 14+; others are deprecated (Android 15).
            TRIM_MEMORY_UI_HIDDEN, TRIM_MEMORY_BACKGROUND -> {
                // Do NOT unload while a decode is in flight — the FGS keeps us alive; defer.
                if (!stt.isDecoding) stt.unloadModel()   // frees native ctx under the mutex; reload lazily
            }
            else -> Unit
        }
    }
    override fun onConfigurationChanged(newConfig: Configuration) {}
    @Deprecated("Legacy") override fun onLowMemory() { if (!stt.isDecoding) stt.unloadModel() }
}
```

- **Explicit unload API** mirrors iOS `unloadModel()` ([WhisperKitTranscriptionService.swift:216](../app-four/Services/WhisperKit/WhisperKitTranscriptionService.swift#L216), also called on every transcription completion/error [:175,199](../app-four/Services/WhisperKit/WhisperKitTranscriptionService.swift#L175)). On Android it nulls the JNI context handle under the mutex; next `transcribe` lazily reloads (mirror `loadModel` guard, [WhisperKitTranscriptionService.swift:49-55](../app-four/Services/WhisperKit/WhisperKitTranscriptionService.swift#L49)).
- **Never unload mid-decode** — the `isDecoding` guard defers unload until the in-flight transcription completes or thermally aborts; the microphone foreground service (`FOREGROUND_SERVICE_MICROPHONE`, plan Phase 1 §4) keeps the process alive through `UI_HIDDEN` during an active check-in.
- **Prefer `mmap` model load** (whisper.cpp supports it) so the kernel can evict clean model pages under memory pressure instead of OOM-killing the process — this makes the `onTrimMemory` unload a *courtesy*, not the only defense.
- `onLowMemory()` is not formally deprecated but is legacy; keep it as a belt-and-braces unload, gated by the same `isDecoding` check.

---

### Empty / edge states (per DESIGN.md)

Reuse the existing iOS empty-state vocabulary; do not invent new ones.

| State | Surface | Source |
|---|---|---|
| **First launch / no recordings** | **Calendar-empty**: header + illustration + copy, top hero 40 — a dedicated screen already specced. | [figma-ds-reproduction-plan.md:80](ui/figma-ds-reproduction-plan.md#L80) (Calendar "Unchanged", do not redesign — [DESIGN.md](../DESIGN.md)) |
| **Empty day** (day with no check-in) | **DayCard folded** shows the empty-copy branch of its summary `FlowLayout` (glyphs \| empty copy), not a blank card. | [figma-ds-reproduction-plan.md:80](ui/figma-ds-reproduction-plan.md#L80) (DayCard-folded) |
| **Insights, no sleep data** | Signals section renders Sleep as **"not tracked yet"** rather than a zero bar. | [DESIGN.md:93](../DESIGN.md#L93) |
| **Recording detail, sparse extraction** | Conditional cards: Medications card renders **only if ≠ ∅**; absent sections simply don't appear (no "None" placeholders cluttering the page). | ADHDSummarySection, [figma-ds-reproduction-plan.md:80](ui/figma-ds-reproduction-plan.md#L80) |
| **Check-in captured** (post-save) | Saved state: check pops + "Captured." with Done leading — **no transcribing UI, no daily card**; results land later. This *is* the deferred-transcription empty state that thermal/OOM defer piggyback on. | [DESIGN.md:91](../DESIGN.md#L91) |
| **Transcript pending / deferred (thermal/OOM)** | Transcript card shows the soft "will finish when your phone cools down" / "finishing up" state, audio player already usable. New Android state, styled on the existing transcript `StatusPill`. | Catalog #8; StatusPill [figma-ds-reproduction-plan.md:80](ui/figma-ds-reproduction-plan.md#L80) |

Tone across all: calm, unhurried, non-judgmental ([DESIGN.md:16](../DESIGN.md#L16)) — an empty day is permission, not a scold.

---

### Exit criteria (binary)

1. **Audio-durability property test passes:** with transcription forced to throw / abort / OOM-unload at every point after `stopRecording`, the `.m4a` file and its `Recording` row are present and playable in 100% of injected-failure runs (instrumented test).
2. **Thermal abort verified on device (deterministic):** with `adb shell cmd thermalservice override-status 3` (SEVERE) forced mid-decode, transcription aborts and **zero recordings are lost**; then `override-status 1` (LIGHT) + `override-status reset` proves the deferred queue drains every transcript to `Success`. The organic 5-consecutive-check-in run on the P0.2 thermal rig is kept as a secondary realism check, not the gate.
3. **Disk-full is unreachable-by-surprise:** pre-record gate blocks below the 20 MB floor with the Manage-storage surface; an induced `ENOSPC` mid-record finalizes-or-cleans with no crash and no orphan temp file.
4. **Memory:** with `adb shell am send-trim-memory <pkg> UI_HIDDEN` (and a real home-button `UI_HIDDEN` + task-switch `BACKGROUND` transition — the only two levels Android 14+ delivers and the only two the handler acts on), the model unloads when idle, never mid-decode, and reloads correctly on next check-in; no native leak across 20 load/unload cycles (verified via `dumpsys meminfo`). `onLowMemory()` is exercised via its own path; `RUNNING_CRITICAL` is deliberately **not** exercised because the handler ignores it by design.
5. **Every catalog row (1–10) has a wired surface** reachable in a debug "chaos menu" and screenshot-reviewed against DESIGN tone.
6. **All six empty/edge states render** from real empty data (no mock) on device.

Any red → not shippable to closed beta.

### Risks & effort

| Risk | Sev | Mitigation |
|---|---|---|
| `getThermalHeadroom` returns **NaN** on mid-tier devices (P0.2 REVIEW NOTE 5) | Med | Guardrail already leans on the **status listener** (categorical SEVERE) as primary; headroom is only a pre-flight optimization. NaN → skip the pre-check, rely on listener. |
| sherpa-onnx has **no mid-utterance abort** — single-shot decode; `cancel()` can't interrupt it | Med | Let the in-flight utterance finish (or unload if the process must shed) and defer the remaining queue; worst case one utterance's compute is wasted, audio still safe. Acceptable. |
| API 28/29 devices lack `getThermalHeadroom` (API 30) / listener (API 29) | Low | SDK-guarded; API 28 falls back to RTF-drift watch + no proactive throttle. Small install-base slice. |
| Unloading the model mid-decode → JNI crash / corrupt handle | High | `isDecoding` guard + mutex-owned handle; unload deferred. Covered by exit criterion #4. |
| Install-time asset pack still needs ~2× space at install (plan risk #4) | Med | Not app-controllable (Play installs it); document the requirement, gate on-demand packs with `getAllocatableBytes`. |

**Effort:** ~1.0 engineer-week within Phase 3 — thermal governor + engine abort wiring (~2 d, most of the novelty), storage gates + `onTrimMemory`/unload (~1 d, largely mirrors iOS), the ten surfaces + six empty states + chaos menu (~1.5 d), device verification against the P0.2 thermal rig (~0.5 d). The audio-durability property test (#1) is the highest-value item and should be written first (TDD).

---

### Cross-phase dependencies & assumptions

- **Depends on P2-E (recovery drain):** the thermal/OOM/space **defer-and-drain queue is shared infrastructure**. P3-A produces the *defer* signals (`TranscriptionOutcome.Deferred`, keeping `status = .pendingTranscription`); P2-E owns the *drain*, but its current triggers are **launch / foreground / download-complete only** (ANDROID_PHASE2.md:1005-1007) — it has **no** thermal/space/network trigger today. **Requirement on P2-E:** add a thermal-`≤LIGHT` (and space-recovered) drain trigger to that set; flag to Phase 2. **Fallback:** if P2-E won't take it, P3-A's ThermalGovernor listener calls `drainIfModelReady()` directly on the transition to ≤LIGHT. If P2-E lands a different queue contract, the `Deferred` outcomes here must map onto it. Exit criterion #2 depends on whichever lands.
- **Depends on P0.2 winner (assumed decided at G0):** the abort mechanism is engine-specific — whisper.cpp `abort_callback` (fine-grained, per-step) vs sherpa-onnx (coarse — single-shot decode per utterance, no mid-utterance abort). Written for both; the surviving engine picks one. **Contract:** cooperative abort rides Phase 2 P2-A's existing `cancel()` (flips an atomic checked by whisper's `abort_callback` — ANDROID_PHASE2.md:260,341,1023,1049); the ThermalGovernor calls `cancel()` rather than passing an abort-closure parameter (no such parameter exists on `transcribe(pcm16kMono:)`). Retry/deferred re-decode of a persisted `.m4a` goes m4a→PCM through the **Phase-1 audio decoder (P1-D, MediaCodec)**, then `transcribe(pcm)`. `unloadModel()` already exists on the P2-A surface (:341); **`isDecoding` is a net-new additive ask to P2-A** (a `@Volatile` flag) — flag it to Phase 2. **Degraded fallback if `isDecoding` never lands:** P3-A owns a local decode-in-flight flag for the `onTrimMemory` unload guard; if `cancel()`/abort is somehow unavailable, fall back to **pre-flight-only** thermal defence (never *start* a decode while `shouldAbort`/headroom ≥ 0.95; on the sherpa branch let the in-flight utterance finish and defer the queue; rely on OS throttling + mmap page eviction for anything already in flight) and record it as an accepted limitation — exit criterion #2 relaxes to "no *new* decode starts under SEVERE" in that mode.
- **Depends on Phase 1 §4 audio pipeline:** the durability invariant assumes `MediaMuxer` fsync-on-stop and `@Upsert` row insert *before* enqueue. If the audio pipeline persists lazily, the "never lose audio" guarantee breaks. **This ordering is NOT yet stated in Phase 1 §4 (fsync-on-stop + `@Upsert`-before-enqueue absent there) — raise it as a back-requirement on Phase 1, don't assume it's already implemented.**
- **Model delivery fork (P0.2.6 / plan Phase 2 step 5):** install-time vs on-demand asset pack changes which surfaces exist — install-time removes catalog #7 and #10 (no runtime download). Written to cover both; collapses once delivery is decided.
- **Persistence fork (P0.3, Room vs SkipSQL):** P3-A adds **no** new `Recording` column — the deferred/awaiting state reuses the existing `status: RecordingStatus` field ([AppEnums.swift:5](../app-four/Models/AppEnums.swift#L5)), so the **29-field count and Phase 1's DTO field-count guard are preserved** (an earlier draft invented a 30th `transcriptionState` field — corrected). The fork only changes which store persists `status` (Room column vs SkipSQL column); no migration, v1 greenfield.
- **minSdk 28 / targetSdk 36 (plan Phase 3 §10):** thermal listener (API 29) and `getThermalHeadroom` (API 30) are both above minSdk — the SDK guards above are mandatory, not optional.
- **No iOS thermal guardrail to port:** confirmed by absence — iOS `thermalState` is diagnostic-only ([SessionSnapshot.swift:11](../app-four/Diagnostics/SessionSnapshot.swift#L11)). This workstream's thermal code is Android-original and carries no cross-platform parity obligation (unlike the error enums and empty states, which must match iOS).

---

## P3-B — Accessibility

**Phase 3 (Hardening → closed beta) workstream.** Mirrors the iOS VoiceOver / Dynamic Type / AA-contrast / Reduce-Motion posture onto Android's TalkBack + Compose semantics, through the SkipFuseUI → SkipUI mapping layer. Grounding standard: external claims carry a cited URL (verified 2026-07-22); repo claims carry `file:line`. This section is **hardening**, not greenfield — the shared SwiftUI already carries a real accessibility layer; the job is to verify what survives the SkipUI mapping, patch what doesn't, and prove it on-device with TalkBack.

### Goal

Every interactive element in the Android build is TalkBack-navigable with a correct label, value, state, and role; custom glyphs are labeled or marked decorative; text honors the system font scale; motion honors "Remove animations"; and color contrast meets the same AA bar (with the same owner-accepted exceptions) as iOS. Binary exit: a blind-navigation TalkBack pass of the core loop (record → transcribe → review → day view → detail → settings) completes with no unlabeled control, no double-read, no focus trap, and no gesture-only action.

### iOS AX posture to mirror (repo grounding)

The iOS app has a real, non-trivial accessibility layer — this is the *spec* the Android build must match, not a checkbox to invent:

- **Labels everywhere** — `accessibilityLabel` on ~25 view files (e.g. [CheckInView.swift:220](../app-four/Views/CheckIn/CheckInView.swift#L220) "Start voice check-in", [ExtractionReviewView.swift:310](../app-four/Views/ExtractionReviewView.swift#L310) "Mark \(med.name) as taken or missed", [CalendarDayCell.swift:38](../app-four/Views/Components/CalendarDayCell.swift#L38)).
- **Hints** — ~17 `accessibilityHint` sites carrying "what happens next" copy: [TimelineRow.swift:23](../app-four/Views/Components/TimelineRow.swift#L23) "Opens recording detail", [RecordingDetailView.swift:208](../app-four/Views/RecordingDetailView.swift#L208) expand/collapse, all Settings toggles ([MyMedicationSection.swift:69](../app-four/Views/Settings/MyMedicationSection.swift#L69), [DayCardSettingsSection.swift:15](../app-four/Views/Settings/DayCardSettingsSection.swift#L15)), [WelcomeView.swift:59](../app-four/Views/Onboarding/WelcomeView.swift#L59).
- **Value** — `accessibilityValue` for stateful controls: [ExtractionReviewView.swift:311](../app-four/Views/ExtractionReviewView.swift#L311) "Taken"/"Missed", [JournalExportSection.swift:57](../app-four/Views/Settings/JournalExportSection.swift#L57) recovery key.
- **Traits** — `.isHeader` ([InsightsView.swift:63](../app-four/Views/InsightsView.swift#L63), `:109`, `:178`; [WelcomeView.swift:46](../app-four/Views/Onboarding/WelcomeView.swift#L46)), `.isSelected` (chips, day cells, dose-guard modes — [Chip.swift:68](../app-four/Views/Components/Chip.swift#L68), [CalendarDayCell.swift:40](../app-four/Views/Components/CalendarDayCell.swift#L40), [DoseGuardSection.swift:39](../app-four/Views/Settings/DoseGuardSection.swift#L39)), `.isButton` ([FoldedDayCardHeader.swift:66](../app-four/Views/Components/FoldedDayCardHeader.swift#L66)).
- **Grouping** — heavy `accessibilityElement(children: .combine / .contain / .ignore)` so multi-view rows read as one element: [RecordingRow.swift:31](../app-four/Views/Components/RecordingRow.swift#L31), [TimelineRow.swift:28](../app-four/Views/Components/TimelineRow.swift#L28), [FoldedDayCardHeader.swift:64](../app-four/Views/Components/FoldedDayCardHeader.swift#L64)/`:142`, and every Insights card ([ConnectionCardsView.swift:15](../app-four/Views/Insights/ConnectionCardsView.swift#L15)/`:69`/`:105`, [SignalAverageGauges.swift:15](../app-four/Views/Insights/SignalAverageGauges.swift#L15)/`:54`, [MoodBubbleChart.swift:27](../app-four/Views/Insights/MoodBubbleChart.swift#L27), [DailyRhythmMatrix.swift:40](../app-four/Views/Insights/DailyRhythmMatrix.swift#L40)).
- **Custom glyphs own their label** — [SignalGlyph.swift:25-27](../Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/SignalGlyph.swift#L25) sets `.accessibilityElement()` + `.accessibilityLabel(signalAccessibilityLabel(...))` + `.accessibilityHidden(decorative)`; the label reads e.g. "Energy: Alert, 4 of 5" ([GlyphSignal.swift:77-83](../Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/GlyphSignal.swift#L77)). `decorative: true` is passed at ~15 call sites where the parent row already announces the signal (avoids double-read).
- **Live VoiceOver announcements** — the check-in flow posts prompt-advance announcements gated on speech silence so VoiceOver never talks over the speaker: [CheckInView.swift:65](../app-four/Views/CheckIn/CheckInView.swift#L65) `AccessibilityNotification.Announcement(message).post()`, driven by the announcement gate in [CheckInViewModel.swift:49-110](../app-four/ViewModels/CheckInViewModel.swift#L49) (FR-010/012).
- **Reduce Motion** — `@Environment(\.accessibilityReduceMotion)` in ~11 views, each gating `withAnimation(reduceMotion ? nil : Motion.…)`; plus [AccessibilityHelpers.swift:5](../app-four/Utils/AccessibilityHelpers.swift#L5) `UIAccessibility.isReduceMotionEnabled`.
- **Dynamic Type** — the design system scales custom sizes against a text style: `Typography.text(_ size:, weight:, relativeTo:)` at [Typography.swift:59](../Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/Typography.swift#L59) (e.g. `Typography.text(24, weight: .bold, relativeTo: .title2)`), so numeric sizes still track the system content-size setting.
- **AA contrast intent** — `DESIGN.md` targets WCAG AA and *documents* every miss with an owner ruling: `NewLook.inkSecondary` `#8A8A8E` is 3.0:1 (sage) / 3.4:1 (white), accepted as a known limitation ([DESIGN.md:133-137](../DESIGN.md#L133); ruling 2026-07-12); selection green `#54B492` 2.52:1 label accepted ([DESIGN.md:140](../DESIGN.md#L140); ruling 2026-07-16); remediations already applied — destructive `#D54037` (4.55:1 on card), `accent/medicationText` `#6B4E8F`, `sleepIndigo` dark `#8E9BD4` ([DESIGN.md:128-131](../DESIGN.md#L128)).

### SwiftUI-AX → SkipUI / Compose semantics mapping

SkipFuseUI compiles the shared SwiftUI natively and SkipUI maps supported modifiers to Compose `Modifier.semantics{}`. **The controlling rule: "Anything not listed here is likely not supported."** ([skip-ui README](https://github.com/skiptools/skip-ui/blob/main/README.md) L590, verified 2026-07-22). Support legend: **✅ Full · 🟢 High · 🟡 Medium · 🟠 Low** (README support legend; per-row line numbers drift with every README commit — re-verify against the pinned Skip SHA at execution).

| iOS modifier (repo uses it) | SkipUI status | Compose target it maps to | Gap / action |
|---|---|---|---|
| `.accessibilityLabel` | ✅ Full (README L1410) | `semantics { contentDescription = … }` | Direct — no work |
| `.accessibilityValue` | ✅ Full (L1414) | `semantics { stateDescription = … }` (read before description) | Direct |
| `.accessibilityHidden` | ✅ Full (L1402) | `clearAndSetSemantics{}` / `contentDescription=null` | Direct — decorative glyphs covered |
| `.accessibilityAddTraits(.isHeader)` via `.accessibilityHeading` | ✅ Full (L1398) | `semantics { heading() }` | Direct |
| `.accessibilityAddTraits` (`.isButton`, `.isSelected`) | 🟢 High (L1389) — *"Only traits that map to Compose accessibility roles are used"* | `Role.Button` / `selected = true` | Verify `.isSelected`→`selected` and `.isButton`→`Role.Button` actually round-trip; unmapped traits silently drop |
| `.accessibilityIdentifier` | ✅ Full (L1406) | `semantics { testTag = … }` | Enables Compose UI tests |
| **`.accessibilityHint`** | **NOT listed ⇒ unsupported** (0 hits in matrix) | (none) | **GAP.** ~17 hint sites lose their "what happens next" copy. Fold the hint into the label, or set an `onClickLabel`, or drop to `ComposeView` |
| **`.accessibilityElement(children: .combine/.contain/.ignore)`** | **NOT listed ⇒ unsupported** (0 hits) | `semantics(mergeDescendants = true)` / `clearAndSetSemantics{}` | **BIGGEST GAP.** Every combined row/card (RecordingRow, TimelineRow, day-card header, all Insights cards) risks fragmenting into per-word TalkBack stops. Needs verification + likely per-screen `ComposeView` `mergeDescendants` wrappers |
| `.accessibilitySortPriority`, `.accessibilityRepresentation`, `.accessibilityAction` | NOT listed ⇒ unsupported | — | Not used in repo today — no action, but do not introduce them |
| **`AccessibilityNotification.Announcement`** | **NOT listed ⇒ unsupported** (0 hits) | Compose `semantics { liveRegion = LiveRegionMode.Assertive }` or `View.announceForAccessibility()` | **GAP.** The check-in prompt-advance announcement gate ([CheckInView.swift:65](../app-four/Views/CheckIn/CheckInView.swift#L65)) has no SkipUI path — must be re-expressed as a Compose live region behind `#if os(Android)` / `ComposeView` |

**Environment keys that DO map (read-only, supported):** `accessibilityReduceMotion` (README L2643), `accessibilityVoiceOverEnabled` (L2646 — reads TalkBack state), `accessibilityInvertColors`, `accessibilityReduceTransparency` (L2644, Android → "reduce blur effects"), `accessibilityEnabled`, `accessibilitySwitchControlEnabled`. **`dynamicTypeSize` is NOT in the exposed list** — code that branches on `@Environment(\.dynamicTypeSize)` won't compile for Android; rely on automatic sp scaling instead (see below).

**Compose semantics reference** (all: [developer.android.com/develop/ui/compose/accessibility/semantics](https://developer.android.com/develop/ui/compose/accessibility/semantics)): `contentDescription`, `stateDescription`, `role` (`Role.Button/Checkbox/Switch/RadioButton`), `heading()`, `selected`, `disabled`, `liveRegion` (`LiveRegionMode.Polite`/`.Assertive`), `mergeDescendants`, `clearAndSetSemantics{}`, `customActions` (`CustomAccessibilityAction` — the accessible alternative to swipe/drag gestures), `error(msg)`, `paneTitle`.

**Fallback pattern for the three gaps** — drop the affected subtree to Compose via `ComposeView` (SkipFuseUI, README §composeview) and set semantics directly:

```swift
// Shared Swift, Android-only branch for the combined recording row + its hint.
#if os(Android)
import SkipUI  // ComposeView bridge
// row content rendered by Compose so we can express mergeDescendants + onClickLabel,
// neither of which SkipUI maps from SwiftUI today.
#endif
```

```kotlin
// Merge a multi-Text row into ONE TalkBack stop (mirrors accessibilityElement(children:.combine)).
Row(
    modifier = Modifier
        .clickable(onClickLabel = "Opens recording detail") { openDetail() }  // ← the missing hint
        .semantics(mergeDescendants = true) { }   // one focusable element, children read in order
) { /* time, glyphs, transcript snippet */ }

// Decorative signal glyph (mirrors SignalGlyph decorative:true):
Canvas(Modifier.size(16.dp).clearAndSetSemantics { }) { /* draw sprout/bolt/aperture */ }
// NOTE: under Phase-2 P2-D the glyphs are shared SwiftUI Shapes (SignalGlyph.swift:25-27) rendered by
// SkipFuseUI, so their a11y rides the shared modifiers; this Compose Canvas path is only a fallback.

// Non-decorative glyph:
Canvas(Modifier.size(30.dp).semantics { contentDescription = "Energy: Alert, 4 of 5" }) { … }

// Selected chip (mirrors .accessibilityAddTraits(.isSelected) + label):
Modifier.semantics { role = Role.Button; selected = isSelected
    stateDescription = if (isSelected) "Selected" else "Not selected" }
```

### TalkBack pass + smoke checklist

TalkBack is Android's screen reader (Settings → Accessibility → TalkBack). Enable it, then linear-swipe (right = next element) through each core-loop screen. Automated backstop: Compose UI tests keyed off `.accessibilityIdentifier`→`testTag`, plus **Accessibility Scanner** (Play Store) and **Espresso `AccessibilityChecks`** for touch-target/contrast/label lint ([developer.android.com/guide/topics/ui/accessibility/testing](https://developer.android.com/guide/topics/ui/accessibility/testing)). Scanner/Espresso catch *missing* labels and small targets; only a **human TalkBack pass** catches double-reads, wrong focus order, and gesture traps — it is non-negotiable (mirrors the iOS "device QA is the release gate" rule).

Smoke checklist (each item = pass/fail):
- [ ] **Check-in**: record button announces label + role "Button"; timer status is not spelled digit-by-digit every 0.1 s; **prompt-advance announcement fires once, after the speaker goes quiet, and does not interrupt** (the [CheckInViewModel.swift:49](../app-four/ViewModels/CheckInViewModel.swift#L49) gate, re-expressed as a live region); pause/cancel/finish all reachable and labeled.
- [ ] **Extraction review**: each med row reads "Mark {name} as taken or missed", value "Taken"/"Missed"; emotion/side-effect chips announce selected state; date/time pickers labeled; save/cancel labeled.
- [ ] **Day view / calendar**: a day cell reads as ONE element with its summary (not fragmented per glyph); selected day announces "Selected"; month/week header announces expand/collapse affordance; empty day reads calm copy, not a bare glyph.
- [ ] **Recording detail**: signal glyphs read "{kind}: {word}"; transcript expand/collapse announces its state; audio player scrubber exposes progress; edit button labeled.
- [ ] **Insights**: section titles are headings (rotor/heading-navigation jumps between them); each card reads as one combined sentence with its bar value; locked cards announce "locked" + unlock copy.
- [ ] **Settings**: every toggle announces label + on/off state + its hint-equivalent; dose-guard radio group announces selection.
- [ ] **Global**: no element focuses that has no label; no decorative glyph is focusable; focus order matches visual reading order; every tap target ≥ 48 dp.

### Dynamic Type ↔ Android font-scale

- Android exposes a system **font scale** (Settings → Display → Font size / Accessibility → Font size); Compose `Text` sized in **`sp`** scales with it automatically. SkipUI maps SwiftUI `.font` (✅ Full, README L1619) to Compose text, so semantic styles (`.body`, `.title2`, …) and numeric `.system(size:)` sizes land as `sp` and **scale for free** — this covers most of the app.
- **What does NOT carry:** `dynamicTypeSize` is not an exposed SkipUI environment key, so any `@Environment(\.dynamicTypeSize)` branch is iOS-only (`#if !os(Android)`). And `Typography.text(size, relativeTo:)`'s `UIFontMetrics`-style *clamped, style-relative* scaling ([Typography.swift:59](../Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/Typography.swift#L59)) is an iOS concept — on Android the numeric `sp` scales **linearly and unbounded** with font-scale. Verify layouts survive the top Android font scale (2.0×) and the "Bold text" + "Display size" (density) settings; the largest sizes are where combined-row grouping and truncation break.
- Action: at the two largest font scales, TalkBack-walk the check-in and day-card screens and confirm no clipped/overlapping labels; where a fixed numeric size overflows, cap via a Compose `TextUnit` guard in the per-screen fallback rather than converting to `dp` (converting to dp would *freeze* the size and fail the AA text-scaling requirement).

### AA contrast audit

- Android's bar is identical to the iOS target: **WCAG AA 4.5:1** for normal text, **3:1** for large text (≥18 pt / 14 pt bold) and for UI-component/graphical boundaries ([WCAG 2.1 SC 1.4.3](https://www.w3.org/WAI/WCAG21/Understanding/contrast-minimum.html); non-color-cue rule per [Android a11y principles](https://developer.android.com/guide/topics/ui/accessibility/principles)). The design tokens are shared, so the audit is a **re-verification, not a re-derivation**.
- **Inherited, already-documented exceptions** carry to Android unchanged (same hex): `inkSecondary` `#8A8A8E` (3.0:1/3.4:1, [DESIGN.md:133](../DESIGN.md#L133)) and selection green `#54B492` label (2.52:1, [DESIGN.md:140](../DESIGN.md#L140)). Decision needed for the Android build: **re-affirm the owner rulings or fix for Android** — Android's Accessibility Scanner will flag both on every screen they appear, so document the acceptance in the Play a11y notes or the Scanner report will look like an unaddressed defect.
- Run Accessibility Scanner across all core-loop screens in **both light and dark**; dark-mode tokens are AA by construction ([DESIGN.md](../DESIGN.md) rulings) so failures there indicate a mapping bug, not a design choice.
- Reinforce the non-color-cue rule (Android principle #5): signal level must never be conveyed by color alone — the glyph shape + the "X of 5" label already satisfy this; verify it holds through the shared P2-D `Shape` glyph mapping (and at any residual Compose fallback site).

### Reduce-motion

- Android's equivalent is **Settings → Accessibility → Remove animations**, which sets `Settings.Global.ANIMATOR_DURATION_SCALE = 0`. SkipUI surfaces this through the **supported** read-only `accessibilityReduceMotion` environment key (README L2643) — so the existing pattern **maps directly**: every `withAnimation(reduceMotion ? nil : Motion.…)` in the ~11 views compiles and behaves on Android with no rewrite.
- `UIAccessibility.isReduceMotionEnabled` ([AccessibilityHelpers.swift:5](../app-four/Utils/AccessibilityHelpers.swift#L5)) is UIKit and iOS-only — fence it `#if !os(Android)` and route Android callers through `@Environment(\.accessibilityReduceMotion)` (already the dominant pattern; the helper is the sole UIKit holdout).
- Verify on-device: with "Remove animations" on, the medication-bar onset pulse ([MedicationBarView.swift:141](../app-four/Views/Components/MedicationBarView.swift#L141)), calendar expand/collapse, and transcript expand all settle instantly with no animation.

### Glyph / decorative labeling

- Per Phase 2 **P2-D (plan-of-record, Option A)** the four `Canvas` glyphs are re-authored as composed `Shape`s **in the shared `SquirlDesignSystem` and adopted on iOS too** (ANDROID_PHASE2.md:666,805), so `SignalGlyph` stays a single shared SwiftUI view rendered **natively through SkipFuseUI**. Its accessibility rides the **existing shared modifiers** at [SignalGlyph.swift:25-27](../Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/SignalGlyph.swift#L25) — `.accessibilityLabel(signalAccessibilityLabel(...))` (✅ Full → Compose `contentDescription`) and `.accessibilityHidden(decorative)` (✅ Full → `clearAndSetSemantics{}`), both ✅-mapped in the matrix above — so **no per-screen Compose re-attachment is required for glyph a11y**; only verify the mapping survives on-device. Hedge: *if* any glyph must still fall back to `Canvas`/Compose, attach `contentDescription`/`clearAndSetSemantics` at that boundary. The `ComposeView` fallback boundary is therefore for the grouping/hint/live-region gaps, not for glyphs.
- Every non-text `Icon`/vector (waveform, chevrons, mic) must carry `contentDescription = null` when decorative (the row labels it) or a real description when it is the only affordance — mirror the existing `.accessibilityHidden(true)` sites (e.g. [RecordingRow.swift:42](../app-four/Views/Components/RecordingRow.swift#L42), [CalendarHeaderView.swift:78](../app-four/Views/Components/CalendarHeaderView.swift#L78)).

### Exit criteria (binary, testable with TalkBack)

Android AX is **green** only if ALL hold on a real device with TalkBack on:
1. **No unlabeled focusable control** across the core loop — Accessibility Scanner reports zero "missing label / item description" items on every screen, AND a human right-swipe pass reaches no element that announces only its position/type.
2. **Combined rows read as one stop** — RecordingRow, TimelineRow, the day-card header, and every Insights card each take exactly one TalkBack focus and read their full sentence (no per-glyph/per-word fragmentation, no double-read of a signal already named by the row).
3. **State + role announced** — selected chips/day-cells/dose-modes announce selected/not-selected; toggles announce on/off; section titles are reachable by heading navigation; buttons announce role "Button".
4. **Live announcement works and does not interrupt** — during a TalkBack check-in, each prompt advance is announced once, only after the speaker goes quiet, via a Compose live region (no lost prompt, no talk-over).
5. **Font scale ≥ 2.0×** — check-in and day-card screens show no clipped or overlapping text at the maximum system font size.
6. **Reduce-motion honored** — with "Remove animations" on, no core-loop animation plays.
7. **Contrast** — Accessibility Scanner (light + dark) surfaces only the two owner-accepted, documented exceptions (`inkSecondary`, selection-green label); any *new* contrast failure is a red.

Anything short of all seven is not green — record which check failed and the suspected mapping cause (SkipUI gap vs. Compose semantics vs. token).

### Risks & effort

| Risk | Impact | Mitigation |
|---|---|---|
| **`accessibilityElement(children:)` unsupported** — the app's most-used grouping modifier has no SkipUI mapping. | Combined rows/cards fragment into dozens of TalkBack stops → the single biggest AX regression. | Per-screen `ComposeView` with `Modifier.semantics(mergeDescendants = true)`; it reuses the P0.3 `ComposeView` seam (glyphs themselves need no fallback under P2-D). Verify empirically on Day 1 — do not assume SkipUI silently merges. |
| **`accessibilityHint` unsupported** — ~17 sites lose "what happens next". | Users lose affordance context (e.g. "Opens recording detail"). | Fold hint into the label, or use Compose `clickable(onClickLabel:)`; audit every hint site for a label-side home. |
| **`AccessibilityNotification.Announcement` unsupported** — the check-in gate can't post. | A blind user gets no prompt-advance cue → the flow's core AX feature silently dies. | Re-express as a Compose `liveRegion` (Assertive) toggled by the existing silence gate; the gate logic is shared Swift and reusable. |
| **`.accessibilityAddTraits` is 🟢 High, not ✅** — only traits mapping to Compose roles survive. | `.isSelected`/`.isButton` may drop silently. | Verify each trait round-trips under TalkBack; where it doesn't, set `role`/`selected` in a Compose fallback. |
| **Unbounded `sp` scaling** vs. iOS clamped Dynamic Type. | Layout breakage at 2.0× font scale. | Test at max scale; cap with `TextUnit` guards, never convert to `dp`. |
| **Two known contrast exceptions flagged by Scanner every run.** | Looks like unaddressed defects to a Play reviewer. | Document the owner rulings in the Play a11y notes / Scanner report annotations. |

**Effort: ~4–5 engineer-days** within the Phase 3 window. Rough split: 1 d verifying the SkipUI mapping on-device (which modifiers actually round-trip) and cataloguing the real gap set; 1.5 d building the `ComposeView` fallbacks for grouping + hints + the live-region announcement (reusing the P0.3 `ComposeView` seam); 0.5 d font-scale + reduce-motion verification; 1 d full TalkBack smoke pass + Accessibility Scanner sweep (light/dark) + fixes; 0.5 d contrast re-verification and Play a11y write-up. **Slip risk:** the grouping fallback count is unknown until the Day-1 catalogue — if SkipUI merges nothing automatically, every combined row/card needs a wrapper and this could reach 6–7 days.

### Cross-phase dependencies & assumptions

- **Depends on P0.3 (Skip Fuse UI spike):** P0.3 decides the per-screen Compose fallback pattern — the AX work *reuses that exact `ComposeView` boundary* for the grouping/hint/live-region gaps (glyphs themselves are shared P2-D `Shape`s and need no Compose attach point). If P0.3 finds SkipFuseUI can't host `ComposeView` cleanly for these subtrees, the three-gap fallback strategy needs rework. **Assumption:** `ComposeView` interop (README §composeview) is available under SkipFuseUI compiled Swift.
- **Depends on Phase 1 shared-core extraction:** `signalAccessibilityLabel` / `GlyphSignal` / the `decorative:` flag must live in the shared `SquirlDesignSystem` package (they're `nonisolated`, [GlyphSignal.swift:77](../Packages/SquirlDesignSystem/Sources/SquirlDesignSystem/GlyphSignal.swift#L77)) so Android reuses the label *strings*; only the attach-point is re-platformed.
- **Depends on Phase 2 UI build-out (step 7):** every screen must exist before its TalkBack pass; this workstream runs *after* the core-loop UI lands, not alongside it.
- **Couples to P3 test strategy (step 9):** Compose UI tests key off `.accessibilityIdentifier`→`testTag` (✅ supported) — so identifiers must be set during build-out, not retrofitted, or the automated AX backstop has nothing to query.
- **Assumption — SkipUI matrix is current as of 6.3-era (v1.9.4):** support statuses read from [skip-ui README](https://github.com/skiptools/skip-ui/blob/main/README.md) `main` on 2026-07-22; re-verify the four gap rows (`accessibilityHint`, `accessibilityElement(children:)`, `Announcement`, `accessibilityAddTraits` completeness) against the pinned Skip version at execution time — an intervening release may close one, shrinking the fallback surface.
- **Assumption — font-scale auto-scaling:** SkipUI maps `.font` sizes to `sp`; unverified that *every* `.system(size:)` path does so rather than emitting `dp`. First on-device font-scale test confirms or refutes this; a `dp` leak would be an AA text-scaling failure to fix in the mapping, not the app.
- **Out of scope (inherited from plan):** widgets / Live Activities / App Intents surfaces are not in Android v1, so their iOS accessibility (none material) needs no mirroring. Voice Control / Switch Access parity beyond touch-target sizing is deferred to Android v2.

---

## P3-C — Test strategy

**Workstream owner:** Test engineering. **Phase:** 3 (Hardening → closed beta). **Depends on:** P0.1 (aarch64 toolchain), P0.4 (golden-fixture suite already authored), P0.3 (persistence fork: Room vs SkipSQL), Phase 1 items 3–4 (persistence + audio built), Phase 2 item 7 (UI built), and Phase 1 P1-B (Android CI to automate the below).

### Goal

Ship a test suite that lets `main` for the Android app stay releasable with the same confidence the iOS app has today, given a hard constraint: **no XCTest carry-over exists on Android, and there is no shared UI-test runtime.** The iOS project's automated coverage is 57 Swift Testing files, zero XCTest (verified this session: `grep -rl "import Testing" app-fourTests` → 57; `import XCTest` → 0). None of those files test SwiftUI views — they test the shared logic core and services. That split is the strategy's foundation: **the deterministic logic is tested once in Swift and proven byte-identical on both platforms; everything platform-specific (Room, `AudioRecord`/`MediaCodec`, Compose, navigation) is tested Android-native; the composed app is verified by an on-device smoke checklist that mirrors the iOS device-QA rounds** — which are a non-negotiable release gate per [CLAUDE.md](../CLAUDE.md) ("No PR is merged without … manual human QA on device").

The goal is **not** to re-prove STT accuracy (frozen at the P0.2 gate) or logic correctness (proven at P0.4) in Phase 3 — it is to (a) re-run those gates against the integrated Phase-3 build, (b) add the Android-native layers that P0.x never covered, and (c) codify the manual release gate.

### The test pyramid

Four layers, widest/cheapest at the base. Each row states what runs it, where it runs, and what it is allowed to catch.

| Layer | Framework / runner | Executes on | Covers | Speed |
|---|---|---|---|---|
| **1. Shared-core parity (Swift)** | Swift Testing via `swift test` (host) **+** P0.4 `fixture-runner` (aarch64 device) **+** `skip test` (host↔Robolectric parity) | Mac host + real `arm64-v8a` device | Extractor byte-parity (golden fixtures), lexicon/cue matching, tense classification, level enums, DTO ↔ JSON codec, all pure `Foundation` logic | ms; the base of the pyramid — most assertions live here |
| **2. Android unit (Kotlin)** | JUnit4 + AndroidX Test + Robolectric | Host JVM (no device) | Room DAO/converters/`@Upsert`, audio format-selection + FGS state machine + interruption logic, JNI `jbyteArray`→UTF-8 decode | fast (JVM) |
| **3. Compose UI + navigation** | `androidx.compose.ui:ui-test-junit4` + `createComposeRule` + `TestNavHostController`, run under Robolectric | Host JVM (Robolectric) or instrumented | Check-in flow state machine, day-card→detail navigation, settings toggles, semantics/accessibility labels | fast (JVM); slower if instrumented |
| **4. On-device smoke (manual)** | Human, scripted checklist | ≥1 mid-tier physical device | Real mic capture, SkipFuseUI→Compose render fidelity, thermal/battery, TalkBack, dark mode, font scale, storage pressure, permissions | slow; owner-run **release gate** |

**Two things the pyramid deliberately does NOT collapse:**
- Layer 1's `skip test` host run and the P0.4 `fixture-runner` are *different mechanisms* — see the Skip section for why the on-device aarch64 run cannot be replaced by `skip test`.
- Layer 4 is manual on purpose. There is no automated visual-regression tool in v1 scope (see "No coverage").

### Shared-core parity tests (P0.4 suite: `swift test` + `fixture-runner`)

This is the base of the pyramid and the single most valuable suite in the port, because it is the guarantee that made the Option-B rewrite unnecessary ([ANDROID_PHASE0.md](ANDROID_PHASE0.md) §P0.4). Phase 3 does not author it — P0.4 does (40–60 cases in `Tests/ExtractorFixtures/`, each a `NNN-slug.txt` transcript + `NNN-slug.json` canonical output). Phase 3 **re-runs it against the integrated build and keeps it green as fixtures grow.**

The assertion is byte-equality of the canonically-encoded output, not value equality, to catch encoding drift (P0.4 §5):

```swift
import Testing
import Foundation

private let canonicalEncoder: JSONEncoder = {
    let e = JSONEncoder()
    e.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]  // deterministic key order; NOT .prettyPrinted
    return e
}()

@Test(arguments: FixtureCatalog.allCases)   // one row per NNN-slug pair
func extractorFixtureIsByteIdentical(_ name: String) throws {
    let transcript = try Fixtures.loadText(name)
    let got = try canonicalEncoder.encode(
        NLNoteExtractor(personalOverlay: nil).extract(from: transcript))  // overlay-free = deterministic core
    let want = try Fixtures.loadJSON(name)                    // raw bytes of NNN-slug.json
    #expect(got == want)                                     // Data == Data, byte-equal
}
```

**Two run paths, both required for the exit criterion:**

1. **iOS / host** — `swift test` over the whole corpus. The host is also the *generator* of goldens; regeneration is asserted byte-identical to the committed file and treated as a build failure on drift ([ANDROID_PHASE0.md](ANDROID_PHASE0.md) §P0.4.4).

2. **Android device** — there is no `swift test` for the Android triple and no Android CI in Phase 0. A dedicated **`fixture-runner` executable target** is cross-compiled and pushed to the device:

```bash
# scripts/android/run-fixtures.sh  (checked in; P0.4 §5)
swift build --swift-sdk aarch64-unknown-linux-android28 -c release --product fixture-runner
adb push .build/aarch64-unknown-linux-android28/release/fixture-runner /data/local/tmp/
adb push Tests/ExtractorFixtures /data/local/tmp/ExtractorFixtures
adb shell /data/local/tmp/fixture-runner /data/local/tmp/ExtractorFixtures   # prints per-case PASS/FAIL + byte-diff
```

Green on **both** = parity proven for that corpus on the real `arm64-v8a` ABI. Because the fixtures and assertion are shared, adding a fixture covers both platforms automatically.

### Skip test story (verified 2026-07-22)

Verified against Skip's own docs ([skip.dev/docs/testing](https://skip.dev/docs/testing/), [skip.dev/docs/modules/skip-unit](https://skip.dev/docs/modules/skip-unit/)):

- **`skip test`** is the primary command; it runs the suite on **both** the host (native Swift) and Android and prints a **side-by-side parity report** matching each test across platforms with result + run time — mismatches surface portability bugs immediately.
- **Framework support differs by mode.** Skip **Lite** (Swift transpiled to Kotlin) runs **both XCTest and Swift Testing**, transpiled to JUnit (this is what SkipUnit / `skip-unit` does). Skip **Fuse** native modules (our route — [ANDROID_PORT_PLAN.md](ANDROID_PORT_PLAN.md) §Route) support **Swift Testing only**: they execute the native Swift Testing runtime directly via its `swt` entry point, and **XCTest cases are not executed.**
- **This is a de-risked assumption for us, not a migration cost.** The iOS app is already 100% Swift Testing (all 57 test files, 0 XCTest; the other 10 of 67 files in app-fourTests are mocks/eval helpers). There is no XCTest to strand under Fuse. New shared-core tests must stay Swift Testing.
- **Android side runs on Robolectric (host JVM) by default.** `#if os(Android)` evaluates **false** under Robolectric; Skip exposes a `ROBOLECTRIC` compilation symbol for code that must run "on a device and under Robolectric." For real-device fidelity, `ANDROID_SERIAL=emulator-5554 skip test` (or a device serial) runs instrumented instead. A generated `XCSkipTests.swift` harness wires Xcode / `swift test` into the Gradle test pipeline.

**Critical limitation — why `skip test` does not subsume the P0.4 `fixture-runner`:** the default `skip test` Android leg runs Swift-native-on-host + Kotlin-on-Robolectric (host JVM, x86_64 Mac). It proves host↔JVM parity; it does **not** execute the extractor's `.so` on the production `arm64-v8a` device ABI. Byte-parity on the real target is a distinct guarantee, which is exactly why P0.4 keeps a separate aarch64 `fixture-runner` pushed via `adb`. Treat them as complementary: `skip test` guards the shared-core Swift↔Kotlin bridge broadly and cheaply on every push; the `fixture-runner` guards byte-parity on the real ABI at the gate.

### Android unit tests (JUnit + Robolectric)

Everything Kotlin-side that P0.4/`skip test` cannot reach: the persistence layer, the audio pipeline's decision logic, and the JNI decode boundary. Runs on the host JVM via Robolectric — no device, fast enough for every push once P1-B stands up CI.

**Persistence — Room DAO, converters, `@Upsert`-not-cascade** (shape valid iff P0.3 picks Room; if SkipSQL wins, these move up into Layer-1 Swift Testing instead — see Cross-phase). The schema is the full real model — **29 stored `Recording` fields, 3 relationships** ([Recording.swift](../app-four/Models/Recording.swift#L9), per [ANDROID_PORT_PLAN.md](ANDROID_PORT_PLAN.md) Phase 1.3). Real snippet:

```kotlin
@RunWith(RobolectricTestRunner::class)
class RecordingDaoTest {
    private lateinit var db: SquirlDatabase
    private lateinit var dao: RecordingDao

    @Before fun setup() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        db = Room.inMemoryDatabaseBuilder(ctx, SquirlDatabase::class.java)
            .allowMainThreadQueries()          // test-only; no background executor
            .build()
        dao = db.recordingDao()
    }
    @After fun teardown() = db.close()

    @Test fun upsert_updates_parent_without_cascade_deleting_children() = runTest {
        val rec = recordingFixture(id = "r1", segments = 3)
        dao.upsert(rec)
        dao.upsert(rec.copy(mood = MoodLevel.HIGH))   // @Upsert — never INSERT OR REPLACE (that cascades children away)
        val loaded = dao.recordingWithSegments("r1")
        assertEquals(MoodLevel.HIGH, loaded.recording.mood)
        assertEquals(3, loaded.segments.size)                          // children survive the update
        assertEquals(loaded.segments, loaded.segments.sortedBy { it.startTime })  // @Relation sorted, deterministic
    }

    @Test fun date_long_converter_roundtrips_utc() {
        val c = DateConverters()
        val d = Instant.parse("2026-07-22T00:29:00Z")
        assertEquals(d, c.toInstant(c.fromInstant(d)!!))              // Date↔Long, no TZ leak
    }
}
```

**Migration tests: N/A for v1, harness pre-wired for v2.** v1 is greenfield with schema versioned from 1 ([ANDROID_PORT_PLAN.md](ANDROID_PORT_PLAN.md) Phase 1.3) — there is nothing to migrate. Enable `exportSchema = true` now so `MigrationTestHelper.runMigrationsAndValidate(...)` works the day a v2 schema lands; do not write migration tests before there is a migration.

**Audio — logic is unit-testable; the codec is not.** `AudioRecord`, `MediaCodec`, and `MediaMuxer` are native/hardware and Robolectric's shadows do not actually encode — so the **real encode path is instrumented-only** (connected device/emulator, Layer 4 / a dedicated `androidTest` source set). What *is* pure logic and belongs in Robolectric unit tests: the float-PCM capability decision, the foreground-service state machine, and audio-focus interruption handling ([ANDROID_PORT_PLAN.md](ANDROID_PORT_PLAN.md) Phase 1.4):

```kotlin
@RunWith(RobolectricTestRunner::class)
class AudioEncoderPolicyTest {
    @Test fun falls_back_to_int16_when_float_pcm_unconfirmed() {
        // getInputFormat() does not confirm KEY_PCM_ENCODING == ENCODING_PCM_FLOAT
        val fmt = MediaFormat().apply { /* no float key set */ }
        assertEquals(ENCODING_PCM_16BIT, EncoderPolicy.pcmEncoding(reported = fmt))
    }
    @Test fun cannot_start_capture_from_background() {
        val sm = RecorderStateMachine(fgsGranted = false, recordAudioGranted = true)
        assertFailsWith<ForegroundServiceStartNotAllowed> { sm.startFromBackground() }  // Android 14+ FGS microphone rule
    }
    @Test fun audio_focus_loss_pauses_and_preserves_buffer() {
        val sm = RecorderStateMachine.recording()
        sm.onAudioFocusChange(AUDIOFOCUS_LOSS_TRANSIENT)
        assertEquals(RecorderState.PAUSED, sm.state)
        assertTrue(sm.bufferedPcmBytes > 0)                 // no data dropped on a phone call
    }
}
```

The actual "PCM → playable `.m4a`" encode is verified instrumented, asserting the muxed container is real (`MediaCodec` alone emits a raw AAC elementary stream, not a playable file — [ANDROID_PORT_PLAN.md](ANDROID_PORT_PLAN.md) Phase 1.4):

```kotlin
// androidTest/ (instrumented — real MediaCodec/MediaMuxer)
@Test fun encodes_playable_m4a_container() {
    val out = AudioEncoder().encode(silencePcm16k(seconds = 1))
    MediaExtractor().apply { setDataSource(out.absolutePath) }.use { ex ->
        assertEquals("audio/mp4a-latm", ex.getTrackFormat(0).getString(MediaFormat.KEY_MIME))
    }
}
```

**JNI decode boundary.** The STT bridge returns transcripts as a UTF-8 `jbyteArray` (never `NewStringUTF`, which corrupts supplementary characters — [ANDROID_PHASE0.md](ANDROID_PHASE0.md) §P0.1.3.6a, [ANDROID_PORT_PLAN.md](ANDROID_PORT_PLAN.md) Phase 2.5). Unit-test the Kotlin decode against emoji/non-Latin bytes so the boundary is proven before it touches a real model.

### Compose UI + navigation tests

Compose tests run on the JVM under Robolectric — no emulator needed ([developer.android.com/develop/ui/compose/testing](https://developer.android.com/develop/ui/compose/testing)). Dependencies: `androidx.compose.ui:ui-test-junit4` + `org.robolectric:robolectric`, with `testOptions { unitTests { isIncludeAndroidResources = true } }`. Drive the view models with fakes so no real STT/audio is involved.

**Check-in flow** (mirrors the iOS spec-024 single-`captureStage` refactor — ring stays centred, chrome floats):

```kotlin
@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "w411dp-h891dp")
class CheckInScreenTest {
    @get:Rule val rule = createComposeRule()

    @Test fun tapping_record_enters_recording_stage() {
        val vm = CheckInViewModel(recorder = FakeRecorder(), stt = FakeStt())
        rule.setContent { CheckInScreen(vm) }
        rule.onNodeWithContentDescription("Start check-in").performClick()
        rule.onNodeWithTag("recordingTimer").assertIsDisplayed()
        rule.onNodeWithText("Stop").assertExists()          // Stop + Cancel present over the ring
        rule.onNodeWithText("Cancel").assertExists()
    }

    @Test fun stop_transcribes_and_shows_extracted_signals() {
        val vm = CheckInViewModel(recorder = FakeRecorder(), stt = FakeStt(transcript = "took my meds, felt calm"))
        rule.setContent { CheckInScreen(vm) }
        rule.onNodeWithContentDescription("Start check-in").performClick()
        rule.onNodeWithText("Stop").performClick()
        rule.waitUntil { vm.state is CheckInState.Review }
        rule.onNodeWithText("Medication").assertExists()    // extractor output rendered
    }
}
```

**Navigation** via `TestNavHostController` — assert routes, not pixels:

```kotlin
@Test fun day_card_entry_opens_recording_detail() {
    lateinit var nav: TestNavHostController
    rule.setContent {
        nav = TestNavHostController(LocalContext.current).apply {
            navigatorProvider.addNavigator(ComposeNavigator())
        }
        SquirlNavHost(nav, sampleDay = dayFixture(entries = 1))
    }
    rule.onNodeWithText("Morning check-in").performClick()
    assertEquals("recordingDetail/{id}", nav.currentBackStackEntry?.destination?.route)
}
```

**Accessibility assertions ride along free:** `onNodeWithContentDescription` / semantics checks in these same tests catch missing labels before the TalkBack smoke pass, since Compose's test tree *is* the semantics/accessibility tree.

### On-device smoke checklist (mirrors the iOS QA rounds)

Manual, run on ≥1 **mid-tier physical device** (shared with the P0.2 procurement device), owner-signed. This is the direct analog of the iOS device-QA rounds (e.g. spec 024's calendar/check-in/settings round) and the same **release gate** — no merge to a releasable branch without it ([CLAUDE.md](../CLAUDE.md)). Binary pass/fail per line; any fail blocks the closed-beta cut.

**Core loop**
- [ ] Grant mic permission on first check-in; deny-then-retry path recovers gracefully.
- [ ] Record a real check-in → transcript appears → signals extracted → entry saved.
- [ ] Transcript with emoji / non-Latin text survives the JNI boundary (no corruption/crash).
- [ ] Stop mid-recording; Cancel mid-recording; both leave a consistent state.
- [ ] Incoming call / audio-focus loss mid-recording pauses and preserves audio (no data loss).

**Calendar / day view (027 layout parity)**
- [ ] Day card renders entries; expand/collapse works; "Always expand" setting honored.
- [ ] Tap entry → recording detail (027 four-card layout) opens and back returns.
- [ ] Empty day and dense day (many entries) both render without clipping.

**Recording detail**
- [ ] Playback of the saved `.m4a` works end-to-end.
- [ ] Edit/delete an entry; delete is visible and reversible-safe; list updates.

**Settings**
- [ ] Every toggle persists across relaunch (Room-backed).
- [ ] Model/storage state reflects the installed asset pack.

**Cross-cutting (each its own iOS-QA-round analog)**
- [ ] **Dark mode:** every screen legible; Paper & Pollen ramps + med-purple correct in both themes.
- [ ] **Font scale (largest / AX-equivalent):** no truncation or overlap — the Android analog of the iOS AX5 overlap check.
- [ ] **TalkBack:** every interactive element announces a meaningful label; check-in is completable eyes-free ([ANDROID_PORT_PLAN.md](ANDROID_PORT_PLAN.md) Phase 3.8).
- [ ] **Thermal/battery:** 5 consecutive check-ins → no thermal abort; on thermal pressure, audio is preserved (guardrail from Phase 3.8).
- [ ] **Storage pressure:** low-free-space + large-file behavior degrades gracefully.
- [ ] **Fidelity spot-check:** signal glyph + meadow ramp render acceptably (the enumerated P0.3 fallbacks are in place).
- [ ] **Cold start / rotation / process-death restore** on a real mid-tier SoC.

### What has NO coverage, and why

- **SkipFuseUI→Compose *visual* fidelity (pixels).** No automated visual-regression (Roborazzi/Paparazzi) in v1 scope. Rationale: the fidelity risk was enumerated at P0.3 with per-screen fallbacks; screenshot baselines are high-maintenance for a solo dev and add little over the manual fidelity spot-check. Caught by Layer-4 smoke. *(Candidate Phase-1-of-v2 add.)*
- **STT accuracy / WER.** Frozen at the P0.2 kill gate; not re-measured in Phase 3. Only re-opens if the engine or model changes — then re-run P0.2's harness, not this workstream.
- **Sustained on-device RTF / thermal as an automated perf gate.** Manual smoke only; no perf-assertion harness in v1 (device-and-workload-specific, low ROI to automate for one dev).
- **Real microphone hardware capture.** Cannot be unit-tested; instrumented + manual smoke only.
- **Actual codec encode under Robolectric.** `MediaCodec`/`MediaMuxer` shadows don't encode — moved to instrumented `androidTest`; the pure policy logic stays in Robolectric.
- **aarch64 device execution under `skip test`.** The default Robolectric leg is JVM/x86_64; real-ABI parity is covered by the P0.4 `fixture-runner`, not `skip test`.
- **iOS coverage is not re-authored here** — the existing 57 Swift Testing files already cover the iOS logic core; **Android CI to run all of the above is Phase 1 P1-B, not a Phase-3 deliverable** ([ANDROID_PHASE0.md](ANDROID_PHASE0.md) CI-posture note).

### Exit criteria (binary)

Phase 3 test strategy is **done** iff **all** hold on the integrated Phase-3 build:

1. **Golden-fixture suite GREEN on both paths** — iOS `swift test` **and** the on-device aarch64 `fixture-runner` (`scripts/android/run-fixtures.sh`), byte-identical output, ≥40 cases. *(Re-run of the P0.4 gate against the Phase-3 build.)*
2. **`skip test` GREEN** with a host↔Android parity report showing **zero** unmatched/divergent tests for the shared-core Swift Testing suite.
3. **Android JUnit/Robolectric suite GREEN** — Room DAO + converters + `@Upsert`/no-cascade + sorted `@Relation`; audio format-selection + FGS state machine + focus-loss preservation; JNI `jbyteArray` decode (incl. emoji/non-Latin).
4. **Compose UI + navigation Robolectric suite GREEN** — check-in state machine, day-card→recording-detail route, settings-toggle persistence, semantics labels present.
5. **Instrumented suite GREEN on ≥1 real device** — playable-`.m4a` encode + mic-permission grant/deny paths.
6. **On-device smoke checklist 100% pass**, owner-signed, on ≥1 mid-tier physical device — the release gate.
7. **CI runs 2–4 on every push and blocks merge on red** (wiring delivered by Phase 1 P1-B; Phase 3 asserts it is active).

Miss any one → not done. The sharpest single failures are (1) an aarch64 fixture diverging that `skip test`'s JVM leg hid, and (6) a fidelity/accessibility miss only visible on a real device.

### Risks & effort

**Budget:** ~4–6 engineer-days of net-new work inside the 3-week Phase 3 (layers 2–4 authoring + CI wiring hooks); layer 1 is inherited from P0.4. The on-device smoke round is owner labor, ~0.5–1 d per beta cut and repeated per release.

| Risk | Impact | Mitigation |
|---|---|---|
| **Robolectric + in-memory Room flakiness** (documented: [robolectric#8289](https://github.com/robolectric/robolectric/issues/8289) — in-memory DB works instrumented but breaks under Robolectric for some setups). | DB unit layer red/flaky. | Pin Robolectric version; if a DAO test won't stabilize under Robolectric, demote that case to instrumented `androidTest`. Keep converters/policy (pure) on Robolectric. |
| **`skip test` default leg is JVM/x86_64, not the device ABI.** | False green: host↔JVM parity passes while real arm64 diverges. | Keep the P0.4 `fixture-runner` as the authoritative ABI gate (exit-criterion 1); periodically run `ANDROID_SERIAL=… skip test` instrumented. |
| **`MediaCodec`/`MediaMuxer` unshadowed under Robolectric.** | Codec bugs escape the fast JVM layer. | Split: policy logic on Robolectric; real encode instrumented on device/emulator; assert container validity via `MediaExtractor`. |
| **No visual-regression harness.** | Silent SkipFuseUI→Compose drift (glyphs, meadow ramps). | Manual fidelity spot-check in smoke; enumerate P0.3 fallbacks; flag Roborazzi as a v2 candidate. |
| **On-device smoke is manual + owner-gated.** | Release-cadence bottleneck; human-miss risk. | Fixed written checklist (above), owner-signed per cut; mirrors the proven iOS device-QA discipline. |
| **Persistence fork undecided until P0.3.** | DB test *shape* (Layer 2 JUnit vs Layer 1 Swift Testing) unknown until then. | Author DB tests only after P0.3; if SkipSQL wins, they collapse into the shared-core Swift suite (strictly less Android-native surface). |
| **Emulator/device in CI for instrumented tests.** | Slow/absent CI leg. | Instrumented set kept small (encode + permission); the bulk (layers 1–3) is JVM-fast and gates every push. |

### Cross-phase dependencies & assumptions

**Depends on:**
- **P0.1** — the aarch64 Swift Android SDK toolchain; the `fixture-runner` cannot cross-compile or run on device without it.
- **P0.4** — the golden-fixture suite is authored there (`Tests/ExtractorFixtures/`, `scripts/android/run-fixtures.sh`); Phase 3 re-runs and grows it, does not create it. If P0.4's **escape hatch** is invoked (deterministic tokenizer made authoritative on iOS too), goldens are re-baselined once; this workstream's *structure* is unchanged, only the reference bytes.
- **P0.3** — the persistence fork (Room vs SkipSQL) decides whether the DB layer is Layer-2 JUnit/Robolectric (Room) or Layer-1 Swift Testing (SkipSQL, shared-core C-interop). Do not author DB tests before this is decided.
- **Phase 1.3 (persistence) + 1.4 (audio) + Phase 2.7 (UI)** must be implemented before layers 2–4 can target real code.
- **Phase 1 P1-B (Android CI)** — automates layers 1–4 on every push; without it these are checked-in scripts run locally (the Phase-0 posture). Exit-criterion 7 is satisfied by P1-B, asserted in Phase 3.

**Assumptions (flag if any breaks):**
- **Skip is in Fuse mode** (v1.9.4+, [ANDROID_PORT_PLAN.md](ANDROID_PORT_PLAN.md) §Route) → **Swift Testing only** for shared-core tests; XCTest is silently not executed under Fuse. Verified acceptable because the iOS app is already 100% Swift Testing (all 57 test files, 0 XCTest) — **no XCTest may be reintroduced**, or it will run on iOS but vanish on Android.
- `skip test` behaves as documented (host↔Android parity report; Robolectric default; `ANDROID_SERIAL` for instrumented; `ROBOLECTRIC`/`#if os(Android)==false` under Robolectric) — [skip.dev/docs/testing](https://skip.dev/docs/testing/).
- A mid-tier physical Android device is available for the smoke gate (shared with the P0.2 device — no separate procurement).
- Compose UI testing runs on the JVM via Robolectric without a device ([developer.android.com/develop/ui/compose/testing](https://developer.android.com/develop/ui/compose/testing)); a real emulator/device is needed only for the small instrumented codec/permission set.
- The extractor is exercised **overlay-free** (`personalOverlay = nil`) so the parity suite tests the deterministic core; the SwiftData-backed personal-overlay path is a separate line item, out of this suite's scope ([ANDROID_PHASE0.md](ANDROID_PHASE0.md) §P0.4.6).

---

## P3-D — Play compliance & readiness

*Workstream owner: repo owner (Caesar) — agent drafts every declaration, owner signs. The **Health-apps category selection** (§2) and the **data-safety "no data collected" attestation** (§1) are legal declarations: they are **owner-sign-off gates**, not agent-completable — the agent must not tick health categories or submit the data-safety form unilaterally.*

### Goal

Get the standalone, on-device-only Android build **submittable and promotable to production** on Google Play with zero policy blockers. Concretely: every mandatory Play Console declaration completed truthfully and consistently with the app's actual data flows (audio + DB stay on device, STT model bundled, no backend), the privacy-policy link wired, target/min SDK set to the production regime, the 16 KB gate re-confirmed on the release artifact, and the personal-account closed-testing requirement satisfied so a production release is legally possible. This mirrors — and reuses the artifacts of — the iOS App Store readiness the project already completed ([docs/app-store/SUBMISSION.md](app-store/SUBMISSION.md), [docs/app-store/PRIVACY_POLICY.md](app-store/PRIVACY_POLICY.md)).

**Data-flow ground truth** (from the shipping iOS app + the plan's Android scope), which every answer below is mapped to:
- Audio recording, transcript, and extracted signals are written to the app's **private on-device storage** only ([PRIVACY_POLICY.md](app-store/PRIVACY_POLICY.md) "What Squirl stores, and where").
- STT runs **on device**; audio is never uploaded. Android STT model bundled in an install-time Play asset pack ([ANDROID_PORT_PLAN.md](ANDROID_PORT_PLAN.md#L37)).
- **No account, no backend, no analytics, no ad IDs, no third-party SDKs** ([PRIVACY_POLICY.md](app-store/PRIVACY_POLICY.md) "What Squirl does not do").
- Exactly one network call: a **one-time model download from a CDN** — download only, no personal data / identifiers / telemetry transmitted. On iOS this is Hugging Face's CDN; on Android the winning engine's model host (P0.2). This is the *only* egress and it is the one nuance the data-safety answers must not misstate.

The iOS privacy posture is **"Data Not Collected"** + policy at **https://squirl.pt/privacy** ([SUBMISSION.md](app-store/SUBMISSION.md#L64-L66)). The Play posture is the same "no data collected" — but Play's form is structured differently and adds two declarations iOS has no equivalent of (**Health apps declaration** and the account-deletion question), so it is not a copy-paste.

---

### 1. Data-safety form (question-by-question, this app)

**Mandatory regardless of posture.** "All developers that have an app published on Google Play must complete the Data safety form… Even developers with apps that do not collect any user data must complete this form and provide a link to their privacy policy" (https://support.google.com/googleplay/android-developer/answer/10787469, verified 2026-07-22). Only exemptions are internal-testing-only apps and system/private apps — neither applies to a closed-then-production consumer app. So: form is required, and a privacy-policy URL is required, even though our truthful answer is "no data collected."

| Form question | Answer for Squirl Android | Why |
|---|---|---|
| Does your app collect or share any of the required user data types? | **No** | All user content (audio, transcript, mood/energy/focus/sleep/medication/side-effect/emotion signals) is written to app-private on-device storage and never transmitted. "Collect" in Play's definition = data transmitted off the device; on-device-only processing is not collection (https://support.google.com/googleplay/android-developer/answer/10787469). No account, no backend, no analytics, no ad identifiers. |
| Is all of the user data collected by your app encrypted in transit? | **N/A / not shown** | Follow-up only appears if collection = Yes. The one-time model *download* is inbound content delivery over HTTPS, carries no user data, and is not "user data collected," so it does not flip the top-level answer. Document this in the review notes so a reviewer doesn't read the network permission as undisclosed collection. |
| Do you provide a way for users to request that their data is deleted? | **N/A / not shown** (no collected data). See account-deletion §6 — no account, no server-side data to delete; on-device data is removed by uninstalling the app. | Deletion question is about server-held collected data. There is none. |
| Data types (Location, Personal info, Financial, Health & fitness, Messages, Audio, Files, etc.) | **None selected** | Nothing in any category is *collected/shared* (transmitted). Note the trap: the app clearly *handles* Audio and Health-adjacent data on-device — Play's data-safety form is scoped to transmission, so none are declared here, but the same data is exactly why the **Health apps declaration (§2) is unavoidable**. The two forms use different definitions; keep them consistent-by-design (collected = none; health *features* = yes). |
| Privacy policy URL | **https://squirl.pt/privacy** | Mandatory field. Reuse the live iOS policy verbatim — it already states "no accounts, no servers, no analytics," discloses the one-time model download, and is the canonical source ([PRIVACY_POLICY.md](app-store/PRIVACY_POLICY.md)). One edit needed: it currently names WhisperKit/Hugging Face (iOS); generalize the model-download sentence to cover the Android engine/host chosen in P0.2, or the policy will misdescribe the Android binary. |

**Net data-safety result:** "No data collected / No data shared" label, with a privacy-policy link — the Play equivalent of iOS "Data Not Collected." Truthful and defensible because the egress audit posture (on-device processing, single non-personal model download) is identical to the audited iOS binary ([SUBMISSION.md](app-store/SUBMISSION.md#L4)).

---

### 2. Health-apps declaration (unavoidable)

**Mandatory since 2024-08-31 for all apps**, including those on testing tracks; only system/private apps are exempt: "After August 31, 2024, all apps will be required to have completed an accurate Health apps declaration" (https://support.google.com/googleplay/android-developer/answer/14738291, verified 2026-07-22). This is a Play-specific gate with **no iOS equivalent** — it is new work relative to what the project already did for the App Store, and it cannot be skipped or answered "none."

**Why this app cannot tick "none":** the declaration's feature taxonomy explicitly lists, under *Medical*, **"Medication and Treatment Management — Apps for managing medication schedules, pharmacy services, and ensuring adherence to treatment plans,"** and, for the mood-journaling side, a mental-wellbeing category (console wording drifts — live taxonomy currently reads e.g. *Health & Fitness ▸ "Stress management"* / *Medical ▸ "Mental and Behavioral Health"*; select by meaning, not exact label). Squirl logs medications, side effects, and mood/energy/focus signals — it is squarely a medication-adherence + mental-wellbeing journaling tool. Ticking "none" would be an inaccurate declaration.

**Answers:**
- **Does your app provide any health features? → Yes.**
- **Select applicable features:**
  - *Medical ▸ Medication and Treatment Management* — the app records medication logs and adherence signals (the med capsule signal, side-effect capture). **Primary selection.**
  - *Health & Fitness ▸ Stress management / mental-wellbeing* **or** *Medical ▸ Mental health* — mood/energy/focus check-in journaling. Select whichever the console's current wording maps to a self-reflection/mood-journaling tool (not clinical counseling). Choose the least-overclaiming option that is still accurate; do **not** select clinical/diagnostic categories the app does not perform.
- **Additional info if prompted:** state plainly that the app is a personal, on-device journaling aid; it does **not** provide medical advice, diagnosis, dosing recommendations, or clinical decision support (the in-app medication-info disclaimer already establishes this posture — [SUBMISSION.md](app-store/SUBMISSION.md#L20)). This keeps the app out of the heavier "medical device / clinical" review lanes while being accurate.
- **Do not over-select:** picking clinical-decision-support / disease-management categories the app doesn't implement invites a stricter review and possible documentation demands. Select only Medication-management + mood/mental-wellbeing.

**Consistency check (must hold before submit):** Health declaration says "yes, health features (medication + mental wellbeing)"; Data-safety says "no health data *collected*." These are not contradictory — one is about product *features*, the other about data *transmission* — but a reviewer will look at both. The reconciliation is the on-device story: the app *has* health features but *transmits* no health data. State this explicitly in the review notes.

---

### 3. Privacy-policy requirement

- **Required by the data-safety form itself** (§1) — not optional, even for "no data collected" (https://support.google.com/googleplay/android-developer/answer/10787469).
- **Reuse the existing live policy:** https://squirl.pt/privacy is already published, effective 2026-07-21, canonical source [PRIVACY_POLICY.md](app-store/PRIVACY_POLICY.md), mirrored to the website ([SUBMISSION.md](app-store/SUBMISSION.md#L64)). No new legal doc needed.
- **One required edit for Android accuracy:** the policy's "Network access" + "Transcribes your voice on your device, using… (WhisperKit)" sentences name the iOS stack. Generalize to "an open-source on-device speech-recognition model, downloaded once from its content delivery network" so it truthfully describes both binaries, or add an Android-specific clause. Edit the canonical `.md` + `privacy.html` + website mirror together (they must not drift — [PRIVACY_POLICY.md](app-store/PRIVACY_POLICY.md) header rule).
- **App-level policy field:** paste the URL into Play Console ▸ App content ▸ Privacy policy (this is separate from the data-safety form's own link field; both must be filled and identical).

---

### 4. minSdk / targetSdk

- **minSdk = 28** (Android 9). Matches the port's deployment floor and the Swift Android SDK's min ([ANDROID_PHASE0.md](ANDROID_PHASE0.md) §P0.1 "Deployment floor is API 28"). Policy-safe: Play sets *target* SDK floors, not minimum, so a low minSdk is permitted and only widens device reach.
- **targetSdk = 36** (Android 16). **Required for new apps and app updates from 2026-08-31:** "Starting August 31 2026: New apps and app updates must target Android 16 (API level 36) or higher to be submitted to Google Play" (https://developer.android.com/google/play/requirements/target-sdk, verified 2026-07-22). The ~12-week port lands inside that regime, so build at 36 from day one — the plan already pins `targetSdk = 36` in the P0.1 scaffold ([ANDROID_PHASE0.md](ANDROID_PHASE0.md#L295)).
  - Right-now floor (before 2026-08-31) is targetSdk 35 to reach new users, 36 to be future-proof; there is no reason to target below 36 for a greenfield app.
  - Extension path exists to **2026-11-01** if more time is needed (https://developer.android.com/google/play/requirements/target-sdk) — but that is a fallback, not a plan; we target 36 outright.
- **Coupling to §5:** targetSdk 36 ⇒ API 35+ ⇒ the 16 KB page-size requirement applies to every submitted APK/AAB. That is *why* the 16 KB gate is a launch blocker, not a nice-to-have.

---

### 5. 16 KB final re-verify (final gate; primary gate is P0.1)

The engineering gate is owned by **P0.1 §4** (a hard sub-gate: every `.so` 16 KB / `0x4000`-aligned, verified on the bring-up APK; NDK r27x does **not** align by default, so explicit `-Wl,-z,max-page-size=16384 -Wl,-z,common-page-size=16384` linker flags on every `.so` — Swift core, C bridge, `libc++_shared.so` — https://developer.android.com/guide/practices/page-sizes). Requirement: "16 KB page-size support for all new apps and updates targeting API 35+," in force 2025-11-01, no documented extension.

**What P3-D adds is the *final* re-verify on the actual release artifact**, because the bring-up APK is not what ships:
- The release build now contains **new native `.so`s absent at P0.1** — the P0.2 STT engine (whisper.cpp or sherpa-onnx) and its transitive libs. Each is third-party and must be independently confirmed aligned; sherpa-onnx / whisper.cpp prebuilts are a known 16 KB risk on r27 ([ANDROID_PORT_PLAN.md](ANDROID_PORT_PLAN.md#L21)).
- Run Google's checker over the **release AAB's** extracted `lib/arm64-v8a/*.so`: `check_elf_alignment.sh` must print `ALIGNED (16384)` for every `.so` (script vendored/pinned in P0.1 §4). Also spot-check via `llvm-readelf -l` (LOAD Align column = `0x4000`).
- Confirm AGP `useLegacyPackaging = false` (default) so `.so`s are stored uncompressed + page-aligned inside the package.
- **CI gate:** the alignment check should already fail the build on any non-16 KB `.so` (P0.1 §6 mitigation). P3-D's job is to confirm that gate is green on the *release* variant with the STT libs present, and to physically load-test on a 16 KB-page device/emulator if one is available.

This is a re-confirmation checkbox here precisely because the hard work was front-loaded to P0.1 — but it is **not skippable**: a single misaligned STT `.so` is a Play upload rejection.

---

### 6. Account-deletion requirement (N/A rationale)

- Play's account-deletion policy applies **only to apps that let users create an account**: "If your app allows users to create an account from within your app… it must also allow users to request for their account to be deleted" (https://support.google.com/googleplay/android-developer/answer/13327111, verified 2026-07-22).
- **Squirl has no account and no backend** ([PRIVACY_POLICY.md](app-store/PRIVACY_POLICY.md) "No account… No servers"). There is nothing to sign up for and no server-side data. The requirement is therefore **N/A** — no in-app deletion flow and no web deletion resource are required.
- In the data-safety form, the "provide a way to request data deletion" question is not applicable because no data is collected/transmitted; on-device data is removed by uninstalling the app. Do **not** invent a deletion URL — declaring one would misrepresent a backend that doesn't exist.
- **Guard for scope creep:** sync (spec 038) is explicitly out of scope for Android v1 ([ANDROID_PORT_PLAN.md](ANDROID_PORT_PLAN.md#L6-L7)). If a future v2 adds accounts/sync, both the account-deletion requirement and the entire data-safety posture (collection = Yes) flip and must be re-done. Flag this as a v2 dependency, not a v1 task.

---

### 7. Play Console readiness checklist

Ordered; each item is a Play Console field/gate. `[iOS✓]` = artifact/decision already produced for the App Store and reused.

**App content / declarations**
- [ ] Data-safety form completed: "No data collected / No data shared" (§1).
- [ ] Data-safety privacy-policy link = https://squirl.pt/privacy. `[iOS✓ policy]`
- [ ] **Health apps declaration** completed: Yes → Medication & Treatment Management (+ mental-wellbeing) (§2). *No iOS analogue — net-new.*
- [ ] Health-vs-data-safety consistency note written for reviewers (features = health; data transmitted = none) (§2).
- [ ] App-content Privacy policy URL field = https://squirl.pt/privacy. `[iOS✓]`
- [ ] Policy edited to generalize the model-download / STT sentence for the Android engine (§3).
- [ ] Ads declaration = **contains no ads** (no ad SDKs).
- [ ] Content rating questionnaire (IARC) completed — declare no ads, no UGC-sharing, medication/health-info content answered truthfully.
- [ ] Target audience & content = adult/general wellbeing; **not** "designed for children" (avoids Families policy + stricter data rules).
- [ ] Government / financial / health-app-specific policy forms: confirm none beyond the Health declaration apply (no clinical claims, no prescriptions, no telehealth).
- [ ] Data-deletion / account-deletion: **N/A** — recorded as no-account, no-server (§6).
- [ ] App access: provide reviewer instructions — no login required; all features reachable without credentials.
- [ ] Permissions justification: `RECORD_AUDIO` + `FOREGROUND_SERVICE_MICROPHONE` (foreground-service-type `microphone`, Android 14+) explained as core check-in recording; INTERNET used only for one-time model download.

**Build / technical gates**
- [ ] `minSdk = 28`, `targetSdk = 36` set in the release build (§4).
- [ ] Release AAB every `.so` 16 KB-aligned — `check_elf_alignment.sh` all `ALIGNED (16384)` incl. STT libs (§5).
- [ ] App signing enrolled (Play App Signing / upload key configured).
- [ ] Install-time asset pack (STT model) within Play size limits — model ≤ base/pack caps ([ANDROID_PORT_PLAN.md](ANDROID_PORT_PLAN.md#L37)).

**Store listing**
- [ ] Store listing text, screenshots, feature graphic, app icon.
- [ ] Support email = caesar915@icloud.com (matches iOS + policy — [SUBMISSION.md](app-store/SUBMISSION.md#L19)). `[iOS✓]`
- [ ] Support/website URL = https://squirl.pt. `[iOS✓]`

**Closed-testing gate (the schedule-critical one)**
- [ ] Closed-testing track created; ≥ **12 testers** enrolled and opted in.
- [ ] Testers held **opted-in for ≥ 14 consecutive days** before applying for production (§8 risk — start this early).
- [ ] Production-access application submitted after the 14-day window; allow up to ~7 days Google review.

---

### 8. Exit criteria (binary)

P3-D is **green** only if ALL hold:
1. Data-safety form submitted with "No data collected / No data shared" + privacy-policy link accepted by Play Console (no "declaration incomplete" flag).
2. Health apps declaration submitted (Medication management + mental-wellbeing) with no outstanding "action required."
3. Privacy policy live at https://squirl.pt/privacy and generalized to accurately describe the Android binary's on-device STT + one-time model download.
4. Release AAB built at `minSdk 28` / `targetSdk 36`; `check_elf_alignment.sh` reports `ALIGNED (16384)` for **every** `.so` (including STT engine libs).
5. Account-deletion requirement formally recorded as N/A (no-account/no-server) — no phantom deletion URL declared.
6. Closed-testing track has ≥ 12 testers opted in for ≥ 14 consecutive days, and production access has been granted (or the application is accepted and pending only Google's ≤ 7-day review).
7. Content rating, ads (none), target-audience, app-access, and permissions declarations all completed and submittable with no blocking policy warning in Play Console's "Publishing overview."

Anything short of all seven = not green; document what's outstanding and the blocker.

---

### 9. Risks & effort

| Risk | Impact | Mitigation |
|---|---|---|
| **Closed-testing 14-day wall.** Personal accounts created after 2023-11-13 need 12 testers opted-in **14 consecutive days** before production; opt-outs reset the clock (https://support.google.com/googleplay/android-developer/answer/14151465). | Adds **≥14 days of calendar latency** to first production release regardless of code readiness — the critical-path item of the whole Phase 3. | Start recruiting + enrolling 12 testers on **day 1 of Phase 3**, in parallel with hardening. Over-recruit (14–15) to absorb drop-outs. Confirm account creation date; if it's a pre-2023-11-13 or an Organization account, this may not apply — verify in console first. |
| **Health declaration over/under-claim.** Wrong feature set → stricter review lane or an inaccurate-declaration flag. | Delayed/blocked review. | Select only Medication-management + mood/mental-wellbeing; add the "personal journaling, not medical advice" note; lean on the existing in-app disclaimer posture. |
| **Data-safety vs Health-declaration inconsistency.** Reviewer sees "health features: yes" + "health data: none." | Manual-review friction. | Pre-write the reconciliation note (features ≠ transmission) into App-access reviewer instructions. |
| **STT `.so` 16 KB regression** on r27 prebuilts absent at P0.1. | Upload rejection at the last step. | Re-run alignment check on the *release* AAB with STT libs; keep it a CI gate; source aligned copies / re-link if any third-party `.so` is 4 KB. |
| **Policy drift** (Play changes wording/dates between now and execution). | Answers or dates stale. | Re-verify all five URLs at execution start (they change); this doc's claims are stamped 2026-07-22. |
| **Model download read as undisclosed collection.** | Data-safety mismatch. | Explicitly document the one-time, no-PII model download in reviewer notes + policy. |

**Effort:** ~**2–3 engineer-days** of actual console/paperwork work (data-safety + health declaration + content rating + listing + release-config + final 16 KB re-verify), most of it reusing iOS artifacts. **But wall-clock is gated at ~3+ weeks** by the closed-testing 14-consecutive-day requirement + up to 7-day production review — this is scheduling latency, not effort, and it is why tester recruitment must begin at the very start of Phase 3, not at the end. This mirrors the iOS readiness the project already executed ([SUBMISSION.md](app-store/SUBMISSION.md)); the genuinely new surfaces are the **Health apps declaration** and the **closed-testing tester gate** — neither exists on the App Store side.

---

### Cross-phase dependencies & assumptions

**Depends on (upstream):**
- **P0.1 (Toolchain / 16 KB primary gate)** — P3-D's §5 is a *re-verify*; if P0.1's alignment gate wasn't made a CI gate, P3-D inherits the full alignment engineering, not a checkbox. targetSdk 36 must already be pinned in the P0.1 scaffold ([ANDROID_PHASE0.md](ANDROID_PHASE0.md#L295)).
- **P0.2 (STT winner)** — determines which native `.so`s and which model host exist, driving both the §5 re-verify surface and the §3 policy wording (engine/CDN named). Asset-pack size posture also set here.
- **Phase 1 step 4 / Phase 2 step 5 (audio + STT integration)** — establishes the `RECORD_AUDIO` + `FOREGROUND_SERVICE_MICROPHONE` permission set that P3-D must justify in the console.
- **Existing iOS App Store readiness** — the live privacy policy, support email, "no data collected" audit, and disclaimer posture are reused directly ([SUBMISSION.md](app-store/SUBMISSION.md), [PRIVACY_POLICY.md](app-store/PRIVACY_POLICY.md)).

**Feeds (downstream):** production release is the terminal Phase 3 milestone; nothing in the port is scheduled after it for v1.

**Assumptions:**
- The developer account is a **personal** account created **after 2023-11-13** ⇒ the 12-tester / 14-day rule applies (worst case; verify — an org account or older personal account may be exempt). Verified rule: https://support.google.com/googleplay/android-developer/answer/14151465.
- Android v1 remains **standalone, local-only, no account, no sync** ([ANDROID_PORT_PLAN.md](ANDROID_PORT_PLAN.md#L6-L9)). If sync (038) enters scope, data-safety flips to "collected = Yes" and account-deletion becomes mandatory — a full re-do, flagged as v2.
- No ads, no third-party SDKs, no children-directed targeting — all three keep the app out of Play's heavier policy lanes.
- Play policy text/dates are stable as verified **2026-07-22**; re-verify the five source URLs at execution start.

**External sources (all verified live 2026-07-22):**
- Data safety form — https://support.google.com/googleplay/android-developer/answer/10787469
- Health apps declaration — https://support.google.com/googleplay/android-developer/answer/14738291
- Target API level requirement (targetSdk 36 from 2026-08-31; extension to 2026-11-01) — https://developer.android.com/google/play/requirements/target-sdk
- Closed testing: 12 testers / 14 consecutive days (personal accounts post 2023-11-13) — https://support.google.com/googleplay/android-developer/answer/14151465
- 16 KB page-size requirement (API 35+, from 2025-11-01) — https://developer.android.com/guide/practices/page-sizes
- Account/data deletion (applies only to apps with accounts) — https://support.google.com/googleplay/android-developer/answer/13327111

---

## P3-E — Release engineering & beta ops

*Workstream owner: release/DevOps. Scope: everything from a green Phase-2 build to a stable closed-beta channel on Google Play. Solo dev + agent; PRs are a review surface, `main` stays releasable (CLAUDE.md §Git Workflow). This section defines the Android analogue of the iOS TestFlight discipline, not a re-derivation of the port itself.*

### Goal

Stand up a **repeatable, signed, tagged AAB pipeline** that puts a build on a Google Play **closed-testing track** in front of **≥12 real testers (recruit 14–16 for dropout slack)**, with crash/ANR telemetry (Play Vitals) and a triage loop feeding back into the backlog — while satisfying the Play policy gate (12 testers / 14 consecutive days) that P3-D owns. Exit = a build the owner can promote toward production with confidence, on a channel that mirrors the iOS "stable TestFlight + `git tag`" release rhythm already codified for the iOS app (stable-testflight-channel-plan (memory note), IMPLEMENTED on `main` per PR#26).

The discipline being ported, not the tech:
- **iOS today:** stable channel + `git tag v1.0.0` on every TestFlight upload, so a tester's exact build is recoverable (CLAUDE.md §Git Workflow: *"When a commit on `main` is uploaded to TestFlight, tag it (`git tag v0.1.0`) so a tester's exact build is recoverable."*).
- **Android target:** identical rule, one channel over — tag the commit uploaded to a Play track.

---

### AAB build + Play App Signing (real config)

**Publishing format is non-negotiable: AAB.** *"From August 2021, new apps are required to publish with the Android App Bundle on Google Play"* (https://developer.android.com/guide/app-bundle). Google Play generates and serves per-device-optimized split APKs from the bundle; we never assemble/sign production APKs ourselves. This is also why the P0.2 model-delivery decision (asset pack for Parakeet ≈640 MB > 500 MB base cap — ANDROID_PORT_PLAN.md:37) is a *bundle* concern, not an APK one — the release pipeline must `bundle`, never `assemble`, for anything Play-bound.

**Two-key model (Play App Signing).** Google holds the long-lived **app signing key** and re-signs every upload; we sign locally with a replaceable **upload key** that only authenticates the upload (https://support.google.com/googleplay/android-developer/answer/9842756). Consequences for our pipeline:
- The upload key is **rotatable** — if the CI secret leaks, we reset it in Play Console without breaking installed users (the app signing key is unchanged). This is the Android equivalent of iOS's Apple-managed distribution certificate: the identity that matters is not on our disk.
- Enroll in Play App Signing at first upload; record the app signing key's SHA-256 (needed later for any deep-link/asset-links or attestation work — out of v1 scope but note it).

**Generate the upload key once** (kept in CI secret store, never in the repo):

```bash
keytool -genkeypair -v \
  -keystore upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 9125 \
  -alias upload \
  -storetype JKS
```

**Gradle release signing** — `app/build.gradle.kts`, credentials injected from env (CI) or `~/.gradle/gradle.properties` (local), never hard-coded:

```kotlin
android {
    signingConfigs {
        create("release") {
            storeFile = file(System.getenv("UPLOAD_KEYSTORE_PATH") ?: providers.gradleProperty("uploadKeystorePath").get())
            storePassword = System.getenv("UPLOAD_STORE_PASSWORD") ?: providers.gradleProperty("uploadStorePassword").get()
            keyAlias = System.getenv("UPLOAD_KEY_ALIAS") ?: "upload"
            keyPassword = System.getenv("UPLOAD_KEY_PASSWORD") ?: providers.gradleProperty("uploadKeyPassword").get()
            enableV1Signing = false          // Play App Signing re-signs; v2/v3 scheme only
            enableV2Signing = true
        }
    }
    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
        }
    }
    // 16 KB packaging + jniLibs dedup carried from P0.1 (ANDROID_PHASE0.md §3.7):
    packaging { jniLibs { pickFirsts += listOf("**/libc++_shared.so") } }
    defaultConfig { minSdk = 28; targetSdk = 36 }
}
```

**Build the signed bundle:**

```bash
./gradlew :app:bundleRelease
# → app/build/outputs/bundle/release/app-release.aab  (upload-key signed)
```

**Local pre-upload verification with `bundletool`** (https://developer.android.com/tools/bundletool, https://developer.android.com/guide/app-bundle/test). Google's servers do the real split generation, but we replicate a device-specific install locally to catch packaging breakage before burning an upload:

```bash
# Build the exact split set Play would serve to the connected device, then install it.
java -jar bundletool-all.jar build-apks \
  --bundle=app/build/outputs/bundle/release/app-release.aab \
  --output=app-release.apks \
  --connected-device \
  --ks=upload-keystore.jks --ks-key-alias=upload   # sign the local test APKs

java -jar bundletool-all.jar install-apks --apks=app-release.apks
```

- `--connected-device` makes `bundletool` query `adb` for the device spec and emit only the splits that device would receive — the closest local proxy to what Play delivers.
- For the **asset-pack model path** (P0.2 winner if Parakeet), add `--local-testing` to `build-apks` and install via `install-apks` so the install-time pack is pushed to device local storage exactly as Play would stage it (https://developer.android.com/guide/app-bundle/test). This is the only local way to exercise the model-delivery path before it hits a track.
- **Re-run the P0.1 16 KB alignment gate on the AAB's `.so`s here** (ANDROID_PHASE0.md §4) — the AAB build is the last chokepoint before upload; a mis-aligned `libc++_shared.so`/`libSwiftCore.so` is a hard upload rejection.

**Ties to P1-B CI.** The Phase-1 CI job already cross-compiles the Swift core and assembles a debug APK on every push (ANDROID_PORT_PLAN.md:31). P3-E extends that job with a **release lane**, gated to run only on a tag push:
1. `bundleRelease` with upload-key secrets from the CI secret store.
2. `check_elf_alignment.sh` on the AAB `.so`s (fail-the-build gate — carried from P0.1 §6).
3. Upload to the closed track via the Google Play Developer API / `gradle-play-publisher` or `fastlane supply`, `track = closed-<name>`, `status = draft` (owner promotes manually — never auto-publish, mirrors the iOS "I approve/merge" rule).
4. Emit the `bundletool` `--connected-device` set as a CI artifact for the owner's device QA.

---

### Versioning / tagging discipline (mirror the iOS git-tag rule)

The iOS rule is: a commit uploaded to TestFlight gets a `git tag` so the tester's exact build is recoverable (CLAUDE.md §Git Workflow). Port it verbatim, one channel over.

| Concern | iOS today | Android (P3-E) |
|---|---|---|
| Human version | `CFBundleShortVersionString` (e.g. `1.0`) | `versionName = "1.0"` |
| Machine build number | `CFBundleVersion` (monotonic) | `versionCode` (monotonic **Int**, Play rejects a re-used or lower code) |
| Channel | stable TestFlight | Play **closed-testing** track |
| Recoverability | `git tag v1.0.0` on upload | `git tag android-v1.0.0-beta.1` on upload |

**Rules:**
- `versionCode` is the single source of upload identity — **strictly increasing, never reused.** Derive it deterministically in CI (e.g. from the tag, or a monotonic counter), so a re-run of the same tag produces the same code and a rebuild is byte-reproducible in intent.
- **Tag every commit uploaded to a Play track**, prefixed `android-` to keep the iOS and Android tag namespaces disjoint in the shared monorepo: `android-v<versionName>-beta.<n>`. The tag is what makes a tester's crash report traceable to an exact tree.
- **CI release lane fires on the tag, not on merge to `main`** — pushing `android-v1.0.0-beta.2` is the deliberate "cut a beta" act, exactly as an iOS TestFlight upload is today. `main` merges alone never ship.
- Record in the tag annotation (or a `WORKLOG` block per CLAUDE.md §Process): `versionCode`, `versionName`, Swift/SDK/NDK pins (ANDROID_PHASE0.md §2 — toolchain is part of the build identity here because there's no platform owner), model+hash shipped, and the closed-track release name.
- One tag = one revertable beta, mirroring the iOS "one PR = one revertable feature" invariant (CLAUDE.md §Git Workflow).

---

### Closed-testing track ops (tester invite, 14-day clock, staged rollout)

**Track ladder (use all three, in order):**
1. **Internal testing** — up to 100 testers, no Play review, near-instant availability. This is the **inner loop**: every tagged beta lands here first for the owner + agent smoke pass. No 14-day clock, no policy gate. This is the true TestFlight analogue for speed.
2. **Closed testing** — custom-named track, manually created; *"To create a release on an existing closed testing track, select Manage track"* (https://support.google.com/googleplay/android-developer/answer/9859348). This is where the **≥12 external testers (recruit 14–16)** and the **policy clock** live.
3. Production — out of P3 scope; the closed beta is the P3 deliverable.

**Inviting testers** (https://support.google.com/googleplay/android-developer/answer/9845334):
- Add testers by email list or Google Group (a Group is strongly preferred at this size — you add/remove without editing the track, and the opt-in count is auditable).
- Each tester **must click the opt-in URL and accept** before they receive builds — being on the list is not being opted in. The 14-day clock only counts *opted-in* testers.
- Target **12+ testers, not "~10"** — the policy floor is 12 and the plan's earlier "~10" was corrected in ANDROID_PORT_PLAN.md:45. Recruit ≥14 to absorb dropouts (see 14-day clock).

**The 14-day clock (P3-D owns the policy; P3-E owns keeping it running).** For personal developer accounts created after 2023-11-13: *"At least 12 testers must be opted-in to your closed test when you apply for production access. They must have been opted-in for the last 14 days continuously"* (https://support.google.com/googleplay/android-developer/answer/14151465). Critically: *"these 14 days must be consecutive… we won't count testers who opted in, tested for less than 14 days, and then opted out."* Ops implications:
- **A tester opting out mid-window resets *their* clock to zero** — even re-opting in doesn't restore continuity. This is the single biggest schedule risk in P3.
- **Over-recruit and monitor daily.** Keep a running count of testers who have been continuously opted-in ≥14 days; the beta cannot end until ≥12 clear that bar. Recruiting 14–16 gives slack for 2–4 dropouts.
- **Start the clock the moment the first closed build is live** — the 14 days run in parallel with hardening QA, not after it. Cutting the first closed-track beta early (even a rough build) is the schedule-critical move; polish lands in later betas on the same track without resetting the clock.
- The clock is a *tester-continuity* property, not a *build* property — pushing new betas does not reset it, so ship freely within the window.

**Beta recovery is roll-forward, not rollback.** A closed-track release cannot be un-published and a tester already holds the bad APK — so on a build that bricks the core loop, immediately cut `android-v<ver>-beta.<n+1>` with a **higher `versionCode`** (halt the bad release's rollout if it was staged) and message the Google Group to prevent frustrated opt-outs (which reset the 14-day clock). "One tag = one revertable beta" is a git property, not a Play-track one.

**Staged rollout.** *"Staged rollouts can only be used for app updates, not when publishing an app for the first time"* and *"won't increase automatically; you must… click the Update rollout button and select a new percentage"* (https://support.google.com/googleplay/android-developer/answer/6346149). For a closed beta of ~12 people staged rollout is largely moot (the cohort is tiny), but the **discipline matters for the eventual production cutover**: first production release is 100%-to-a-small-cohort by definition; subsequent updates go 5% → 20% → 50% → 100%, each step gated on Vitals staying under threshold, **halt-and-fix** on regression. Note this as the production playbook; do not attempt staged % inside the closed beta.

---

### Play Vitals crash/ANR monitoring + pre-launch report

**Play Vitals** is the zero-instrumentation crash/ANR telemetry we get for free once builds are on any track (https://developer.android.com/topic/performance/vitals). It is the Android analogue of iOS Organizer crashes/MetricKit — no SDK to add. The two **core vitals** that gate store visibility are **user-perceived crash rate** and **user-perceived ANR rate** (https://support.google.com/googleplay/android-developer/answer/9844486).

**Bad-behavior thresholds (the numbers we must stay under):**

| Metric | Overall threshold (all devices) | Per-device threshold |
|---|---|---|
| User-perceived **crash** rate | ≥ **1.09%** of DAU with a user-perceived crash | ≥ **8%** on a single device model |
| User-perceived **ANR** rate | ≥ **0.47%** of DAU with a user-perceived ANR | ≥ **8%** on a single device model |

Source: https://support.google.com/googleplay/android-developer/answer/9844486. Exceeding a threshold means *"Play may reduce the visibility of your title and may also show users a warning on your store listing"* — a store-ranking penalty, not just a dashboard color. Definitions: crash detail at https://developer.android.com/topic/performance/vitals/crash, ANR detail at https://developer.android.com/topic/performance/vitals/anr.

**Why this matters for *this* app specifically:** the STT path is the ANR risk. A synchronous transcribe on the main thread, or the model-load blocking UI, is exactly what trips the 5-second ANR detector. P3's thermal/battery guardrails (ANDROID_PORT_PLAN.md:43) and the audited JNI bridge standard (`_with_params`, mutex-guarded handle, errors thrown not swallowed — ANDROID_PORT_PLAN.md:37) are what keep us under the 0.47% ANR floor. Vitals is where we *prove* it during the beta.

**Beta-cohort caveat:** at ~12 testers the DAU denominator is tiny, so rates are noisy and Vitals will show low confidence — a single crash is a huge percentage. Treat closed-beta Vitals as **presence/absence of a class of bug**, not as a rate to compare against the thresholds. The thresholds become meaningful only at production scale; in beta, *any* crash/ANR cluster is triaged regardless of the computed rate.

**Pre-launch report (PLR).** Auto-generated on every upload to internal/closed/open testing: Firebase Test Lab crawls the build for a few minutes across a range of real devices (Android 9+, high-end to low-end), tapping/typing/swiping (https://support.google.com/googleplay/android-developer/answer/9842757). It surfaces crashes, ANRs, accessibility, security, and performance issues **before any human tester touches the build** — a free first-pass QA on device diversity we cannot otherwise afford solo. Ops:
- **Read the auto-generated PLR on the first closed-track upload of each beta**, especially the crash/stability and accessibility sections (the latter backstops the P3 TalkBack pass, ANDROID_PORT_PLAN.md:43).
- The app has **no login wall**, so no PLR test-credential config is needed — the crawler reaches the core loop unaided. (Confirm the RECORD_AUDIO permission prompt doesn't dead-end the crawler; if it does, the crawl still reports the reachable surface.)
- PLR device diversity is *complementary* to our single-device mid-tier P0.2 target — it catches ABI/OEM-specific `.so`/16 KB load failures our one test device would miss.

---

### Beta feedback → triage loop

Small-N, high-touch — matching the solo-dev reality. No heavyweight tooling.

1. **Channels in:** (a) Play Console **crash/ANR clusters** (Vitals, stack-trace grouped), (b) **PLR** findings per upload, (c) tester **feedback** — for closed tracks, testers submit via the opt-in web page's feedback form / email; funnel all human feedback to one address or Google Group thread.
2. **Triage cadence:** review Vitals + new PLR after each beta upload; sweep tester feedback at a fixed cadence (e.g. per beta). Each item is classified: **crash/ANR (P0)** → fix before next beta; **core-loop bug (P1)** → next beta; **polish/UX (P2)** → BACKLOG (`docs/BACKLOG.md`, the single registry per CLAUDE.md §Backlog).
3. **From report to tree:** every Vitals crash carries the `versionCode`; map it via the git tag (versioning section) back to the exact commit — this is the entire point of the tagging discipline. No "which build was that?" ambiguity.
4. **Fix path obeys the repo rules:** fix on a `fix/…` branch off `main`, `/code-review` before merge, owner device QA before merge (CLAUDE.md §Git Workflow — device QA is non-negotiable), then a new tagged beta re-enters the loop. `main` stays releasable throughout.
5. **Log the *why* to DEVLOG, the *what* to WORKLOG** at each beta cut (CLAUDE.md §Process) so the beta history reconciles with `git tag`/`gh` exactly.

---

### Go-live checklist (closed beta)

Binary items, run per beta cut unless marked once:

- [ ] **(once)** Play App Signing enrolled; upload key generated, stored in CI secret store, **not** in repo.
- [ ] **(once)** Closed-testing track created; Google Group of ≥14 testers attached; opt-in URL distributed.
- [ ] `versionCode` strictly greater than the last uploaded code; `versionName` set.
- [ ] Signed **AAB** built via `bundleRelease` (not `assemble`).
- [ ] 16 KB alignment gate GREEN on every `.so` in the AAB (`check_elf_alignment.sh`).
- [ ] `bundletool --connected-device` (+ `--local-testing` if asset-pack model) installs and the core loop runs on a real mid-tier device.
- [ ] Data-safety form + privacy-policy link submitted; **Health apps declaration** completed (mandatory, cannot tick "none" — ANDROID_PORT_PLAN.md:45).
- [ ] `targetSdk 36`, `minSdk 28` confirmed in the built bundle.
- [ ] Commit tagged `android-v<versionName>-beta.<n>`; tag annotation records versionCode + toolchain pins + model hash.
- [ ] Uploaded to closed track as **draft**; owner reviews PLR before promoting to testers.
- [ ] PLR read (crash/stability + accessibility sections); no new P0.
- [ ] Vitals dashboard checked for the prior beta; no unresolved crash/ANR cluster carried forward.

---

### Exit criteria (binary)

P3-E is **done** when all hold:

1. A **signed AAB** is produced by the CI release lane from a **tagged** commit, with the 16 KB gate GREEN, and installs+runs the core loop on a real mid-tier device via `bundletool --connected-device`.
2. That build is **live on a Play closed-testing track**, distributed to ≥12 opted-in external testers.
3. The **14-consecutive-day opt-in clock** is running and monitored, with a daily-updated count of testers who have cleared ≥14 continuous days (target ≥12; P3-D scores the policy pass).
4. **Play Vitals** is being read after each upload and the **PLR** (auto-generated) is read per upload; a documented **triage loop** routes crash/ANR/feedback to `fix/…` branches or BACKLOG.
5. The **versioning/tagging rule** is codified (every track upload tagged `android-v*`, `versionCode` monotonic) — the Android mirror of the iOS `git tag` rule is in force, not aspirational.

Not required for P3-E exit: production release, staged-rollout %, >12 testers, multi-language beyond the STT-validated set.

---

### Risks & effort

**Effort:** ~3–4 engineer-days of *setup* (keystore + Play App Signing enrollment, CI release lane, first track + tester group, PLR/Vitals wiring), then **14+ calendar days of clock time** that runs in parallel with the rest of Phase-3 hardening. The critical path is calendar, not effort — cut the first closed beta as early in Phase 3 as a runnable build allows.

| Risk | Impact | Mitigation |
|---|---|---|
| **Tester attrition breaks the 14-day continuity.** A single mid-window opt-out resets that tester's clock; too many and the policy gate can't be met on schedule. | Slips production access by up to another 14 days. | Over-recruit to 14–16; use a Google Group for auditable opt-in state; monitor the continuous-opt-in count daily; start the clock on the *first* runnable closed build, not the polished one. |
| **Upload-key secret handling in CI.** Leaked keystore = someone can sign uploads as us (though Play App Signing caps the blast radius — the app signing key is Google's). | Beta channel compromise; forced key reset. | Keystore in CI secret store only, never repo; upload key is *rotatable* by design (reset in Play Console) — the recoverable-by-design property is the mitigation. |
| **Vitals thresholds misapplied at beta scale.** ~12-tester DAU makes crash/ANR rates statistically meaningless vs the 1.09%/0.47% floors. | Either false alarm or false confidence. | Treat beta Vitals as presence/absence of a bug *class*, not a rate; the thresholds gate production, not the closed beta; any cluster is triaged regardless of computed %. |
| **STT-driven ANR.** Main-thread transcribe or blocking model-load trips the 5 s ANR detector; ANR floor (0.47%) is 2× stricter than crash. | Store-visibility penalty at production; failed beta. | Enforce the audited JNI bridge standard + thermal guardrails (ANDROID_PORT_PLAN.md:37,43); watch the ANR pane specifically during beta; PLR crawl is a free early ANR probe. |
| **First-release staged-rollout confusion.** Staged % is unavailable for a first publish; assuming otherwise breaks the production cutover plan. | Botched production launch. | Documented above: first prod release is not staged; 5→20→50→100 begins at the *first update*. Closed beta never uses staged %. |
| **AAB/asset-pack path untested until upload.** The model-delivery (Parakeet install-time pack) path only fully exercises through Play. | Late-breaking install failure on real devices. | `bundletool --local-testing` replicates asset-pack staging locally before every upload; PLR's device diversity catches OEM-specific load failures our single device misses. |

---

### Cross-phase dependencies & assumptions

**Depends on (upstream):**
- **P0.1 (toolchain/16 KB)** — the AAB build inherits the 16 KB alignment gate and `jniLibs.pickFirsts` dedup verbatim (ANDROID_PHASE0.md §3.7, §4). P3-E adds no new alignment logic; it *re-runs the same gate on the release AAB* as the last chokepoint before upload. If P0.1 is red, there is nothing to release.
- **P0.2 (STT winner + model size)** — decides whether the release bundle carries a 264 MB q8_0 model in-base or a ≈640 MB Parakeet **install-time asset pack** (ANDROID_PORT_PLAN.md:37, 25); that choice changes the `bundletool` local-test invocation (`--local-testing`) and the go-live checklist. P3-E assumes the winner is known.
- **P1-B (CI: cross-compile + debug APK on push, ANDROID_PORT_PLAN.md:31)** — P3-E extends this exact job with a tag-gated release lane; it does not stand up new CI infrastructure.
- **P3-D (Play policy / data-safety / Health declaration / 12-tester-14-day *policy*)** — P3-E runs the *ops* of the closed track (invites, clock monitoring, uploads); P3-D owns the *policy compliance* (the declarations, the production-access application). The two share the closed track; keep the boundary explicit: P3-E keeps testers opted-in, P3-D scores whether the gate is met.
- **Phase-2 (working core loop)** — nothing ships to a track until record→transcribe→extract→journal→calendar→detail→settings runs (ANDROID_PORT_PLAN.md:9). P3-E is a channel, not a feature.

**Feeds (downstream):**
- Production rollout (post-P3, out of scope): the staged-rollout playbook, the tagging discipline, and the Vitals-threshold gates defined here are the production cutover's inputs.
- The beta triage loop feeds `docs/BACKLOG.md` (P2 polish) and `fix/…` branches (P0/P1), closing back into the standard repo workflow.

**Assumptions:**
1. **Personal (not organization) Google Play developer account created after 2023-11-13** — this is what triggers the 12-tester/14-day gate (https://support.google.com/googleplay/android-developer/answer/14151465). If the account predates 2023-11-13 or is an org account, the gate may not apply and the closed-beta clock is advisory only — **verify the account's creation date and type before scheduling the beta**, as it moves the critical path by up to 14 days.
2. **≥12 (recruit ≥14–16) real testers sourced *before* day 1** — solo-dev + iOS-only-to-date means no proven Android audience, so recruitment is a real risk with its own lead time (Google-Group opt-in is not instant). Named channels: existing iOS TestFlight users willing to switch/dual-run on Android, ADHD/journaling communities, personal network, and a landing-page waitlist tied to the "Android demand signal post-1.0" recommendation (ANDROID_PORT_PLAN.md:55). Target ≥14 opted-in by the first closed build; pull recruitment ahead of Phase-3 day 1.
3. **iOS discipline is the template** — the stable-channel + `git tag`-on-upload rule is already live for iOS (CLAUDE.md §Git Workflow; stable-testflight-channel-plan memory / PR#26); P3-E ports the *rule*, assuming the owner wants channel/tag parity across platforms.
4. **`versionCode` derivation is deterministic in CI** — assumed available from the tag; if not, a monotonic counter must be provisioned (minor, but a prerequisite for reproducible uploads).
5. Sync, widgets, App Intents, and a TestFlight-style *stable* second channel are **out of Android v1 scope** (ANDROID_PORT_PLAN.md:8) — the Android beta is a single closed channel, not the two-channel (stable/beta) iOS arrangement.

<!--
Sourcing:
- AAB required format + APK generation: https://developer.android.com/guide/app-bundle
- bundletool build-apks/install-apks/--connected-device/--local-testing: https://developer.android.com/tools/bundletool , https://developer.android.com/guide/app-bundle/test
- Play App Signing (upload key vs app signing key, rotatable upload key): https://support.google.com/googleplay/android-developer/answer/9842756
- Sign your app / signingConfigs: https://developer.android.com/studio/publish/app-signing
- Closed testing 12 testers / 14 consecutive days (personal accts post-2023-11-13): https://support.google.com/googleplay/android-developer/answer/14151465
- Set up internal/closed/open test (tester invites, opt-in): https://support.google.com/googleplay/android-developer/answer/9845334
- Prepare and roll out a release / Manage track: https://support.google.com/googleplay/android-developer/answer/9859348
- Staged rollout (updates only, manual increase): https://support.google.com/googleplay/android-developer/answer/6346149
- Android vitals overview + core vitals + bad-behavior thresholds (crash 1.09%/8%, ANR 0.47%/8%): https://support.google.com/googleplay/android-developer/answer/9844486
- Vitals crash detail: https://developer.android.com/topic/performance/vitals/crash ; ANR detail: https://developer.android.com/topic/performance/vitals/anr ; overview: https://developer.android.com/topic/performance/vitals
- Pre-launch report (Firebase Test Lab crawler, device range, opt-in): https://support.google.com/googleplay/android-developer/answer/9842757
Repo/plan refs: ANDROID_PORT_PLAN.md lines 8,9,25,31,37,43,45,55 ; ANDROID_PHASE0.md §2,§3.7,§4,§6 ; CLAUDE.md §Git Workflow, §Process, §Backlog.
-->

---

## Consolidated risks & sequencing

### Intra-phase order

Phase 3 is not a linear pipeline — it is one engineering track (P3-A, P3-B, P3-C) running **in parallel** with a paperwork/ops track (P3-D, P3-E), because the binding constraint is a **calendar clock, not an effort sum** (see below). Recommended sequence:

1. **Day 1 (non-negotiable, parallel):** stand up the P3-E signed-AAB release lane far enough to cut a *runnable* closed-track build, and **begin tester recruitment** (P3-D policy + P3-E ops). Cutting the first closed beta early — even a rough build — starts the 14-consecutive-day clock immediately; every day of delay here is a day added to the end of Phase 3. Because a **closed**-track rollout requires the publish-blocking App-Content declarations to be *accepted* first (Data safety + Health apps declaration + Content rating + Target audience + Privacy-policy URL), treat that minimum declaration set as a **day-0/day-1 blocker**, not in-window paperwork — the 14-day clock cannot begin until they clear. (Alternatively: publish to *internal* testing day 1 for the smoke loop, and flip to *closed* the moment the declarations are accepted — only the closed go-live starts the clock.)
2. **Week 1–2 (engineering):** P3-A resilience and P3-C test authoring proceed together. **Write the P3-A audio-durability property test first (TDD)** — it is the highest-value item and guards the single non-negotiable ("never lose the user's recording"). P3-C layers 2–4 are authored against the Phase-1/2 code as it stabilizes.
3. **After Phase-2 UI is stable:** P3-B accessibility runs (it needs the screens to exist) and **reuses P0.3's per-screen `ComposeView` boundary** — the same boundary the glyph-fidelity fallbacks and the three SkipUI a11y-gap fallbacks all share, so scope overlaps deliberately.
4. **Day-1 blocking subset, then anytime in-window:** the publish-gating declarations (data-safety, Health declaration, content rating, target audience, privacy-policy URL) must be **accepted before the first closed release** — they gate clock-start; the remainder of P3-D's ~2–3 eng-days (listing, release-config, final re-verify) is in-window.
5. **End-of-phase gates:** P3-D's **final 16 KB re-verify on the release AAB** (STT libs now present) → P3-E promotes the build to the closed track → the P3-C **on-device smoke checklist (owner-signed)** is the release gate before each beta cut. Production access is applied for once the 14-day window clears.

### The wall-clock gate — the closed-testing clock

**The critical path of Phase 3 is not engineering effort — it is the 12-tester / 14-consecutive-day closed-testing clock.** For a personal Google Play developer account created after **2023-11-13**, at least **12 testers must be opted-in for 14 continuous days** before production access can be applied for, and a mid-window opt-out **resets that tester's clock to zero** (https://support.google.com/googleplay/android-developer/answer/14151465, verified 2026-07-22). On top of the 14 days sits **up to ~7 days of Google production review**. Policy is owned by **P3-D §9**; the running of the clock is owned by **P3-E**.

Operational consequences (must be honored or Phase 3 cannot finish in 3 weeks):
- **Start recruitment on day 1** and cut the first closed build as soon as one is runnable — the 14 days run *in parallel* with hardening QA, not after it.
- **Over-recruit to 14–16** to absorb 2–4 dropouts; use a Google Group for auditable opt-in state; **monitor the continuous-opt-in count daily**.
- **Verify the account first:** if it predates 2023-11-13 or is an organization account, the gate may not apply and the clock is advisory — this single fact moves the critical path by up to 14 days.
- Pushing new betas does **not** reset the clock (it is a tester-continuity property, not a build property), so ship freely within the window.

### Total effort vs wall-clock

**Engineering effort (sum of the five budgets): ~18–23 engineer-days.**

| Workstream | Eng-days | Nature |
|---|---|---|
| P3-A Resilience & edge states | ~5 (1 eng-week) | Engineering (thermal governor is the novelty) |
| P3-B Accessibility | ~4–5 (up to 7) | Engineering + on-device verification |
| P3-C Test strategy | ~4–6 net-new | Engineering (layer 1 inherited from P0.4) |
| P3-D Play compliance | ~2–3 | Console/paperwork (reuses iOS artifacts) |
| P3-E Release & beta ops | ~3–4 setup | DevOps setup |
| **Total** | **~18–23 eng-days** | |

**Wall-clock: a 3-week (≈15 working-day) window.** The eng-day sum exceeds a naive single-track 15-day span, which is exactly why the engineering (P3-A/B/C) and paperwork/ops (P3-D/E) tracks must run **concurrently** — feasible because console work and clock-monitoring overlap coding.

**The tester clock can exceed the eng-day sum in wall-clock terms.** The Play closed-testing gate alone is **14 consecutive calendar days + up to ~7 days review ≈ 21 calendar days** — more than the ~15 working days of engineering, and it cannot be compressed by adding effort. It is scheduling latency, not work. **If the first closed build is not cut on or near day 1, Phase 3 overruns 3 weeks regardless of engineering velocity** — the clock, not the code, is what closes the phase. Budget the phase as a **band, not 3 weeks flat: 3 weeks is the zero-dropout floor** (day-1 start, 14 consecutive days + up to 7-day review = ~21 calendar days with no margin); **plan 4–5 weeks with a realistic 1–2 tester-dropout allowance** (each mid-window opt-out adds up to 14 days). P3-D green (hence phase close) cannot occur before ~day 15 regardless of engineering velocity.

### Carried risks (assembled; verify at execution)

- **SkipUI accessibility gaps degrade the mirrored iOS AX posture (P3-B).** `.accessibilityHint` (~17 sites), `.accessibilityElement(children: .combine/.contain/.ignore)` (the app's most-used grouping modifier — every combined row/card), and `AccessibilityNotification.Announcement` (the check-in prompt-advance gate) are **unsupported by SkipUI** and each needs a per-screen `ComposeView` fallback (`onClickLabel` / `mergeDescendants` / `liveRegion`). Glyph a11y is **not** part of this gap set — per Phase 2 P2-D the glyphs are shared `Shape`s whose `SignalGlyph` modifiers map directly. If SkipUI merges nothing automatically, the grouping-fallback count is unknown until the Day-1 catalogue and P3-B can reach **6–7 eng-days**. Re-verify the four gap rows against the pinned Skip version at execution — an intervening release may close one.
- **The thermal guardrail rides the Phase-2 STT bridge (P3-A).** Abort rides P2-A's push-style `cancel()`/native-atomic seam (whisper's `abort_callback` polls it — ANDROID_PHASE2.md:260); on the sherpa branch there is **no mid-utterance abort** (single-shot decode — let it finish or unload, then defer the queue). `unloadModel()` exists on P2-A; **`isDecoding` is a net-new additive ask on P2-A**, with a documented pre-flight-only degraded fallback. The guardrail itself is **Android-original code with no iOS analogue to port** (iOS `thermalState` is diagnostic-only — no compute-abort exists in the iOS codebase).
- **`onTrimMemory` legacy levels are deprecated (P3-A).** From **Android 14 the system delivers only `TRIM_MEMORY_UI_HIDDEN` and `TRIM_MEMORY_BACKGROUND`**; the legacy `TRIM_MEMORY_RUNNING_*` / `_MODERATE` / `_COMPLETE` constants were formally deprecated in **Android 15**. The model-unload path must handle only the two delivered levels (plus a belt-and-braces `onLowMemory()`), never rely on the legacy `RUNNING_*` levels.
- **STT `.so` 16 KB regression at the last step (P3-D §5 / P3-E).** The release AAB carries native STT libs absent at P0.1 (whisper.cpp / sherpa-onnx prebuilts are a known r27 alignment risk). A single 4 KB-aligned `.so` is a Play upload rejection — re-run `check_elf_alignment.sh` on the *release* AAB and keep it a CI fail-the-build gate.
- **Persistence fork undecided until P0.3 (P3-C).** Room ⇒ Android-native JUnit/Robolectric DB tests; SkipSQL ⇒ those tests collapse into shared-core Swift Testing. **Do not author DB tests before P0.3 decides.**
- **Tester attrition (P3-E) and Health-vs-data-safety consistency (P3-D)** are the two paperwork-track risks: a mid-window opt-out resets the 14-day clock (mitigate by over-recruiting + daily monitoring), and a reviewer will read "health features: yes" (Health declaration) alongside "health data collected: none" (data-safety) — pre-write the reconciliation note (features ≠ transmission) into the App-access reviewer instructions.
