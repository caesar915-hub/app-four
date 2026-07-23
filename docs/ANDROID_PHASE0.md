<!-- Created: 2026-07-21 23:33 WEST · Updated: 2026-07-22 01:03 WEST -->
# Android Port — Phase 0 (De-risk Spikes) → Gate G0

**Scope.** This document expands **Phase 0** of [ANDROID_PORT_PLAN.md](ANDROID_PORT_PLAN.md) (v1.1) into four execution-ready spike specs. Nothing after **G0** is scheduled work until all four spikes pass. Phase 0 exists to resolve the two unknowns that can void the whole plan — **STT real-time factor on mid-tier hardware** and **SkipFuseUI fidelity** — plus toolchain viability and extractor parity, for ~12 engineer-days optimistic (14–16 realistic — see Consolidated) *before* any committed build-out.

**Provenance.** Every technical claim traces to a primary source verified 2026-07-21/22. Each section was drafted by a dedicated engineer-agent, then independently reviewed by an adversarial agent that re-verified claims against live docs/repo and applied corrections inline. A final whole-document pass (two independent reviewers + a merger, 2026-07-22) added the P0.2 pre-registration gate, the fixed med-recall statistical floor, and the on-device fixture-runner, and re-verified the swift.org support-tier claim live. Per-section `REVIEW NOTES` blocks (HTML comments at the end of each section) record the residual minor items. Sourcing standard: external claims carry an inline cited URL; repo claims carry `file:line`.

**Standing recommendation (from the plan):** the plan is execution-ready, but execution should start when there is an Android demand signal post-1.0. Phase 0 is cheap enough (~2 weeks) to run early as insurance if the team prefers.

---

## G0 gate — the four spikes at a glance

| Spike | Question it kills | Budget | Binary exit criterion | Failure ⇒ |
|---|---|---|---|---|
| **P0.1 Toolchain bring-up** | Can we ship Swift-on-Android through Play at all? | 2 d (3 d realistic) | "Hello from Swift" from an APK on a real API 28+ device; `libc++_shared.so` packaged once; **every `.so` 16 KB-aligned** | Port strategy changes fundamentally |
| **P0.2 STT bake-off** *(the go/no-go)* | Is on-device STT good enough AND fast enough on mid-tier? | 4 d | One engine: med-name recall clears the pre-registered statistical + point-estimate floor vs iOS-small (P0.2.0/P0.2.2) **AND** WER within the pre-registered delta **AND** batch RTF ≤ 1.0 **AND** no thermal abort over 5 check-ins | **★ PORT PARKED — plan ends ★** |
| **P0.3 Skip Fuse UI** | Does SkipFuseUI render Paper & Pollen acceptably? SkipSQL or Room? | 3 d | Check-in screen + one glyph navigable on device; every fidelity gap enumerated + assigned a fallback, none blocking; persistence fork decided | Surfaces leak from shared Swift → per-platform Compose (erodes Fuse's benefit) |
| **P0.4 Extractor portability** | Can the existing Swift extractor run byte-identical on Android? | 3 d | Golden-fixture suite GREEN on iOS `swift test` **and** the on-device Android fixture-runner with byte-identical output; every Apple-NL dep fenced + replaced | Byte-parity not a build property; Option B (rewrite) pressure returns |

**Gate rule:** all four green → Phase 1. **Any red → stop and re-decide; do not "push through" a red spike.** P0.2 is uniquely terminal — a red there parks the entire port, not just Phase 1. **Green-with-caveats counts as green for G0 iff** every caveat is (a) enumerated in the spike report and (b) assigned an owner-acknowledged cost/risk line in the Phase 1 plan; any caveat that would change a Phase 1 architectural decision (toolchain pin, NDK version, packaging mechanism) must be resolved to green or red before G0 is scored.

**Cross-spike couplings to hold in mind:**
- **targetSdk 36** (required for new Play apps and all updates from 2026-08-31) triggers the **16 KB** requirement (API 35+) — P0.1 must build/verify at `targetSdk 36`, not defer it.
- **Model size** decided in P0.2 (whisper-small 264 MB vs Parakeet int8 ≈640 MB) drives the Play delivery mechanism (asset pack mandatory >500 MB base cap).
- **Persistence fork** decided in P0.3 (SkipSQL vs Room) changes Phase 1's persistence-layer task and whether the plan's SwiftData(iOS)+Room(Android)+DTO split survives.
- **Extractor** (P0.4) compiles as plain SwiftPM cross-compilation with the official Android SDK — it is a UI-free package; Fuse adds nothing to it. Its Android-triple compile + on-device fixture run gate on P0.1 only; integration into the Skip Fuse app build is verified opportunistically once P0.3's scaffold exists, not an exit criterion.

---

## P0.1 — Toolchain bring-up

Phase 0 de-risk spike. Self-contained, execution-ready. Budget: **2 days.**

Goal: prove that a Swift package can be cross-compiled to an Android `.so` with the **official Swift Android SDK**, loaded by a real Android app on a real device, and that the resulting APK passes Google Play's hard gates (16 KB page alignment, targetSdk regime). Everything downstream in the port (shared SwiftData/logic core behind a Kotlin/Compose UI) is blocked on this working end-to-end. If it can't, the port strategy changes fundamentally, so this is the first thing we build.

### 1. Goal & why this is a spike

**Unknown being killed:** *Can we ship Swift-on-Android at all, with a supported toolchain, through Google Play, in mid-2026?* Three things could each independently sink the port:

1. The official Android SDK bundle cross-compiles our package cleanly to `aarch64` `.so`.
2. That `.so` loads and executes inside a stock Kotlin/Compose APK via JNI on a physical API 28+ device.
3. The APK clears Play's **16 KB page-size** requirement and the **targetSdk** requirement — both of which are enforced *now*, not deferred.

**Why a spike and not just a task:** The Swift Android SDK is real and official as of Swift 6.3 (released 2026-03-24), current 6.3.3 (2026-06-30) — but Android is listed on swift.org's platform-support matrix (min deployment Android 9 / API 28) with **NO platform owner** — the owners table covers only Apple platforms, Linux, and Windows; stewardship is community-driven via the Android Workgroup only (https://www.swift.org/platform-support/, verified live 2026-07-22). That means: no vendor SLA, no "file a P1 and someone fixes your toolchain" path. **Every failure mode in this spike is self-support** — Swift forums, GitHub issues, and our own bisection. We are buying that risk deliberately, and this spike is where we find out how expensive it is *before* we've written a line of shared business logic. The deliverable of the spike is not just a working demo but a written verdict: *green / green-with-caveats / red*, with the caveats enumerated.

**In-scope:** host toolchain, SDK bundle install, one trivial cross-compiled function, JNI load, `.so` packaging, `libc++_shared.so` handling, 16 KB alignment verification, Play-gate posture.
**Out of scope (later Phase 0 spikes):** SwiftData-on-Android, Foundation/networking surface coverage, C-interop with the real model layer, build-time in CI at scale, bidirectional Kotlin↔Swift bridging ergonomics.

### 2. Prerequisites

**Host machine (dev):**
- macOS (Apple Silicon or Intel) with **Xcode** installed (we already develop the iOS app here; provides the host Swift for local sanity, though the Android SDK cross-compile is driven by the swiftly-managed toolchain, not Xcode's).
- **swiftly** — the recommended installer for the host Swift toolchain and the mechanism the getting-started doc uses (https://www.swift.org/documentation/articles/swift-sdk-for-android-getting-started.html). Install per https://www.swift.org/install/macos/ .
- **Android Studio** with the Android SDK + platform-tools (`adb`), and the **NDK LTS r27d** (the Swift getting-started doc requires "r27d or later"; pin r27d exactly per §6, with r28+ only as the §7 contingency; releases at https://github.com/android/ndk/releases). Note the NDK version pin below — it interacts with the 16 KB gate (§4).
- `llvm-readelf` (ships with the Swift toolchain / LLVM; also in the NDK toolchain) for alignment verification.

**Target:**
- A **real, physical Android device running API 28 (Android 9) or newer**, USB-debugging enabled and visible to `adb devices`.
- Deployment floor is **API 28** — build triple `aarch64-unknown-linux-android28`.

**Important constraint carried from iOS:** the project's rule is "no iOS simulator" (owner tests on a physical iPhone). That rule is about *iOS*. For Android there is no such prohibition — an Android **emulator** (`x86_64-unknown-linux-android28`) or a physical device are both acceptable. Prefer the physical device for the exit-criteria run (matches production ABI `arm64-v8a`); the `x86_64` emulator is fine for fast inner-loop iteration but is a *different* ABI and must be built with the emulator triple.

**Versions to pin (record exact values in the spike report):**
- Swift host toolchain: `6.3.3` (2026-06-30).
- Swift Android SDK bundle: `swift-6.3.3-RELEASE_android.artifactbundle`.
- NDK: `r27d` (or note the exact `r27x`/`r28x` used — decisive for §4).

### 3. Step-by-step procedure

#### 3.1 Install host toolchain via swiftly

```bash
# Install swiftly (see https://www.swift.org/install/macos/ for the current one-liner),
# then install/select the matching host toolchain:
swiftly install 6.3.3
swiftly use 6.3.3
swift --version   # expect Swift 6.3.3
```

#### 3.2 Install the Android SDK bundle (checksum is mandatory)

```bash
swift sdk install \
  https://download.swift.org/swift-6.3.3-release/android-sdk/swift-6.3.3-RELEASE/swift-6.3.3-RELEASE_android.artifactbundle.tar.gz \
  --checksum d160cc3206dd1886dae3fef2337af5e25ec034692cd0ec225721c56cc69da7f5
```

`--checksum` is **required** for any remote-URL SDK install — SwiftPM throws `checksumNotProvided` without it (per https://www.swift.org/documentation/articles/swift-sdk-for-android-getting-started.html). Verify:

```bash
swift sdk list        # expect an entry like: swift-6.3.3-RELEASE_android
```

Export the NDK location the SDK expects (exact env/flag per the getting-started doc; typically point at the r27d NDK root):

```bash
export ANDROID_NDK_ROOT="$HOME/Library/Android/sdk/ndk/27.x.xxxxxxx"
```

#### 3.3 Trivial Swift package exposing one C-callable function

The function must be exported with a stable, unmangled symbol so JNI/`dlsym` can find it. We use `@_cdecl` and return a C string.

`Package.swift`:

```swift
// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "SwiftCore",
    products: [
        .library(name: "SwiftCore", type: .dynamic, targets: ["SwiftCore"]),
    ],
    targets: [
        .target(name: "SwiftCore"),
    ]
)
```

`Sources/SwiftCore/SwiftCore.swift`:

```swift
import Foundation

@_cdecl("swiftcore_hello")
public func swiftcore_hello() -> UnsafePointer<CChar> {
    // heap copy; the bridge frees it after building the jstring.
    let message = "Hello from Swift"
    return UnsafePointer(strdup(message))   // JNI side copies then frees
}
```

#### 3.4 Cross-compile to `aarch64` `.so`

```bash
swift build \
  --swift-sdk aarch64-unknown-linux-android28 \
  --static-swift-stdlib \
  -c release
```

`--static-swift-stdlib` is the documented flow (statically links the Swift standard library into our `.so`, reducing the runtime `.so` sprawl we must package). Output: `.build/aarch64-unknown-linux-android28/release/libSwiftCore.so`.

Confirm the ABI and exported symbol:

```bash
llvm-readelf -h .build/aarch64-unknown-linux-android28/release/libSwiftCore.so   # Machine: AArch64
llvm-readelf --dyn-syms .build/aarch64-unknown-linux-android28/release/libSwiftCore.so | grep swiftcore_hello
```

For the emulator inner loop, substitute the triple:

```bash
swift build --swift-sdk x86_64-unknown-linux-android28 --static-swift-stdlib -c release
```

#### 3.5 Package `libc++_shared.so` from the NDK

Even with `--static-swift-stdlib`, the C++ runtime is a shared NDK library. `libc++_shared.so` must be shipped alongside our `.so` (per getting-started doc). Copy the matching-ABI copy out of the NDK:

```bash
cp "$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/darwin-x86_64/sysroot/usr/lib/aarch64-linux-android/libc++_shared.so" \
   app/src/main/jniLibs/arm64-v8a/
cp .build/aarch64-unknown-linux-android28/release/libSwiftCore.so \
   app/src/main/jniLibs/arm64-v8a/
```

Resulting layout:

```
app/src/main/jniLibs/
  arm64-v8a/
    libSwiftCore.so
    libc++_shared.so
```

#### 3.6 Minimal Kotlin/Compose app that loads the `.so` via JNI

`app/src/main/java/.../MainActivity.kt`:

```kotlin
package com.example.swiftbringup

import android.os.Bundle
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.material3.Text

class MainActivity : ComponentActivity() {

    companion object {
        init {
            // Order matters: dependencies first, then dependents.
            System.loadLibrary("c++_shared")
            System.loadLibrary("SwiftCore")
            System.loadLibrary("bridge")   // option-A shim that OWNS Java_..._nativeHello; without this, nativeHello() → UnsatisfiedLinkError. Load AFTER SwiftCore (bridge calls swiftcore_hello).
        }
    }

    // Bridge into the @_cdecl symbol.
    private external fun nativeHello(): String

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val msg = try { nativeHello() } catch (t: Throwable) { "load/call failed: $t" }
        Log.i("SwiftBringUp", msg)     // exit-criteria log line
        setContent { Text(msg) }
    }
}
```

The `external fun` needs a tiny JNI shim that calls `swiftcore_hello()`. Two options:
- **A (thin C shim):** a small `libbridge.so` (built via `externalNativeBuild`/CMake) whose `Java_..._nativeHello` calls `swiftcore_hello()` and wraps the `char*` in a `jstring`. Cleanest. Its `.so` is emitted by `externalNativeBuild` and packaged automatically by AGP (do **not** place it in `jniLibs` by hand); it **must** be `System.loadLibrary("bridge")`-loaded (see §3.6 code) and is itself in scope for the §4 16 KB linker flags (`target_link_options` block below).
- **B (direct `@_cdecl` JNI signature):** name the Swift export to match the JNI mangled name `Java_com_example_swiftbringup_MainActivity_nativeHello` and take `(JNIEnv*, jobject)` — avoids a second `.so` but couples the Swift symbol to the package/class name.

For the spike, **A** is preferred: it keeps `SwiftCore` free of JNI naming and mirrors how the real port will bridge (a stable C ABI boundary between Kotlin and the Swift core).

#### 3.6a The bridge shim, in full (Option A)

This is the fiddliest hour of the spike and the most likely `UnsatisfiedLinkError` source (§6), so the complete source is given rather than described. Layout: `app/src/main/cpp/{bridge.c, CMakeLists.txt}`.

`app/src/main/cpp/bridge.c`:

```c
#include <jni.h>
#include <stdlib.h>

// Exported by libSwiftCore.so (§3.3). Returns a strdup'd buffer this side must free.
extern const char *swiftcore_hello(void);

JNIEXPORT jstring JNICALL
Java_com_example_swiftbringup_MainActivity_nativeHello(JNIEnv *env, jobject thiz) {
    const char *msg = swiftcore_hello();
    jstring out = (*env)->NewStringUTF(env, msg);   // copies the bytes into the JVM string
    free((void *)msg);                              // fulfil the §3.3 "JNI side copies then frees" contract
    return out;
}
```

> **`NewStringUTF` is correct *here* (ASCII "Hello from Swift") but must NOT be carried into the production STT bridge.** It expects Modified UTF-8 and corrupts or aborts the VM on real transcript text containing supplementary characters (emoji, some non-Latin scripts). The plan's JNI standard for the real port returns transcripts as a UTF-8 `jbyteArray` decoded on the Kotlin side (see [ANDROID_PORT_PLAN.md](ANDROID_PORT_PLAN.md) §Phase 2 step 5). This bridge is a throwaway bring-up shim only.

`app/src/main/cpp/CMakeLists.txt`:

```cmake
cmake_minimum_required(VERSION 3.22)
project(bridge C)

add_library(bridge SHARED bridge.c)

# Link against the prebuilt Swift .so copied into jniLibs (§3.5).
add_library(SwiftCore SHARED IMPORTED)
set_target_properties(SwiftCore PROPERTIES IMPORTED_LOCATION
    ${CMAKE_SOURCE_DIR}/../jniLibs/${ANDROID_ABI}/libSwiftCore.so)
target_link_libraries(bridge SwiftCore)

# 16 KB page alignment on the r27 toolchain (§4) — mandatory.
target_link_options(bridge PRIVATE
    "-Wl,-z,max-page-size=16384" "-Wl,-z,common-page-size=16384")
```

Wire CMake into the app module — `app/build.gradle(.kts)`:

```kotlin
android {
    // ...
    externalNativeBuild {
        cmake { path = file("src/main/cpp/CMakeLists.txt") }
    }
}
```

AGP builds and packages `libbridge.so` from this automatically (do **not** copy it into `jniLibs` by hand, per §3.6 option A).

#### 3.7 Gradle: dedup `.so` copies with `jniLibs.pickFirsts`

Multiple dependencies can each vendor a `libc++_shared.so`; without dedup the packager errors on duplicate `.so`. `app/build.gradle(.kts)`:

```kotlin
android {
    // ...
    packaging {
        jniLibs {
            // Keep the first copy encountered; prevents duplicate-.so packaging failure.
            pickFirsts += listOf(
                "**/libc++_shared.so"
            )
            // useLegacyPackaging = false  // default; keeps .so page-aligned & uncompressed (see §4)
        }
    }
    defaultConfig {
        minSdk = 28
        targetSdk = 36   // see §6 — required for new Play apps from 2026-08-31
        ndk { abiFilters += listOf("arm64-v8a") }  // add x86_64 only for emulator builds
    }
}
```

Build and install to the connected device:

```bash
./gradlew :app:assembleRelease
adb install -r app/build/outputs/apk/release/app-release.apk
adb logcat -s SwiftBringUp    # expect: I SwiftBringUp: Hello from Swift
```

### 4. 16 KB alignment verification — HARD SUB-GATE

This is a **launch blocker, not a Phase-3 checkbox.** Google Play requires 16 KB page-size support for **all new apps and updates targeting API 35+**, effective **2025-11-01** — in force now, no extension documented (https://developer.android.com/guide/practices/page-sizes). Our plan targets `targetSdk 36`, so every APK we submit is in scope. A `.so` that isn't 16 KB-aligned will fail to load on 16 KB devices and is rejected at upload.

**Critical toolchain coupling:** **NDK r27x does NOT 16 KB-align `.so`s by default; r28+ does.** Because we pin r27d (per the Swift getting-started doc), we must pass the linker flags explicitly on *every* native `.so` in the APK — our Swift lib, the C bridge shim, and any third-party `.so` (including `libc++_shared.so`, which is pre-built by the NDK — verify its alignment; if r27's copy isn't aligned, source it from an r28+ NDK or re-link).

**Linker flags to add (every `.so`, r27 toolchain):**

```
-Wl,-z,max-page-size=16384 -Wl,-z,common-page-size=16384
```

- **Swift `.so`:** pass these flags through SwiftPM as linker args — this is **mandatory and manual, not automatic**. (Do **not** rely on swiftlang/swift PR #83809 for this: that PR is a 6.2.1 cherry-pick that only adds a `--cross-compile-build-swift-tools` flag and an Android CMake toolchain file so Swift's *own* cross-compile tools/dependencies — e.g. swift-testing — build 16 KB-aligned in CI. It does **not** make `swift build` emit `max-page-size` for *your* library, and there is no documented evidence the 6.3.3 SDK auto-aligns user `.so`s. On r27, if you omit the flags below, your `.so` ships 4 KB-aligned and fails Play upload — verify per §4, don't assume — https://github.com/swiftlang/swift/pull/83809.) Add:
  ```bash
  swift build --swift-sdk aarch64-unknown-linux-android28 --static-swift-stdlib -c release \
    -Xlinker -z -Xlinker max-page-size=16384 \
    -Xlinker -z -Xlinker common-page-size=16384
  ```
- **C bridge shim (CMake `externalNativeBuild`):**
  ```
  target_link_options(bridge PRIVATE
    "-Wl,-z,max-page-size=16384" "-Wl,-z,common-page-size=16384")
  ```
- **Uncompressed/page-aligned in the APK:** keep AGP default `useLegacyPackaging = false` so `.so`s are stored uncompressed and page-aligned inside the APK (https://developer.android.com/guide/practices/page-sizes).

**Verification — run on the built APK, treat a fail as a red gate:**

Per-`.so` LOAD-segment alignment must be 16384 (0x4000). Extract and inspect each `.so`:

```bash
# Pull the .so's out of the APK
unzip -o app-release.apk 'lib/arm64-v8a/*.so' -d apk_extract

for so in apk_extract/lib/arm64-v8a/*.so; do
  echo "== $so =="
  # LOAD segment Align column must read 0x4000 (16384), not 0x1000 (4096)
  llvm-readelf -l "$so" | grep -A1 LOAD
done
```

Or use Google's official checker, which validates every `.so` in the APK in one pass (https://developer.android.com/guide/practices/page-sizes):

```bash
# Acquire + vendor the gate tool first (verify the path against android/ndk-samples at execution time):
curl -fLO https://raw.githubusercontent.com/android/ndk-samples/main/scripts/check_elf_alignment.sh
chmod +x check_elf_alignment.sh    # vendor into scripts/ and pin it — it is the gate tool

./check_elf_alignment.sh app-release.apk    # expect every .so: "ALIGNED (16384)"
```

**Sub-gate pass condition:** every `.so` in `lib/arm64-v8a/` reports 16 KB (`0x4000` / `16384`) LOAD alignment (`check_elf_alignment.sh` prints `ALIGNED (16384)`). Any `0x1000`/`4096` result fails the spike until the flags are correctly applied (and, for `libc++_shared.so`, until an aligned copy is sourced).

### 5. Exit criteria (binary, testable)

The spike is **green** only if ALL hold on a real API 28+ device:

1. **"Hello from Swift" is logged from the installed APK** — `adb logcat -s SwiftBringUp` shows `I SwiftBringUp: Hello from Swift`, proving the Swift `.so` cross-compiled, packaged, loaded via JNI, and executed.
2. **`libc++_shared.so` is packaged exactly once** — confirmed by `unzip -l app-release.apk | grep libc++_shared` returning a single entry; `jniLibs.pickFirsts` dedup verified working (no duplicate-`.so` build failure).
3. **Every `.so` in the APK is 16 KB-aligned** — `check_elf_alignment.sh` (or per-`.so` `llvm-readelf -l`) reports `16384` LOAD alignment for `libSwiftCore.so`, the bridge shim, and `libc++_shared.so`.

Record in the spike report: exact Swift/SDK/NDK versions, APK size, the three checks' raw output, and the verdict (green / green-with-caveats / red) with any caveats enumerated — a green-with-caveats verdict only counts as G0-green under the gate-rule conditions (see G0 gate). Anything short of all three is *not* green — document what failed and the suspected cause.

### 6. Risks & mitigations (toolchain-specific)

| Risk | Impact | Mitigation |
|---|---|---|
| **No platform owner.** Android is community-stewarded via the Android Workgroup only (https://www.swift.org/platform-support/). No vendor SLA; toolchain regressions are self-support. | A future SDK/NDK combo could break the build with no one obligated to fix it. | **Pin everything** (Swift 6.3.3, SDK artifactbundle by checksum, NDK r27d) and check the pins into CI. Never float. Treat toolchain bumps as their own reviewed changes with the full §4/§5 re-verification. Keep a known-good toolchain snapshot. |
| **NDK ↔ Swift SDK version coupling.** The Swift SDK is built against a specific NDK; r27d is the doc-pinned floor (https://github.com/android/ndk/releases). Mismatched NDK ⇒ link/runtime errors. | Silent ABI/link breakage. | Pin NDK r27d exactly; upgrade NDK only paired with a re-verified SDK. Record both versions together. |
| **16 KB alignment regressions on r27.** r27 doesn't align by default; a dropped linker flag on any single `.so` fails Play upload (https://developer.android.com/guide/practices/page-sizes). | Launch blocker at submission time. | Make §4 verification a **CI gate** (`check_elf_alignment.sh` fails the build on any non-16 KB `.so`). Consider moving to NDK r28+ (aligns by default) once SDK compatibility is confirmed — removes the manual-flag footgun. |
| **`libc++_shared.so` not aligned / duplicated.** It's NDK-prebuilt; r27's copy may be 4 KB-aligned, and multiple deps vendor it. | Upload rejection or duplicate-`.so` build failure. | Verify its alignment explicitly; if 4 KB, source from r28+ NDK. `jniLibs.pickFirsts += "**/libc++_shared.so"` for dedup. |
| **targetSdk 36 landing mid-plan.** New Play apps and all updates must target **API 36 from 2026-08-31** (https://developer.android.com/google/play/requirements/target-sdk); the 12-week plan lands inside that regime. | Building against 35 now = rework/rejection later. | Set `targetSdk = 36` from day one of the spike so all gate testing (16 KB included, since 35+ triggers it) reflects production. |
| **`@_cdecl` symbol stability / JNI mangling.** Wrong symbol name ⇒ `UnsatisfiedLinkError` at load. | Demo fails opaquely. | Prefer the thin-C-shim bridge (§3.6 option A) so the stable C ABI is the contract; verify the exported symbol with `llvm-readelf --dyn-syms` before wiring Kotlin. |
| **Static stdlib assumptions.** `--static-swift-stdlib` reduces but doesn't eliminate runtime `.so`s (`libc++_shared` still shared). | Surprise missing-lib at runtime. | Enumerate the APK's `lib/arm64-v8a/` contents in the report; load-test on device, not just build success. |

### 7. Effort estimate

**Budget: 2 days.** Rough breakdown:
- **Day 1:** host toolchain + SDK install (§3.1–3.2), trivial package cross-compile to `.so` (§3.3–3.4), NDK/`libc++_shared` packaging (§3.5). Getting the first clean `aarch64` `.so` is the milestone.
- **Day 2:** Kotlin/Compose app + JNI bridge + `pickFirsts` (§3.6–3.7), on-device "Hello from Swift", then the **16 KB alignment gate** (§4) and exit-criteria write-up (§5).

**What makes it slip:**
- **16 KB flags not taking** on one of the `.so`s (esp. `libc++_shared.so` from r27) — the single most likely time-sink; could add half a day chasing an r28+ copy or re-link path.
- **NDK/SDK version mismatch** surfacing as cryptic link errors with no owner to escalate to → forum/GitHub-issue bisection (self-support tax; budget contingency).
- **JNI symbol/bridge fiddliness** (`UnsatisfiedLinkError`, `char*` lifetime) — usually an hour, occasionally a rabbit hole.
- **Environment friction** (swiftly/PATH, `ANDROID_NDK_ROOT`, `adb` device auth) — minor but real on a fresh host.

If the alignment gate can't be satisfied on r27 within Day 2, work the contingencies in this order: **(1)** fix the flags; **(2)** if only `libc++_shared.so` is misaligned, source that single file from an r28+ NDK while keeping the r27d build (no SDK-coupling risk); **(3)** a full switch to **NDK r28+** (aligns by default) **only after** a `swift build` + on-device load smoke test proves the 6.3.3 SDK tolerates it — §6 row 2 warns exactly against floating the NDK unverified. Budget +0.5–1 d if (3) is needed. **Realistic estimate: treat a Day-3 slip as expected, not exceptional**, if the host is fresh or the r27 `libc++_shared.so` alignment chase bites.

<!-- REVIEW NOTES (P0.1) -->
<!--
Adversarial review, 2026-07-21. BLOCKER/MAJOR items were applied inline above (PR #83809 misattribution corrected; 16 KB enforcement date fixed to 2025-11-01; non-loadable JNI demo fixed by loading libbridge.so). The following MINOR items are left as notes (verify during execution, don't block on them).

- [MINOR] §3.5 / §3.3 over-attribution. The swift.org getting-started doc does NOT cover APK/jniLibs packaging or a Kotlin/Compose host — it demonstrates a CLI binary run on-device via `adb push … /data/local/tmp` and `adb shell`, and contains no mention of 16 KB / max-page-size. The jniLibs+JNI+Gradle flow here is our extension. https://www.swift.org/documentation/articles/swift-sdk-for-android-getting-started.html

- [MINOR] §4/§5 readelf output string. `llvm-readelf -l` prints the LOAD Align column in hex (0x4000), not 2**14 (that notation is objdump -h). `check_elf_alignment.sh` prints `ALIGNED (16384)`. The doc's grep approach works; the pass-strings above are corrected accordingly.

- [MINOR] §3.5 hardcoded NDK host dir. `…/prebuilt/darwin-x86_64/…` is correct on both Intel and Apple-Silicon macOS (NDK ships x86_64 host binaries), but brittle; the getting-started doc uses a `prebuilt/*/` glob. Also confirm whether the 6.3.3 SDK reads `ANDROID_NDK_ROOT` vs `ANDROID_NDK_HOME` (or an install-time config) on Day 1.

- [MINOR] §7 estimate is optimistic, not wrong — 2 days assumes a warm host and a smooth bridge; 3 days realistic first-time.

Residual concerns: whether the 6.3.3 SDK itself aligns anything for you is unconfirmed (no primary source proves `swift build` sets max-page-size) — the manual flags are documented as mandatory-until-verified; confirm empirically on Day 1. `libc++_shared.so` alignment on r27 is the top risk; the r28+-copy contingency is the right call.
-->

---

## P0.2 — STT bake-off (go/no-go gate)

> **Status: KILL GATE.** This is the single de-risk that can park the whole Android port. On-device STT is load-bearing: it is the *only* input path to the signal extractor, it runs on the user's own phone (no server fallback), and there is no iOS-equivalent library (WhisperKit is Core ML / ANE-only) to port. If no candidate engine clears the exit criteria on a real mid-tier device, we do not "descope STT" — we stop. Everything downstream (extractor, sync, UI) is wasted effort against transcripts that are either wrong (high WER) or don't arrive in time (RTF > 1 / thermal abort). Treat a red result here as terminal for the port, not as a backlog item.

### P0.2.0 — Pre-registration (freeze the gate parameters BEFORE any engine output is seen)

Before the Day 1 harness runs — and before any engine transcript of the golden set exists — the **owner records the following in the spike report, in writing**:

1. **WER delta:** default **+3 absolute pts (EN) / +5 pts (EU)** vs iOS-small (P0.2.5) unless overridden now.
2. **Med-name alias map:** frozen as of this record (P0.2.2). It may **not** be extended after any engine transcript exists — adding an alias post hoc converts a miss to a hit.
3. **Statistical floor for med-recall:** as fixed in P0.2.2/P0.2.5 — one-sided exact McNemar, α = 0.05, plus the point-estimate floors. Not renegotiable after results.
4. **NPU-only acceptability:** is a Qualcomm-NPU-only launch acceptable for v1? **Yes** → a (c)/(e)-only pass is green; **No** → a (c)/(e)-only pass is red (the "soft fail" branch of P0.2.6 is decided *now*, not after seeing which engine survives).
5. **Scope the gate licenses:** owner-only-usable or market-viable. Market-viable ⇒ add ≥1 second speaker to the golden set **before recording closes** (P0.2.7 single-speaker risk).
6. **UX ceiling for RTF:** median warm RTF ≤ 0.5 = green; 0.5–1.0 = pass-with-UX-flag — the owner must explicitly accept the projected wait (in seconds, for a 90 s check-in) in the G0 writeup before the spike is scored green; > 1.0 = fail (the feasibility ceiling, P0.2.5).

**Any change to these after results exist voids the run for gate purposes and requires a re-run.** This block exists because every one of these parameters is a lever that could turn a red result green post hoc; freezing them is what makes a red terminal instead of negotiable.

### P0.2.1 — Goal & why this is THE kill gate

**Goal:** prove that *at least one* Android-runnable, on-device STT engine transcribes the owner's real check-in speech (English + European languages, with medication names) at a quality within an agreed delta of the shipping iOS baseline (`openai_whisper-small` via WhisperKit), *and* fast enough to be usable without cooking the phone — on a representative **mid-tier** Android SoC, not a flagship.

There are exactly **two independent failure modes**, and either one alone kills the port:

1. **Quality failure (WER too high vs iOS).** The extractor is a keyword/lexicon matcher — it does not tolerate paraphrase. If the engine mangles med-names ("Elvanse" → "elephants", "Concerta" → "concerto") or drops emotion/symptom keywords, the signal extractor silently produces wrong or empty signals. This is worse than no feature: the app would show confident, incorrect insights. WER on generic speech is not enough — **med-name recall is the specific failure surface** and is scored separately (P0.2.2).
2. **Latency / thermal failure (RTF too slow, or throttles).** A check-in is spoken and the user expects the transcript+signals near-immediately. If real-time factor (RTF = compute-time ÷ audio-duration) exceeds ~1.0 on the target device, transcription falls behind speech and a 90 s check-in takes >90 s to process. Worse, whisper-small CPU decode is a sustained all-core load: across a normal usage burst (several check-ins in a session) the SoC thermally throttles, RTF degrades further, and battery drain becomes user-visible. A cold demo that passes but a 5th-check-in run that aborts is still a **fail**.

**Decision rule up front:** pass = *one* engine clears **both** modes on the golden set on the test device. If none does → **port parked**, Phase 0 concludes "no-go", and no further Android work is scheduled. This section is designed so that outcome is defensible with numbers, not opinion — with the gate parameters frozen before any result exists (P0.2.0).

### P0.2.2 — Golden set design

The golden set is the measuring instrument. If it is not representative of the owner's real speech, every downstream number is theater.

**Composition (~25–30 clips, ≈ 35–50 min total):**

| Bucket | Clips | Purpose |
|---|---|---|
| English check-ins, owner's natural style | 6 | Baseline WER + the real deployment case |
| European-language check-ins (owner's languages — e.g. DE/FR/ES/IT/NL/PT, pick the ones actually used) | 6 | Multilingual coverage + auto language-ID stress (Parakeet/Whisper both claim this) |
| Med-name-dense clips (≥3 labeled med spans each, catalog meds in realistic sentences) | 8–10 | The extractor's failure surface — scored separately |
| Adverse-condition clips (background noise, fast/mumbled speech, code-switching mid-sentence EN↔native) | 4 | Realism; check-ins aren't recorded in a booth |

**Do not close recording until the manifest counts ≥ 30 labeled med spans** (≥ 5 per target language where feasible) — the sample-size guard below is unmeetable otherwise, and Day 0 is owner-recorded work that cannot be cheaply redone on Day 4.

- **Style, not scripts.** Clips must be recorded by the owner speaking as they actually check in (spontaneous, first-person, disfluent) — not read prompts. Read speech overstates every engine's accuracy. Record at the app's real capture settings (sample rate, mono, mic path) so the audio front-end matches production.
- **Med-name coverage** must span the curated EU ADHD stimulant catalog used by the Log-Dose picker (the same name list the extractor keys on — the curated EU ADHD stimulant catalog table from the medication-catalog source note / Log-Dose picker plan, i.e. the list the extractor's `medications` lexicon — 89 entries — is built from). Include the hard ones: brand names that collide with common words, and non-English pronunciations of the same drug.
- **Store raw audio** (lossless WAV/FLAC) under a stable `golden/` dir with a manifest (`clip_id, lang, duration_s, contains_meds[]`). Location: a **private** repo path or a non-committed local dir referenced by the manifest — the clips are the owner's personal health/medication speech; never attach them to a public artifact or issue.

**Ground-truth labeling:**
- Owner produces a **verbatim human reference transcript** per clip (exact words spoken, including the med-names as intended). This is the gold standard for WER — *not* any engine's output.
- Label the **med-name span(s)** per clip explicitly (which catalog entry was said, at what surface form) so med-name recall can be computed independently of overall WER.
- Two-pass: owner transcribes, then a second review pass to catch typos in the reference itself (a wrong reference silently inflates every engine's WER).

**iOS baseline — pin the exact model.** Run the *same* golden audio through the shipping iOS app's WhisperKit path with the model **explicitly forced to `openai_whisper-small`**. This is a real trap: WhisperKit's device-tier default on A14 (iPhone 12) is `openai_whisper-base`, *not* small ([argmaxinc/WhisperKit model tiers](https://github.com/argmaxinc/WhisperKit)). If you let it auto-select, you'd benchmark Android-small against iOS-base and rig the WER delta in Android's favor. Force the model in `WhisperKitConfig(model:)`, capture the transcripts, and store them as `ref_ios_small/` alongside the human reference. WhisperKit is current (argmaxinc, part of argmax-oss-swift, v1.0.0 shipped May 2026 — [argmax-oss-swift releases](https://github.com/argmaxinc/WhisperKit/releases)).

**Baseline capture harness (Day 0, critical path).** The shipping app's STT path is mic-fed and does not accept files, and playing clips at the phone's mic would add uncontrolled acoustic variance that invalidates the baseline. So: add a **debug-only target/test in the iOS repo** that instantiates WhisperKit with `WhisperKitConfig(model: "openai_whisper-small")` and the app's production decode options, transcribes each `golden/*.wav` from file, and writes `ref_ios_small/<clip_id>.txt`. This is a small, owner-approved, spike-scoped code task (not shipped); schedule it Day 0 alongside labeling.

Two references now exist:
- **Human verbatim** → the truth WER is measured against.
- **iOS-small output** → the *bar*. "Agreed delta" (P0.2.5) is defined relative to how far iOS-small itself is from human truth, so we're comparing like-for-like model class, not chasing perfection Android can't reach either.

**WER computation:**
- Use **[jiwer](https://github.com/jitsi/jiwer)** (Python) — `jiwer.wer()` / `jiwer.process_words()` for WER + aligned error breakdown (S/D/I counts).
- Apply a **frozen normalization pipeline** to every hypothesis and reference before scoring: lowercase, strip punctuation, expand/standardize numbers, collapse whitespace. Use the **OpenAI Whisper normalizers** (the same ones Whisper's own eval uses — [openai/whisper normalizers](https://github.com/openai/whisper/tree/main/whisper/normalizers)), but **match the normalizer to the clip's language**: `EnglishTextNormalizer` for the English clips only, `BasicTextNormalizer` for every non-English clip. Do **not** run `EnglishTextNormalizer` over European-language references — it is English-specific (English number-word expansion, contraction/spelling rules) and will corrupt non-English text, silently inflating (or deflating) EU WER. The pipeline must be **byte-identical per language across all engines and both references** (i.e. the same normalizer applied the same way to Android hypotheses, iOS-small hypotheses, and the human reference for a given clip), checked into the repo.
- Report per-clip and aggregate WER, plus the S/D/I split (substitutions vs deletions tells you *how* an engine fails).
- **Scoring harness deliverable:** `scripts/stt-eval/` with a `requirements.txt` (jiwer pinned), the two Whisper normalizer sources **vendored** (avoids installing the full `openai-whisper` package and its torch dependency), and `score.py` (inputs: hypothesis dir, reference dir, manifest; outputs: per-clip/aggregate WER + S/D/I + the med-recall table). Freeze before Day 2.

**Med-name recall (the extractor-specific metric):**
- Independent of WER. For each labeled med span, score a **hit** if the normalized hypothesis contains the med surface form (or an accepted alias — maintain a small alias map, e.g. "Elvanse"/"Vyvanse"/"lisdexamfetamine", so a correct-drug/different-market-name is not a miss; the map is **frozen at pre-registration (P0.2.0) and may not be extended after any engine transcript exists**).
- Report **med-name recall = hits ÷ total med spans**, per engine, next to iOS-small's recall on the same clips.
- This is the metric with **veto power**: an engine can win overall WER and still fail if it can't hear the drug names, because that's precisely what the extractor needs. Default gate: the fixed statistical + point-estimate floor of P0.2.5.
- **Sample-size guard (mandatory — this is a terminal decision).** 4 med-dense clips at ≥2 meds each yields only ≈8–12 scored spans; a single miss swings recall by ~10 pts, so a naïve "≥ iOS-small, one miss = fail" rule would let measurement noise park the entire port. Therefore: (i) **raise the med-span count to ≥ 30** (add med-dense clips and/or seed catalog names into the English/EU buckets until the corpus carries ≥30 distinct labeled spans, ideally ≥5 per target language); (ii) **statistical floor, fixed now and pre-registered (P0.2.0):** a **one-sided exact McNemar test** on paired per-span hits (Android engine vs iOS-small on the same spans), **α = 0.05** — the engine fails the veto if the test rejects; **additionally, regardless of significance, point-estimate recall must be ≥ (iOS-small recall − 10 absolute pts) AND ≥ 80% absolute** — below either bound the engine fails on the point estimate alone, because at n ≈ 30 a 15–20-pt observed deficit can fail to reach significance, and a wide CI must not excuse genuine badness any more than a single unlucky miss may park the port; (iii) any med span iOS-small *also* misses is excluded from the comparison (both engines blind to it → not an Android-specific failure).

Optionally also compute **CER** (character error rate) for the European-language clips, where morphological richness makes word-level WER noisy — jiwer supports `cer()`.

### P0.2.3 — Candidate matrix

RTF bands below are *pre-test expectations* used to prioritize which engines to bench first, not results. "NPU-gated" = only runs (or only meets its RTF band) on a device with a supported Qualcomm Hexagon NPU via QNN.

| # | Engine / runtime | Model | On-disk size | Quant | Languages | Init API / vocab-bias mechanism | NPU-gated? | Expected batch RTF (mid-tier ARM) |
|---|---|---|---|---|---|---|---|---|
| **a** | **whisper.cpp** (CPU, GGML) | whisper-small | **264 MB** (`ggml-small-q8_0.bin`) | q8_0 | 99 (EN + all target EU) | `whisper_init_from_file_with_params` (non-`_with_params` forms are `WHISPER_DEPRECATED`); **soft** bias via `initial_prompt`, capped at `n_text_ctx/2 = 224` tokens for small, needs `carry_initial_prompt` to re-apply across decode windows — **no guarantee** med-names are recognized | No | **~1–2, AT RISK** (likely > 1.0 — the probable loser) |
| **b** | **sherpa-onnx** (CPU, ONNX Runtime) | **Parakeet TDT 0.6b v3** | **≈ 640 MB** (`encoder.int8.onnx` 622 MB) | int8 | 25 EU incl. EN/DE/FR/ES/IT/NL/PT, auto language-ID | `sherpa_onnx` offline transducer recognizer; **no soft-prompt bias** — transducer; lexicon handled downstream, not in-model | No | **~0.09–0.35** (expected survivor) |
| **c** | **sherpa-onnx Whisper-on-QNN** (Qualcomm Hexagon NPU) | whisper-small (QNN) | ~ whisper-small class | QNN-quant | 99 (as Whisper) | sherpa-onnx offline recognizer, QNN provider; `initial_prompt` bias as (a) | **YES** (needs supported Hexagon NPU) | **fast if NPU present; N/A otherwise** |
| — optional slots — | | | | | | | | |
| d | **Moonshine** (sherpa-onnx / native, CPU) | Moonshine base/tiny | small | int8 | **English only** | offline recognizer | No | very fast CPU — **English-only → fallback tier only, cannot be the primary** (kills EU coverage) |
| e | **Qualcomm AI Hub Whisper-Small-Quantized** | whisper-small | whisper-small class | vendor int8/QNN | 99 | vendor runtime, per-SoC | **YES** (per-SoC NPU) | vendor-published per-SoC latencies — use as an NPU sanity datapoint |
| f | **Zipformer int8 transducer** (sherpa-onnx) | multilingual Zipformer | **< Parakeet** | int8 | multilingual (model-dependent) | offline/streaming transducer | Optional (QNN streaming) | smaller + streaming-capable; bench if (b) delivery size is a blocker |

**Sources:** whisper.cpp models + q8_0 file: [huggingface.co/ggerganov/whisper.cpp](https://huggingface.co/ggerganov/whisper.cpp/tree/main); deprecated init: [whisper.cpp `whisper.h`](https://github.com/ggerganov/whisper.cpp/blob/master/include/whisper.h); `initial_prompt`/`carry_initial_prompt` semantics: [whisper.cpp `whisper.cpp` params](https://github.com/ggerganov/whisper.cpp/blob/master/src/whisper.cpp). Parakeet TDT 0.6b v3 (25-lang, auto-LID): [nvidia/parakeet-tdt-0.6b-v3](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3); sherpa-onnx NeMo transducer models + int8 file sizes: [k2-fsa nemo-transducer-models](https://k2-fsa.github.io/sherpa/onnx/pretrained_models/offline-transducer/nemo-transducer-models.html). Whisper-on-QNN added in sherpa-onnx v1.13.4: [sherpa-onnx CHANGELOG](https://github.com/k2-fsa/sherpa-onnx/blob/master/CHANGELOG.md). Qualcomm AI Hub Whisper-Small-Quantized: [aihub.qualcomm.com/models/whisper_small_quantized](https://aihub.qualcomm.com/models/whisper_small_quantized) (the `/models/whisper_small_v2` slug 404s — this is the current path).

**Candidate (c) prerequisites — start Day 0, not Day 2.** (c) is worthless if its setup silently drops out: (i) Qualcomm developer account + QNN / AI-Engine-Direct SDK download (account-gated); (ii) check the sherpa-onnx release assets for a **prebuilt QNN-enabled Android package** (v1.13.4+) before attempting a source build; (iii) confirm the 7-series test device's Hexagon generation is on the QNN supported list. If any of these is not in hand by **end of Day 1**, declare the (c) coverage gap then (per P0.2.7), not on Day 4.

**License check (fill before walking the P0.2.6 decision tree):** record each candidate model's license / redistribution terms in the report — Whisper weights are MIT; Parakeet ships under NVIDIA's model license (verify in-app redistribution terms); vendor QNN runtimes carry their own SDK terms. Cheap to check on Day 4; expensive to discover in Phase 1.

> **Explicitly excluded: SenseVoice.** It covers only zh/yue/en/ja/ko — **zero European coverage beyond English** ([k2-fsa SenseVoice](https://k2-fsa.github.io/sherpa/onnx/sense-voice/index.html)). It was in an earlier draft; it is wrong for this app and must not be benched as a primary. Also **not bet on: whisper.cpp Vulkan/Adreno GPU on Android** — unproven on mobile Adreno; treat as research, not a candidate.

### P0.2.4 — Test protocol

**Device selection — mid-tier, not flagship.** The ground-truth risk data (Qualcomm's own small *encoder* ≈ 0.6–0.7 s on a *flagship* S23; Raspberry Pi 5 whisper-small ≈ RTF 2 batch) means a flagship would give a falsely optimistic pass. Bench on representative 2025-era mid-tier Qualcomm silicon, ideally two points:
- **Snapdragon 6 Gen 3** (4 nm, ships in mid-range 2024–2025 phones e.g. Samsung Galaxy A-series, POCO M-series — [Qualcomm Snapdragon 6 Gen 3](https://www.qualcomm.com/products/mobile/snapdragon/smartphones/mobile-ai) / [spec summary](https://nanoreview.net/en/soc/qualcomm-snapdragon-6-gen-3)) — the honest floor of the addressable market.
- **Snapdragon 7s Gen 3 / 7 Gen 3** — upper mid-tier, has a more capable Hexagon NPU, the realistic target for the QNN candidate (c).
- Procure **physical devices** (not emulator — CPU/NPU/thermal behavior is meaningless on x86 emulation). One 6-series + one 7-series covers the band.

**Runtime configuration to sweep, per engine × device:**
- **Thread counts:** 4 and 6 (mid-tier SoCs are typically 4 perf-ish + 4 efficiency; test both to find the RTF/thermal knee). Pin to perf cores where the runtime allows.
- **Batch vs streaming:** primary metric is **batch** RTF (whole clip, matches the app's record-then-transcribe UX). Also note streaming latency for (b)/(f) as a UX bonus, but the gate is batch.
- **Warm vs cold load:** measure **model load time** separately (cold = first load from asset pack storage; warm = model already resident). Cold load of a 264 MB (whisper) vs 640 MB (Parakeet) file is itself a UX cost and feeds the delivery decision (P0.2.6). RTF is measured **warm** (steady state), load time reported alongside.
- Fix CPU governor caveat: Android won't let you pin governor without root; instead run each measurement **from a controlled thermal baseline** (see below) so results are comparable.

**RTF measurement:**
- `RTF = wall_clock_decode_seconds ÷ audio_duration_seconds`, measured warm, median over 3 runs per clip, reported per-clip and aggregate.
- Instrument inside the engine harness (timestamp around the decode call), not end-to-end app time, to isolate STT from I/O.

**Thermal / battery — the 5-consecutive-check-in run:**
- Simulate real burst usage: transcribe **5 golden clips back-to-back** (≈ the worst realistic session), no cooldown between.
- Sample thermal state throughout via the **Android Thermal API**: `PowerManager.getThermalHeadroom(seconds)` — a value **≥ 1.0 means the device is at/entering `THERMAL_STATUS_SEVERE` throttling** ([Android Thermal API](https://developer.android.com/games/optimize/adpf/thermal)); poll ≤ once/sec (more frequent returns NaN). Also register a `PowerManager.OnThermalStatusChangedListener` and log `THERMAL_STATUS_*` transitions (`NONE` = no throttling; anything above `LIGHT`/`MODERATE` during the run is a warning; `SEVERE`+ is an abort — [thermal status levels](https://source.android.com/docs/core/power/thermal-mitigation)).
- Cross-check from adb: `adb shell dumpsys thermalservice` (shows current temperatures, thresholds, and throttling status) sampled before/during/after the run.
- Track **RTF drift across the 5 clips** (clip 1 vs clip 5) — a clean cold RTF that degrades past 1.0 by clip 5 is a thermal fail even if `THERMAL_STATUS_SEVERE` isn't formally hit.
- Log **battery delta** (`dumpsys batterystats` / battery % before→after) as a secondary signal — a check-in shouldn't cost visible battery.
- **Start each engine's run from the same thermal baseline:** device idle until `getThermalHeadroom` reports a stable low value (headroom well below 1.0) before starting, so engine A isn't unfairly measured on a hot device warmed by engine B.

**Capture-parity smoke check (0.5 d, Day 3).** The golden WAVs are iOS-recorded; the deployed pipeline will feed Android-mic audio through per-OEM DSP (AGC, noise suppression, voice processing) that can move WER independently of the engine. Record 3 golden-script clips on the mid-tier test device via a minimal `AudioRecord` path at the planned capture config (16 kHz mono, `VOICE_RECOGNITION` source, effects off), run them through the passing engine, and compare WER against the same clips' iOS-recorded WER. A gap larger than the pre-registered delta flags a **capture-pipeline risk to carry into Phase 1** — it does not retro-fail the engine gate, but it must appear in the G0 writeup.

### P0.2.5 — Exit criteria (binary)

An engine **PASSES** only if it clears **all three**, on the golden set, on the mid-tier test device:

1. **Quality:** **med-name recall clears the fixed veto floor vs iOS-small** — the one-sided exact McNemar test (α = 0.05) does not reject, **AND** point-estimate recall ≥ (iOS-small recall − 10 absolute pts) **AND** ≥ 80% absolute — scored over ≥30 med spans per the P0.2.2 sample-size guard — **AND** overall normalized WER within the **pre-registered delta** (P0.2.0) of iOS-small.
2. **Speed:** **batch RTF ≤ 1.0** (median, warm) on the mid-tier device — and RTF at clip 5 of the thermal run still ≤ 1.0. **Caveat: RTF ≤ 1.0 is the *feasibility* ceiling (transcription keeps up with speech), not the *UX* target.** At RTF = 1.0 a 90 s check-in still costs a ~90 s wait, which contradicts the "near-immediately" promise in P0.2.1. Record the RTF headroom below 1.0 as a product-quality signal and score it against the **pre-registered UX ceiling (P0.2.0 item 6)**: median warm RTF ≤ 0.5 = green; 0.5–1.0 = pass-with-UX-flag, where the owner must explicitly accept the projected wait in the G0 writeup before the spike is scored green; > 1.0 = fail. The owner's acceptance or rejection is *recorded*, not "escalated" — an engine that *technically* passes at RTF 0.95 is not green until the owner has signed off on the wait.
3. **Thermal:** **no throttling abort** across the 5-consecutive-check-in run — i.e. thermal status never reaches `SEVERE` (`getThermalHeadroom` stays < 1.0) and RTF does not drift above 1.0. **NaN fallback (see REVIEW NOTE 5 — some mid-tier devices return NaN unconditionally):** if `getThermalHeadroom` returns NaN on the test device, the criterion is scored instead as `dumpsys thermalservice` status ≤ MODERATE throughout **AND** clip-5 RTF ≤ 1.0 **AND** clip-5 RTF ≤ 1.15 × clip-1 RTF. NaN is never a pass by absence of signal.

**Who sets "agreed delta" and the default:** the **owner** sets it **at pre-registration (P0.2.0), before any engine output exists** (it's a product-quality call, not an engineering one — how much worse than iOS is "still shippable"). If unset at pre-registration, the defaults below apply and are thereby frozen:
- Med-name recall clears the **fixed statistical + point-estimate floor** (P0.2.2 guard: one-sided exact McNemar α = 0.05, recall ≥ iOS-small − 10 pts, ≥ 80% absolute — the extractor cannot lose drug names; decided on signal, not a single unlucky miss), **and**
- Overall WER **≤ iOS-small WER + 3 absolute percentage points** on English, **≤ +5 pts** on European-language clips (multilingual is inherently harder and the current iOS app already tolerates that class). *(These +3/+5 defaults are asserted, not derived from a tolerance study — the owner should sign off consciously.)*

These numbers are the recommended default. Tightening or loosening the WER band happens **only at pre-registration** — after results exist, any change voids the run (P0.2.0) — and the med-recall floor never moves.

**PASS = at least one engine meets 1 ∧ 2 ∧ 3. FAIL of all candidates = port parked.** There is no partial credit and no "we'll optimize it later" — Phase 0 exists precisely to find out *before* investing, and the RTF/thermal ceilings are physics, not tuning targets.

### P0.2.6 — Decision tree (which pass leads where)

```
Run bake-off on mid-tier device(s)
│
├─ whisper-small CPU (a) PASSES ──────────────► BEST CASE: SIMPLEST PATH
│     264 MB fits the 500 MB base module (no asset pack strictly needed),
│     same model family as iOS (WER parity easiest to argue), 99 langs,
│     initial_prompt gives at least a soft lexicon nudge. Ship (a).
│     (Least likely per RTF risk data — but if it clears, take it.)
│
├─ ONLY Parakeet int8 (b) PASSES ─────────────► WORKABLE, with a delivery tax
│     640 MB > 500 MB base module cap ⇒ install-time Play asset pack is
│     MANDATORY (base 500 MB / 1.5 GB per pack / 4 GB cumulative install-time —
│     [Play asset delivery limits](https://support.google.com/googleplay/android-developer/answer/9859372)).
│     Consequences to accept: +~380 MB install footprint vs whisper, more RAM
│     at load, pack plumbing, and med-names handled purely downstream (no in-model
│     bias — validate med-recall extra hard). CPU-only ⇒ no NPU fragmentation. Ship (b) + asset pack.
│
├─ ONLY the NPU engine (c/e) PASSES ──────────► NPU-REQUIRED — narrows the market, discuss
│     Works only on supported Qualcomm Hexagon NPUs (QNN). This FRAGMENTS device
│     support: excludes MediaTek/Exynos/older Snapdragon users entirely, or forces
│     a slow CPU fallback for them (which by definition failed the gate → those
│     users get no usable STT). Product decision required: is a Qualcomm-NPU-only
│     launch acceptable for v1? If not, this counts as a soft fail. Do NOT ship
│     NPU-only silently.
│
├─ Multiple PASS ─────────────────────────────► pick on: WER/med-recall margin first,
│     then delivery size (whisper 264 MB < Parakeet 640 MB), then breadth of device
│     support (CPU > NPU-gated). Prefer the widest-supported adequate engine.
│
└─ NONE PASSES ───────────────────────────────► ★ PORT PARKED ★
      No engine clears WER-within-delta AND RTF ≤ 1.0 AND no-thermal-abort on
      mid-tier hardware. On-device STT with no server fallback is infeasible for
      the target market. Phase 0 verdict: no-go. Stop the port; do not build the
      extractor/sync/UI against transcripts that won't arrive or won't be right.
      (Re-open only if: a materially faster model ships, or the product accepts
      an NPU-only / flagship-only market, or a server-STT product pivot is on the table.)
```

### P0.2.7 — Effort estimate & slip risks

**Budget: 4 days** (as planned). Breakdown:

| Day | Work |
|---|---|
| 0 (pre-req, may overlap) | Record the P0.2.0 pre-registration; procure 1–2 mid-tier devices; start candidate-(c) prerequisites (QNN SDK, P0.2.3); record + human-label the ~25–30-clip golden set (do not close recording under 30 labeled med spans); build the baseline capture harness (P0.2.2) and run the golden audio through it with the model pinned to `openai_whisper-small`, capture reference transcripts |
| 1 | Stand up harnesses: whisper.cpp (a) + sherpa-onnx (b) Android builds, load models, wire jiwer WER + med-recall scoring against the frozen normalizer |
| 2 | Full accuracy pass (a)+(b) on golden set both languages; add QNN engine (c) if a supported device is in hand |
| 3 | RTF sweeps (thread counts, warm/cold load) + the 5-check-in thermal/battery run per surviving engine; collect `getThermalHeadroom` / `dumpsys thermalservice` traces |
| 4 | Score against exit criteria, walk the decision tree, run the end-to-end STT→extractor check (below), write go/no-go with the numbers; bench an optional slot (Zipformer/Moonshine) only if (a)/(b) are borderline |

**End-to-end STT→extractor check (Day 4).** P0.2 proves transcript quality and P0.4 proves extractor byte-parity *on identical input text* — nothing else connects them. The winning engine's transcript **style** (casing, punctuation, number formatting — transducer output vs Whisper's) differs from the WhisperKit output the lexicon/regex extractor was tuned on, so signals can diverge even at equal WER and perfect extractor parity. Feed the passing engine's golden-clip transcripts through the (P0.4-fenced) extractor and compare emitted signals against the iOS pipeline's signals (iOS-small transcript → extractor) per clip: med events, mood/energy/focus levels. Material divergence attributable to transcript formatting (not WER) becomes a **named Phase 1 normalization task with an estimate**; severe divergence is surfaced at G0 as a quality flag on the P0.2 pass.

**Slip risks (call these out now):**
- **Device procurement** — the single biggest schedule risk. Physical mid-tier devices must be in hand before Day 3; emulator results are worthless for RTF/thermal. If a QNN-capable 7-series device isn't sourced, candidate (c) can't be evaluated and an NPU-only outcome can't be confirmed or ruled out — flag as a coverage gap, not a pass.
- **Golden-set labeling** — verbatim human transcripts + med-span labels are slow and owner-dependent; a rushed/low-quality reference silently corrupts every WER number. This is on the critical path and should start Day 0, in parallel.
- **Multilingual reference burden** — the owner must produce accurate references in each target EU language; if a language can't be reliably labeled, drop it from the golden set rather than score against a shaky reference.
- **Cross-compilation friction** — Android NDK builds of whisper.cpp / sherpa-onnx (ABI, ONNX Runtime provider libs, QNN SDK for (c)) can eat Day 1; keep prebuilt sherpa-onnx AARs as a fallback to protect the schedule.
- **Thermal non-determinism** — ambient temperature and background OS activity move thermal results; enforce the idle-baseline reset (P0.2.4) and repeat any near-threshold thermal run before calling it.
- **Single-speaker generalization** — the golden set is one speaker (the owner). That is the right bar *if the owner is effectively the only user*; if the port targets a broader Android market (as the P0.2.6 decision tree's "addressable market / excludes MediaTek-Exynos users" language implies), a pass on one voice does **not** prove WER/med-recall generalize across accents, pitch, and mic hardware. Decide at pre-registration (P0.2.0 item 5) which decision this gate is licensing — owner-only-usable, or market-viable — and if the latter, add ≥1 second speaker before recording closes, or a green result is not terminal-grade.

If procurement or labeling slips, the gate slips — but **do not paper over a missing measurement with a flagship or emulator number.** An unproven claim is a no-go input, not a pass.

<!-- REVIEW NOTES (P0.2) — MINOR items from the adversarial verification pass (2026-07-21). Core technical claims all verified against primary sources; these are precision/sourcing refinements, not gate-changers. BLOCKER (med-recall decided on ~10 spans → ≥30-span statistical guard) + 3 MAJOR (RTF-vs-UX caveat, per-language normalizer, single-speaker scope) applied inline.
1. RTF anchor: the published Qualcomm figure is ≈0.7 s encoder for Whisper-Small(-V2) on a Samsung Galaxy S23 (TFLite/GPU), not "610 ms on S23 Ultra" — https://huggingface.co/qualcomm/Whisper-Small-V2 . Order of magnitude + "flagship = optimistic" argument hold; softened inline.
2. Candidate-(b) RTF band: sherpa-onnx docs show v3-int8 RTF 0.325 (single-run log, RK3588, threads unstated) and a v2-int8 table 0.220–0.088 @1–4thr on RK3588 A76 — the 0.05 low end is not observed; band tightened to ~0.09–0.35 inline (top end rests on the single-run log). https://k2-fsa.github.io/sherpa/onnx/pretrained_models/offline-transducer/nemo-transducer-models.html
3. "small ≈ 4–5× tiny" prior: param ratio is ~6× (39M→244M); fine as an ordering heuristic, not a measurement.
4. Play caps are compressed-download vs the doc's on-disk sizes; int8/q8 weights compress poorly (~10–20%) so both conclusions (264 MB fits, 640 MB exceeds base) hold.
5. getThermalHeadroom needs API 30+ AND a device thermal-HAL; some mid-tier devices return NaN unconditionally — confirm non-NaN per device or lean on RTF-drift + dumpsys backups. https://developer.android.com/games/optimize/adpf/thermal
6. Parakeet v3's 25 "European" languages include ru/uk (NVIDIA's own label) — immaterial to coverage.
VERIFIED-CORRECT: whisper_init_from_file_with_params current + non-params deprecated; initial_prompt/carry_initial_prompt + 224-token cap; ggml-small-q8_0.bin 264 MB; Parakeet int8 ≈640 MB / 25 langs / auto-LID; sherpa-onnx v1.13.4 added Whisper-on-QNN; SenseVoice zh/yue/en/ja/ko only (excluded); WhisperKit A14 default = base (pin-small is real); Pi 5 whisper-small ≈ RTF 2. -->

---

## P0.3 — Skip Fuse UI spike

**Budget: 3 days. Owner: iOS eng. Outcome: a go/no-go on Skip Fuse as the port's UI + persistence spine, with every "Paper & Pollen" fidelity gap enumerated and assigned a fallback.**

This is the load-bearing *architecture* spike of Phase 0 (P0.2 remains the terminal go/no-go). Everything else in the port plan (shared-core split, DTO layer, effort estimate) is downstream of two answers this spike must produce with a real device in hand — not from reading the support matrix and guessing.

### 1. Goal & the two questions this spike answers

The spike exists to answer two binary questions by building, not by reading docs:

- **Q1 — Fidelity:** Can `SkipFuseUI` render the **check-in screen** (the app's signature capture surface — see DESIGN.md §New Look) at *acceptable* fidelity on a real Android device, including **at least one signal glyph rendered as a custom SwiftUI `Shape`**? "Acceptable" = the meadow card, the ramp-colored selection chips, the ring gradient, and one glyph are recognizably the same design, with any deviations classified as non-blocking and given a fallback.
- **Q2 — Persistence:** For the one persisted table the check-in writes (a `Recording`-like row), do we standardize on **SkipSQL** (shared Swift core, one persistence surface) or **Room-behind-SkipBridge** (platform-split, doubled surface)? The current port plan assumes SwiftData(iOS) + Room(Android) with DTOs; this spike must pressure-test SkipSQL as the strictly better path before that split is baked in.

Why these two and nothing else: the glyphs and meadow ramps hit SkipUI's documented weak spots (`Canvas` absent, custom-Shape gesture masking, gradient support) *directly* — [skip-ui support matrix](https://github.com/skiptools/skip-ui) — and persistence is the one architectural decision that, if made wrong, forfeits Fuse's entire reason to exist (a shared Swift core). Navigation, networking, and settings screens are deliberately **out of scope** for this spike; they are low-risk and can be de-risked in Phase 1.

Ground-truth anchors (web-verified 2026-07-21):
- Skip Fuse = your Swift compiled **natively** for Android via the official Swift Android SDK; SwiftUI maps to Jetpack Compose through **SkipFuseUI → SkipUI** (SkipUI *is* the Compose implementation). SkipBridge is the JNI Swift↔Kotlin interop layer, **not** the UI mapper. [skip.dev/docs/modes](https://skip.dev/docs/modes/), [skip-fuse-ui](https://github.com/skiptools/skip-fuse-ui), [skip-bridge](https://skip.dev/docs/modules/skip-bridge/)
- Skip is **stable**, v1.9.4 (2026-06-26), shipping in production apps on both stores, and **free + fully open-source** since 1.7 (2026-01-21) — no license cost is a factor in this decision. [skip.dev/docs/status](https://skip.dev/docs/status/), [skip.dev/blog/skip-is-free](https://skip.dev/blog/skip-is-free/)

### 2. Setup

**Host prerequisites** (verified against [skip.dev/docs/gettingstarted](https://skip.dev/docs/gettingstarted/)):

| Requirement | Version | Notes |
|---|---|---|
| macOS | 15+ | development machine |
| Xcode | 15.0.0+ (use current 26.x) | drives the iOS side + the shared Run workflow |
| Java (JDK) | 17.0.0+ | Gradle toolchain |
| Gradle | 8.6.0+ | Android build |
| Android Studio | current | emulator + SDK management |
| Android SDK | auto | installed via Homebrew during Skip setup |
| Swift Android SDK | current | **Fuse-only** — this is what makes it "native"; verify with `skip checkup --native` |
| Skip toolchain | 1.9.4+ | `brew install skiptools/skip/skip` |

**Step 0 — verify the environment before writing a line of Swift:**
```bash
skip checkup --native
```
`skip checkup` validates the whole toolchain and performs **test builds for both platforms** (Swift + Kotlin compilation, app assembly). The `--native` flag exercises the Swift Android SDK path that Fuse depends on. Do not proceed until this is green — a broken Android SDK install is the most common day-1 blocker and `checkup` catches it. [skip.dev/docs/gettingstarted](https://skip.dev/docs/gettingstarted/)

**Step 1 — scaffold with Skip's generated Gradle project (do NOT hand-roll an AGP shell):**
```bash
# interactive (guided prompts for app name / bundle id):
skip create
# or non-interactive for the spike — NOTE the required --native-app flag and the module-name positional:
skip init --native-app --appid=dev.appfour.fusespike appfour-fusespike AppFourFuseSpike
```
`skip create`/`skip init` generate the dual Xcode + Gradle project and the `Skip/skip.yml` module file automatically. **Use this generated project.** The project **type** is selected at scaffold time — `skip create` prompts native-vs-transpiled, and `skip init` requires an explicit `--native-app` (or `--transpiled-app`); omit it and `skip init` does not scaffold a Fuse project. The command also takes **two** positionals — the project/dir name *and* the module name (`skip init --native-app --appid=<id> <dir> <Module>`, verified [skip.dev/docs/skip-cli](https://skip.dev/docs/skip-cli/)). Passing `--native-app` writes `mode: 'native'` into the generated `skip.yml` for you. Embedding Skip output inside an unmanaged, hand-rolled Compose app is *possible* but carries an Activity/state-restoration caveat the spike must not fight: SwiftUI "relies on its own mechanisms to save and restore `Activity` UI state, such as `@AppStorage` and navigation path bindings. It is not compatible with Android's `Activity` UI state restoration" — the remedy is `rememberSaveableStateHolder()`, which is exactly the kind of glue the generated project already wires for you. [skip-ui README](https://github.com/skiptools/skip-ui)

**Step 2 — confirm Fuse mode (already set if you scaffolded with `--native-app`/chose native in `skip create`).** The gotcha is at the `skip.yml` *schema* level, not the scaffold: if the `mode:` key is **unspecified/absent** it defaults to `'transpiled'` (Skip Lite) — verified [skip.dev/docs/modes](https://skip.dev/docs/modes/) ("If the `mode` is not specified, it defaults to `'transpiled'`"). A project created in native mode already carries `mode: 'native'`; the trap bites only when you **hand-add or convert** a module and forget the key. Open `Skip/skip.yml` and confirm it reads:

```yaml
# Skip/skip.yml — Fuse (native) mode
skip:
  mode: 'native'          # ← REQUIRED. Omitting this silently gives you transpiled/Skip Lite.
# optional, only if mixing native + transpiled modules:
# bridging:
#   auto: true
```

Dependency/import consequence of the mode choice ([skip.dev/docs/modes](https://skip.dev/docs/modes/)):
- Fuse (`mode: 'native'`) → depend on `skip-fuse-ui.git`, `import SkipFuseUI`
- Lite (`mode: 'transpiled'`) → depend on `skip-ui.git`, `import SkipUI`

Confirm the mode took by checking that the build pulls `skip-fuse-ui` and that `import SkipFuseUI` resolves.

**Step 3 — dual build + run loop.** Xcode drives the shared Run workflow; Gradle manages the Android assembly under the hood. For the spike:
```bash
skip android emulator create      # one-time
skip android emulator launch      # boot the emulator
# then Run from Xcode (builds iOS + Android), or drive the Android build via the generated Gradle project
```
Both targets build from the **same Swift source**; there is no separate Kotlin UI to maintain. The point of the spike is to prove that single source renders acceptably on the Android side.

**Step 4 — token transfer (real tokens, not approximations).** §3 requires the fidelity comparison to run on the real shipped tokens, and no scaffold step produces them: **copy the `Palette`/`Radius`/`Spacing` source files from `Packages/SquirlDesignSystem` into the spike module and fix imports to `SkipFuseUI`** (a 10-minute task; the values stay byte-identical to the shipped app). Attempting to depend on the package as-is is a bonus datapoint, not the plan of record — P0.4 §6 classifies `SquirlDesignSystem` as SwiftUI-tied, so it may not resolve under Fuse. Record in the report whether it compiles unmodified.

> **Per project policy (memory: feedback-no-sim-build):** the iOS simulator is off-limits for this project. For the spike's exit criteria the artifact that matters is the **Android** build on a real device/emulator; iOS parity is already known from the shipping app. Owner runs the device QA pass.

### 3. What to build

A single screen backed by a single table, chosen to hit the highest-risk constructs on purpose.

**(a) The check-in screen** (DESIGN.md §New Look). Concretely, using the real shipped tokens so the fidelity comparison is against ground truth, not an approximation:
- Screen ground `NewLook.screen` `#EFF2EB` (light) / `#12140F` (dark).
- One `.newLookCard()`: white `#FFFFFF` / `#1C1E19`, **radius 20** (`Radius.newLookCard`), **no border**, **two-layer shadow** — `0.05`-black offset `(0,2)` radius `8` + `0.03`-black offset `(0,1)` radius `2`.
- A row of **selection chips** filled `NewLook.selection` `#54B492` when active, `NewLook.tintNeutral` `#ECEAE6` when not; capture-flow accent `NewLook.checkInGreen` `#5FB36E`.
- The **check-in ring gradient**: `checkInGreen #5FB36E` → `checkInGreenSoft #96C19F` (`LinearGradient`).
- Native SF typography mapped per §6.

**(b) One persisted table — a `Recording`-like row.** Minimal but real: `id: UUID`, `createdAt: Date`, `mood: Int` (1–5), `energy: Int`, `focus: Int`, `note: String`. The check-in screen writes one row on save and reads the latest row back on appear. This is the seed for Q2 (§5).

**(c) At least one signal glyph as a custom SwiftUI `Shape`.** This is the sharp end of the spike. **Note from DESIGN.md §60/§183: the app does NOT yet have Shape glyphs — it currently renders signals with SF Symbols (`sparkles`/`bolt.fill`/`target`/`bed`/`pills.fill`); porting them to SwiftUI `Shape`s is an open, unstarted feature.** So the spike is *also* the first real attempt at the Shape glyph — build it once, prove it on both platforms before committing the design to the Shape path at all. Build the **aperture** or the **lightning** glyph as a `Shape`:

> **Correction — SF Symbols are NOT iOS-only under Skip.** `Image(systemName:)` **is supported on Android** by SkipUI (listed as `init(systemName: String)` in the [skip-ui matrix](https://github.com/skiptools/skip-ui)). The catch: only a **small subset** of names auto-map to Compose Material symbols, and those "will not match the iOS equivalents exactly." For fidelity you **bundle the same-named SF Symbol vector into the app's asset catalog** — then `Image(systemName: "bolt.fill")` uses your bundled vector on Android automatically, no code change ([skiptools discussion #370](https://github.com/orgs/skiptools/discussions/370)). This means the current 5 glyphs (`sparkles`/`bolt.fill`/`target`/`bed`/`pills.fill`) have a **supported, low-cost Android path that does not require building custom `Shape`s at all** — most of them are unlikely to be in the auto-mapped subset, so the real work is bundling 5 vector assets, not writing `path(in:)` geometry. **The spike must therefore test BOTH glyph paths and compare cost:** (i) `Image(systemName:)` + bundled same-named SF Symbol vectors, and (ii) the custom `Shape`. Path (i) may well be the recommendation; the custom-`Shape` port is a *design* decision (live level-morphing), not an Android-necessity. Build the lightning `Shape` to prove the Shape mechanism, but do not frame it as the only way to get glyphs onto Android.

```swift
// Energy → lightning bolt as a filled custom Shape (DESIGN.md §55, "grows and fills with level")
struct LightningGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        p.move(to:    CGPoint(x: 0.55 * w, y: 0.02 * h))
        p.addLine(to: CGPoint(x: 0.18 * w, y: 0.56 * h))
        p.addLine(to: CGPoint(x: 0.46 * w, y: 0.56 * h))
        p.addLine(to: CGPoint(x: 0.40 * w, y: 0.98 * h))
        p.addLine(to: CGPoint(x: 0.82 * w, y: 0.40 * h))
        p.addLine(to: CGPoint(x: 0.52 * w, y: 0.40 * h))
        p.closeSubpath()
        return p
    }
}

// Rendered filled (fill path is well-supported), NOT stroked, to sidestep the
// custom-Shape + .stroke gesture-mask limitation if the glyph is ever tappable:
LightningGlyph()
    .fill(NewLook.checkInGreen)     // maps to Compose fill
    .frame(width: 24, height: 24)
```

For the **aperture** glyph (DESIGN.md §56: "scattered dashed ring (low) → tight concentric rings + sharp center (high)") the risk is higher and more informative, because its natural expression is **`.stroke(style: StrokeStyle(dash:))` on concentric rings** — dashed strokes on custom paths are exactly what the matrix flags. Building aperture surfaces the worst case; building lightning proves the common case. **Build lightning first (must-pass), attempt aperture second (the informative stress test).**

**SwiftUI-construct → SkipUI support mapping** (every construct the screen actually uses). Status per the [skip-ui support matrix](https://github.com/skiptools/skip-ui); "Anything not listed here is likely not supported."

| SwiftUI construct used | SkipUI status | Source / caveat |
|---|---|---|
| `VStack` / `HStack` / `ZStack`, `Spacer`, `padding` | ✅ supported | matrix core layout |
| `RoundedRectangle` + `.fill` (the card) | ✅ supported | filled shapes map to Compose |
| Two-layer `.shadow(color:radius:x:y:)` (card) | 🟡 verify | shadow supported; **multi-layer stacking + exact blur/opacity is the fidelity risk** — measure it |
| `LinearGradient` (ring, buttons) | ✅ supported | matrix |
| `RadialGradient` | ✅ supported | matrix |
| `EllipticalGradient` | 🟡 partial | "Fills as a circular gradient instead of elliptical unless the gradient is used as its own `View`" |
| `AngularGradient` | 🔴 **absent → likely unsupported** | not in matrix; **do not depend on it** for any ramp |
| `Canvas` | 🔴 **absent → likely unsupported** | not in matrix; **any glyph that would need Canvas must become a `Shape` or a static asset** |
| Custom `Shape`/`Path` **filled** (lightning glyph) | 🟡 **NOT explicitly listed → inferred** | the matrix lists only *concrete* shapes (`Rectangle`, `RoundedRectangle`, `Circle`, `Oval`, `Capsule`, `UnevenRoundedRectangle`) — a custom `Shape` conformance with `path(in:)` is **not** its own entry. Support is *inferred* from the `.stroke` gesture caveat, which presupposes "custom shapes and paths." Treat Row 1 as the spike's **primary unknown to prove empirically**, not a matrix-guaranteed pass |
| Custom `Shape`/`Path` **stroked + tappable** (aperture dashed rings) | 🟡 **caveat** | gesture hit-mask "is **not** supported on custom shapes and paths that have a `.stroke` applied … Consider `.strokeBorder` instead of `.stroke`" |
| `withAnimation` on opacity/scale/color/frame/offset/rotation | ✅ subset | only the listed animatable properties animate (background/border/fill/stroke color, font size, foreground color, frame w/h, offset, opacity, padding, rotationEffect, scaleEffect) |
| Custom `Animatable` / custom `Transition` (e.g. glyph morphing low→high) | 🔴 **unsupported** | "Custom `Animatables` and `Transitions` are not supported" |
| Nested `withAnimation` | 🟡 caveat | "Android will apply the innermost animation to all block actions" |

All rows above cite [github.com/skiptools/skip-ui](https://github.com/skiptools/skip-ui).

### 4. Fidelity gap enumeration method

For **every custom visual on the check-in screen**, produce one row in the table below. This is the primary deliverable of the spike — the exit criteria (§7) are literally "this table is complete and no row is blocking." Method: build it, run it on Android, screenshot iOS-vs-Android side by side, and classify.

Classification vocabulary (fixed):
- **Supported** — renders correctly, ship as-is.
- **Partial** — renders but deviates (wrong gradient shape, shadow blur off, dashed stroke solid). Record the deviation + whether it's acceptable.
- **Unsupported** — does not render / wrong enough to be wrong. Assign one fallback.

Fallback vocabulary (fixed, in preference order):
1. **Simplify** — drop to a supported construct that preserves the design intent (e.g. `.stroke` → `.strokeBorder`; `AngularGradient` → `LinearGradient` approximation; morph animation → cross-fade opacity).
2. **Static / bundled-symbol asset** — render the glyph as a bundled vector per state. For the current SF-Symbol glyphs the Skip-native form of this is a **same-named SF Symbol vector in the asset catalog**, consumed automatically by `Image(systemName:)` on Android (see §3c correction); for custom shapes, a per-state SVG/PNG. Loses live scaling/morph; acceptable for fixed glyphs like sleep/medication.
3. **Per-screen Compose** — drop to hand-written Compose for that one element via the interop seam. Highest cost; last resort; each use erodes the shared-core benefit and must be justified.

| # | Custom visual | Construct | Pre-committed bar (owner signs before Day 1) | Result (S/P/U) | Deviation observed | Fallback assigned | Blocking? |
|---|---|---|---|---|---|---|---|
| 1 | Lightning glyph | filled custom `Shape` | silhouette recognizably identical at 24 pt; fill color = exact token | | | | |
| 2 | Aperture glyph | dashed concentric `.stroke` rings | dashed-ring character preserved; solid-ring fallback acceptable only if ring count/weight match | | | | |
| 3 | Check-in ring gradient | `LinearGradient` green→soft | gradient endpoints and direction match; banding acceptable | | | | |
| 4 | Meadow ramp chips | flat ramp fills `#DA7A2A…#2E8B57` | ramp hexes within ΔE < 3 of iOS screenshot | | | | |
| 5 | Card two-layer shadow | stacked `.shadow` | card must read elevated vs ground in both modes; blur radius may deviate ≤ ±50% | | | | |
| 6 | Card corner radius 20, no border | `RoundedRectangle` | radius visually identical; no border artifacts | | | | |
| 7 | Selection-state chip animation | `withAnimation` fill color + scale | state change animated (any supported curve); no hard pop | | | | |
| 8 | (if attempted) glyph level morph low→high | custom `Animatable`/`Transition` | cross-fade acceptable | | | | (expected U — see matrix) |
| 9 | Typography (Roboto standing in for SF) | system-font weight mapping (§6) | weight hierarchy reads identically side-by-side; no owner-judged cheapening — bundled Inter is the fallback | | | | |

Rules for filling it in:
- Every row cites the matrix entry it maps to (§3 table) so a "Partial/Unsupported" is never a surprise — it was predicted.
- A row is **blocking** only if *no* fallback in the ladder produces an acceptable result. Predicted non-issues: rows 1, 3, 4, 6 (supported). Predicted needs-fallback: row 2 (`.stroke`→`.strokeBorder` or static asset), row 5 (measure, possibly simplify to single-layer), row 8 (cross-fade instead of morph).
- The meadow ramps are **flat fills**, not `AngularGradient`, per DESIGN.md §44–46 — so the `AngularGradient` gap does **not** bite the ramps. Confirm this in row 4 rather than assuming.
- **Acceptance rule (pin before building):** to keep exit-criterion 2 objective, the owner signs the filled **"Pre-committed bar" column** *before Day 1* — intent-level criteria per row, since a deviation can't be pre-accepted before it's seen, but the bar it's judged against can and must be. "Acceptable" can then never be redefined to fit the result; §7 criterion 2 references only that column. The Roboto/Inter typography fork (row 9, §6) is decided by the same sign-off and recorded in the G0 decision sheet. See §7 / REVIEW NOTE M4.

### 5. Persistence decision (Q2)

Build the `Recording`-like table (§3b) and decide the port's persistence spine. The two candidates and what the spike does with each:

**Candidate A — SkipSQL (recommended to prove first).** SkipSQL provides SQLite access with a **shared Swift core**: "On Darwin/iOS, and with SkipFuse on Android, it communicates directly through Swift's C integration" — i.e. it talks to SQLite3's C API directly on both platforms, not through Android's Java wrapper, giving identical behavior. [skip-sql](https://github.com/skiptools/skip-sql). Stand it up for real:

```swift
import SkipSQL
let ctx = try SQLContext(path: dbPath, flags: [.create, .readWrite])
try ctx.exec(sql: """
    CREATE TABLE IF NOT EXISTS recording (
      id TEXT PRIMARY KEY, createdAt REAL, mood INT, energy INT, focus INT, note TEXT)
    """)
// insert on save, selectAll on appear; or model the row with SQLCodable for typed mapping.
```
SkipSQL also ships `SQLCodable` (typed struct↔table mapping, `SQLPredicate` querying, batch/aggregate helpers) — enough to back the app without an ORM. Note SkipSQL is a **Skip Lite (transpiled) framework** that nonetheless runs correctly under Fuse via the C-interop path above; confirm it links and round-trips a row under `mode: 'native'` (this is the single most important thing to verify for Candidate A).

**Candidate B — Room behind SkipBridge (document the unknowns; don't necessarily build).** Room is the Android-native ORM; using it means writing the Android persistence in Kotlin and exposing it to Swift across the SkipBridge JNI seam. This is **possible but undocumented by Skip** — the closest Skip discussion is the ORM/Core-Data thread ([discussions/124](https://github.com/orgs/skiptools/discussions/124)), which does not directly address a Room-via-bridge path; there is no supported reference to copy. Cost: it re-introduces a platform-split persistence layer (SwiftData on iOS, Room on Android) with DTOs mediating — **doubling the persistence surface** and forfeiting the shared-core benefit that is the entire reason to be on Fuse. The spike documents, without necessarily building: (i) the DTO boundary shape, (ii) the bridging annotations required, (iii) that there is no Skip-supported reference to copy.

**Framing fact:** SwiftData is **unsupported on Android** — Skip's own direction is a shared Swift persistence layer (SkipSQL, with GRDB-style work in progress), *not* a SwiftData+Room platform split. The current port plan's SwiftData(iOS)+Room(Android)+DTO design is workable but swims against Skip's grain.

**Recommendation posture: the spike's output for Q2 is a recommendation + cost sheet, not a decision.** SkipSQL is the candidate to prove first — it keeps one Swift persistence core for both platforms, is documented and supported under Fuse, and avoids the doubled surface and the undocumented Room bridge. But adopting SkipSQL on iOS is an **owner-level product/architecture call**: it abandons SwiftData — **including the SwiftData+CloudKit path the in-flight iCloud-sync work (feature 038) is built on**. SkipSQL has no CloudKit story, so a replacement sync mechanism would have to be named and estimated on both platforms. The spike therefore delivers: (i) the SkipSQL round-trip result under `mode: 'native'`; (ii) the iOS migration cost SwiftData→SkipSQL **including the 038 sync impact**; (iii) the Room/DTO split cost. **The owner makes the call at G0** (decision sheet); the platform split remains the fallback if the SkipSQL round-trip fails under `mode: 'native'` (it should not, per the C-interop guarantee).

### 6. Typography / token mapping

**Typography.** The iOS app is native SF app-wide (DESIGN.md §20, hierarchy via **weight**, not face). Android has no SF. Two options:
- **Roboto (Android default) — recommended.** SF and Roboto are both neutral geometric-humanist system sans; the app's identity lives in the *layout, color, and glyphs*, not the face (the whole 023 reversal was "typography is not the differentiator"). Using each platform's system font is the native-feel-correct choice and zero bundle cost. Map the SF weight ladder (SF semibold headings) to Roboto Medium/Bold. This keeps `Dynamic Type` ↔ Android font-scale behavior native on each side.
- **Bundle Inter (fallback).** Only if the Roboto substitution visibly cheapens the check-in screen in side-by-side QA. Inter is already the established SF stand-in in this project's Figma work (memory: figma-native-build — "SF-Pro-0-width→Inter"), so it's a known-good match. Cost: bundle weight + losing the OS-native font-scaling nicety.

**Decision to record in the spike:** default to **Roboto**; only escalate to bundled Inter if row-by-row QA of the check-in screen fails the pre-committed row-9 bar (§4) — owner-signed, recorded in the G0 decision sheet, not taste-at-the-time. Do not bundle SF (licensing + non-native on Android).

**Design tokens → SkipUI/Compose.** DESIGN.md is the source of truth; tokens live in the `SquirlDesignSystem` package (`Palette`, `Typography`, `Spacing`, `Radius`, `Motion`). Because Fuse compiles the **same Swift**, the token definitions port **as-is** — a `Color(hex:)` extension and the `Palette`/`Radius`/`Spacing` Swift enums compile natively for Android; there is no re-authoring into Compose `Color`/`dp`. Verify:
- **Color:** hex ramps (`NewLook.screen #EFF2EB`, `checkInGreen #5FB36E`, mood ramp `#DA7A2A…#2E8B57`, medication `#7E5CA8`) render identically — `Color(red:green:blue:)` maps to Compose `Color`. Confirm sRGB, not P3, so iOS-wide-gamut and Android-sRGB don't diverge on the ramps.
- **Spacing/Radius:** the numeric scale (radius small 12 / card 18 / **newLookCard 20** / pill 999; spacing scale) maps to Compose `dp` 1:1 — same Swift constants, same points→dp.
- **Dark mode:** every token has a dark value (DESIGN.md §29–38, §116–131); confirm SkipUI resolves `@Environment(\.colorScheme)` to Android's night mode so both variants light up.

### 7. Exit criteria (binary)

The spike passes **iff all three are true**:

1. **Navigable on a physical device.** The check-in screen + at least the **lightning** glyph (Shape) build under `mode: 'native'` and are navigable on a **physical Android device** — tap a chip, save, see the row persist and read back. Emulator is fine for the build loop, but the exit-criteria run and all §4 side-by-side screenshots must come from a physical arm64 device (the P0.2 mid-tier units can double up): shadow rendering, gradient banding, font rasterization, and dark mode do not transfer from an x86 emulator.
2. **Every fidelity gap enumerated & none blocking.** The §4 table is fully filled: every custom visual classified Supported/Partial/Unsupported, every Partial/Unsupported has an assigned fallback from the ladder, and **no row is judged blocking** against the **pre-committed bar column** (§4, owner-signed before Day 1) — the bar is fixed before building so a marginal glyph can't be self-certified as "acceptable via static asset" after the fact.
   - **2b. Aggregate erosion cap:** if more than **1** of the 9 rows requires fallback 3 (per-screen Compose), the spike is scored **red-for-rescope** regardless of per-row acceptability — the Fuse premise (shared UI core) is not holding on the app's signature screen, and "death by a thousand non-blocking fallbacks" must not read as a pass.
3. **Persistence recommendation with cost sheet.** Q2 answered as a **recommendation, not a decision**: SkipSQL round-trips the `Recording` row under Fuse (or is proven not to), and the §5 cost sheet — SkipSQL (incl. the feature-038 iCloud-sync impact) vs the Room/DTO split — is complete for the owner's call at G0.

If any of the three fails, the spike output states *why* and what it implies for the port (§8).

### 8. Risks & effort (3-day budget)

**Day plan (indicative):**
- **Day 1** — `skip checkup --native` green; `skip init` + `skip.yml` set to `mode: 'native'`; check-in screen skeleton (card, chips, gradient, tokens) building on Android. De-risk the toolchain first; a broken Swift-Android-SDK install can eat a day alone.
- **Day 2** — lightning glyph `Shape` (must-pass) + aperture dashed rings (stress test); SkipSQL table + round-trip; fill §4 rows 1–6.
- **Day 3** — animation rows (7, 8), typography/token side-by-side QA, complete the §4 table, write the persistence recommendation + the go/no-go.

**What a "blocking" gap looks like** (any one of these flips the spike to no-go or forces a re-scope):
- **The animated/morphing glyph behavior can't be approximated acceptably.** Mitigation already in hand (stronger than "at some identity cost"): glyphs are today SF Symbols, not Shapes (§3c), and `Image(systemName:)` is a **supported SkipUI construct on Android** — bundling the same-named SF Symbol vector into the asset catalog renders the *exact* iOS symbol on Android automatically ([discussion #370](https://github.com/orgs/skiptools/discussions/370)). So a failed custom-`Shape` path does not degrade identity for the existing glyphs at all; it only forfeits *live level-morphing* (a design nicety), which is separately unsupported anyway (custom `Animatable`/`Transition`). The canonical blocker is therefore narrow: specifically the animated/morphing glyph behavior, not static glyph rendering.
- **SkipSQL fails to link/round-trip under `mode: 'native'`** — forces Candidate B (Room + platform split), which is undocumented and doubles the persistence surface: not fatal, but a material effort and risk increase to feed back into the estimate.
- **Card shadow / gradient fidelity is unfixable and cheapens the surface** — lower-severity; almost certainly resolvable via simplify (single-layer shadow, `LinearGradient` approximation).

**What a blocking gap *means* for the port:** it does not necessarily kill the port, but it moves the affected surface from "shared Swift, free on Android" to "per-platform Compose/asset work," which is exactly the cost Fuse is meant to avoid. The go/no-go is therefore not "does it work" but "**how much of the app stays in the shared Swift core vs. leaks into platform-specific fallback**" — and this spike produces the first real measurement of that ratio on the two surfaces (glyphs, persistence) most likely to leak.

<!-- REVIEW NOTES (P0.3) — adversarial pass 2026-07-21, sources verified live. 3 MAJOR applied inline (broken `skip init` command → added --native-app + module positional; SF-Symbols-work-on-Android correction; overstated custom-Shape matrix confidence → relabeled inferred). MINOR:
- M1 §5 Candidate B: discussions/124 is "Core Data support" (ORM/SwiftData/GRDB), not Room-via-bridge — citation softened inline (broader claim still true).
- M2 §3 withAnimation row: README animatable list also includes stroke color (added inline). Immaterial to this screen.
- M3 Skip 1.9.4 date (2026-06-26) low-confidence vs one search snapshot; verify the tag date only if load-bearing (it isn't).
- M4 §7 criterion 2 subjectivity: "acceptable"/"judged blocking" could pass a genuinely blocking glyph — pinned to a pre-committed owner side-by-side sign-off (added inline in §4 acceptance rule + §7 criterion 2).
VERIFIED CORRECT: mode 'native' right + default 'transpiled'; SkipFuseUI→SkipUI→SkipBridge roles; skip checkup --native / create / android emulator real; Canvas/AngularGradient absent, custom Animatable/Transition unsupported, .stroke gesture caveat, EllipticalGradient partial — all current; SkipSQL C-interop verbatim; SwiftData unsupported on Android; v1.9.4 current, free/OSS since 1.7, production-stable. -->

---

## P0.4 — Extractor portability

The signal extractor (`NoteExtraction`) is the one piece of the app whose output is *data*, not pixels: it turns a transcript into a structured JSON schema that downstream persistence, insights, and widgets all key off. If iOS and Android disagree by even one byte for the same transcript, a note logged on one platform renders differently on the other, and any cloud-synced `noteExtractionJSON` becomes ambiguous. This section proves the *existing Swift* extractor can be compiled and run unchanged (modulo a fenced Apple-NL shim) on `aarch64-unknown-linux-android28`, producing byte-identical output — which is precisely the guarantee that makes the rejected Option B (a Kotlin/Android rewrite) unnecessary.

All file:line citations verified against the working tree at `/Users/caesargrey/Projects/app-four` on 2026-07-21.

### Extractor path — the files in scope

The service lives in `app-four/Services/NoteExtraction/`. The full set that participates in producing a `NoteExtraction`:

| File | Role | Apple-NL surface |
|---|---|---|
| [`NLNoteExtractor.swift`](../app-four/Services/NoteExtraction/NLNoteExtractor.swift) | Orchestrator: sentence split, cue matching, regex extraction, aggregation | `NLTokenizer(unit: .sentence)` (:332) |
| [`CueMatcher.swift`](../app-four/Services/NoteExtraction/CueMatcher.swift) | Pre-tokenized cue lists; tokenization + verb-lemma matching | `NLTokenizer(.word)` (:39, :60); `NLTagger([.lexicalClass,.lemma])` (:62, :84) |
| [`TenseClassifier.swift`](../app-four/Services/NoteExtraction/TenseClassifier.swift) | Present/past/neutral tense for mood aggregation | `NLTagger([.lexicalClass])` (:73) |
| [`Lexicon.swift`](../app-four/Services/NoteExtraction/Lexicon.swift) | Loads `lexicon.json` into typed cue lists | **Dead** `import NaturalLanguage` (:2) — no NL symbols used |
| [`LexiconData.swift`](../app-four/Services/NoteExtraction/LexiconData.swift) | Lexicon value types + personal-overlay merge + loader | none (`Foundation` only) — but see loader BLOCKER |
| [`NoteExtraction.swift`](../app-four/Services/NoteExtraction/NoteExtraction.swift) | The output schema + `Codable` | none (`Foundation` only) |
| [`PersonalLexiconBuilder.swift`](../app-four/Services/NoteExtraction/PersonalLexiconBuilder.swift) | Builds per-user overlay from SwiftData | `import SwiftData` (:2) — **out of the pure-extractor core**, see §6 |

The output type is `struct NoteExtraction: Sendable, Codable, Equatable` ([NoteExtraction.swift:4](../app-four/Services/NoteExtraction/NoteExtraction.swift#L4)), with level enums (`MoodLevel`/`EnergyLevel`/`FocusLevel`/`SleepLevel`) hoisted into the leaf SPM module `SquirlSignals` ([Levels.swift:8-99](../Packages/SquirlSignals/Sources/SquirlSignals/Levels.swift#L8)) — pure `Foundation` value types (§6).

The lexicon is `app-four/Resources/lexicon.json`: **verified 718 entries across 32 category keys** (`medications` 89, `moodSpecific` 90, `focusFoggy` 38, `energySluggish` 37, `executiveDysfunction` 33, `negationTokens`/`medNotTakenVerbs` 5 each — all counts confirmed by re-parsing the JSON). This is the data the production extractor keys off.

> **BLOCKER — "trivially portable" is wrong; the load path silently diverges.** The production chain is `AppDependencies.summarizationService = NLSummarizationService()` ([AppDependencies.swift:27](../app-four/Store/AppDependencies.swift#L27)) → `init(personalOverlay:)` → `LexiconLoader.loadBundled()` ([LexiconData.swift:119-129](../app-four/Services/NoteExtraction/LexiconData.swift#L119)) → **`Bundle.main.url(forResource: "lexicon", withExtension: "json")`** (:123). On decode failure it **silently returns `Lexicon()` = the hardcoded `defaultX` arrays** (:126), which are **materially smaller than the JSON** (verified: `medications` 56 vs 89, `energyCharged` 10 vs 23, `focusFoggy` 23 vs 38, `energySluggish` 22 vs 37). `Bundle.main` resource resolution under Skip Fuse / the Android SDK is **not** trivial; if it returns `nil` on Android, Android runs a *different vocabulary* than iOS and every note diverges — the exact failure this spike exists to prevent, made invisible by the silent fallback. **FIX:** for the shared core, compile the vocabulary in as a Swift constant (like the §4 inflection table) or make `loadBundled` hard-fail rather than silent-fallback, pin the resource mechanism, and drive both platforms' fixtures through the identical lexicon source. Add "iOS and Android resolve the same lexicon bytes" to §7 exit criteria.

### 1. Goal

**Prove that the existing Swift extractor compiles and runs on `aarch64-unknown-linux-android28` and emits byte-identical `NoteExtraction` JSON to iOS, for a suite of real transcripts.**

Concretely, the de-risk succeeds iff:

1. The extractor core (the files above minus the SwiftData builder) compiles with the official **Swift 6.3 Android SDK** as plain SwiftPM cross-compilation (`swift build --swift-sdk aarch64-unknown-linux-android28`) — native Swift on Android, not transpiled to Kotlin. The extractor is a UI-free package, so Fuse adds nothing to its compile path; integration into the Skip Fuse app build is verified opportunistically once P0.3's scaffold exists, but is **not** an exit criterion. This is the whole point of keeping Option A: one source of truth, one algorithm, zero re-implementation drift.
2. Every Apple-`NaturalLanguage` call is fenced behind a protocol and given a deterministic Android implementation that reproduces the iOS result (§2–§4).
3. A golden-fixture suite (§5) passes byte-equal on iOS `swift test` **and** the scripted on-device Android `fixture-runner` (§5) — there is no Android CI in Phase 0 (that is Phase 1 work).

If (1)–(3) hold, Option B is dead: a rewrite exists only to give Android *some* extractor, and a rewrite can never be *proven* byte-identical to the Swift original — it can only be regression-tested toward it, forever chasing parity. Shipping the same Swift on both sides makes parity a property of the build, not of a test suite we hope is exhaustive. The fixture suite then guards the *one* residual risk: the NL shim.

### 2. Apple-framework dependency audit

`Foundation` is available on the Swift Android SDK (the SDK ships `swift-foundation` / `FoundationEssentials` + `FoundationInternationalization`, the same swift-corelibs lineage used on Linux). `NaturalLanguage` is **not**: it is a closed-source Apple framework whose documented availability is Apple platforms only (see <https://developer.apple.com/documentation/naturallanguage>), and it is absent from swift-corelibs, so it cannot link on the Android triple. Every NL symbol below is therefore a hard port blocker until fenced.

Complete enumeration of Apple-only API in the extractor path (repo-grep verified, no NL usage exists outside these sites):

| # | Site | API | Android? | Classification |
|---|---|---|---|---|
| A | CueMatcher.swift:39 `tokenize(_:)` | `NLTokenizer(unit: .word)` | ✗ | **fence + replace** (deterministic word tokenizer) |
| B | CueMatcher.swift:60 `tokenizeWithLemmas(_:)` | `NLTokenizer(unit: .word)` | ✗ | **fence + replace** (same tokenizer as A) |
| C | CueMatcher.swift:62,68,70 | `NLTagger([.lexicalClass, .lemma])` — per-token verb detection + lemma | ✗ | **fence + replace** (POS) **+ fence + fallback** (lemma → §4 table) |
| D | CueMatcher.swift:84,87,91 `cueLemma(_:)` | `NLTagger([.lexicalClass, .lemma])` — lemma of a single-word cue at init | ✗ | **fence + fallback** (§4 table computes cue-side lemmas offline) |
| E | NLNoteExtractor.swift:332 `splitSentences(_:)` | `NLTokenizer(unit: .sentence)` | ✗ | **fence + replace** (deterministic sentence splitter) |
| F | TenseClassifier.swift:73,78-79 `verbTense(_:)` | `NLTagger([.lexicalClass])` — verb detection for tense fallback | ✗ | **fence + replace** (POS) |
| G | Lexicon.swift:2 | `import NaturalLanguage` with **no NL symbol used** | n/a | **delete the import** (dead) |
| H | CueMatcher.swift:2, TenseClassifier.swift:2, NLNoteExtractor.swift:2 | `import NaturalLanguage` | n/a | replace with `import` of the shim module (§3) |

**What is *not* used (narrows the surface):** the extractor deliberately avoids `NLTagger` sentiment/valence — the comments at NLNoteExtractor.swift:260 ("No sentiment-valence fallback") and :828 ("NLTagger's paragraph sentiment is negatively biased") document a conscious rejection. No `NLModel`, `NLEmbedding`, `NLLanguageRecognizer`, or `NLGazetteer` anywhere (grep-verified: no `setLanguage`/`NLLanguage`/`.script`/sentiment call sites). So the *entire* Apple-`NaturalLanguage` surface reduces to three primitives: **(1) word tokenization, (2) sentence tokenization, (3) `.lexicalClass` verb detection + `.lemma` lemmatization.** That NL claim is accurate — **but the *portability* surface is wider than the NL surface.**

> **BLOCKER — the pipeline is NOT "plain Foundation string/regex, already portable".** Three ICU/Darwin-adjacent Foundation dependencies feed the golden output and must be addressed:
> - **`NSDataDetector` + `Calendar.current`** (NLNoteExtractor.swift:701, :709) in `extractPreciseTime` produce `MedEvent.time` (NoteExtraction.swift:142), which is in every med fixture. `NSDataDetector` is ICU/CoreServices-backed date detection — **its presence on the Swift Android SDK Foundation is unverified and historically absent/partial on swift-corelibs-foundation**, and its parse output is locale-dependent; `Calendar.current` reads the device calendar + **timezone**. iOS-device (local TZ) vs Android-CI (UTC) can disagree on the emitted `HH:mm`. Must be fenced (deterministic time parser) or pinned (fixed POSIX locale + UTC + explicit Gregorian `Calendar`) and added to §7 exit criteria.
> - **`NSRegularExpression` (MAJOR)** — ~8 hot patterns (dose/sleep/onset/duration/crash/intake at :944–1029, plus `energyProductRegex` :443, `sleepPhraseRegex` :525, `sleepHoursRegex`/`sleepBareRegex` :738) plus `NSString`/`NSRange` (:762). These are **ICU-backed** (the `Foundation`-available `Regex` type is the *pure-Swift* one — the extractor does **not** use it), so availability on the Android SDK must be verified and the `(?i)`/`.caseInsensitive` case-fold is ICU-version-bound. Prefer migrating the hot patterns to Swift `Regex` for a provably deterministic path, or pin ICU + fixture-guard.

**Reducing scope further — the lemma path is already load-bearing-optional.** The design *anticipated* this port. `Cue` carries an `altForms` slot (CueMatcher.swift:26-29) with the doc comment: *"Deterministic, sim/device-identical — unlike `lemma`, which rides `NLTagger`'s lemma model (absent on the iOS simulator)."* The lemma bridge already **no-ops on the iOS simulator** because the model isn't present there — meaning the surface-only + `altForms` path is already the de-facto behavior in one Apple environment. The Android replacement makes that path *the* path.

### 3. Android replacements

The strategy: introduce one protocol, `LinguisticProvider`, with two conforming implementations selected at compile time via `#if canImport(NaturalLanguage)`. iOS keeps today's exact `NLTokenizer`/`NLTagger` code; Android gets a deterministic pure-Swift implementation. The extractor calls the protocol, never the framework directly.

```swift
// New file: Services/NoteExtraction/LinguisticProvider.swift  (Foundation-only)
public protocol LinguisticProvider: Sendable {
    func wordTokens(_ lowercased: String) -> [String]          // replaces A, B
    func sentenceTokens(_ text: String) -> [String]            // replaces E
    func isVerb(_ token: String) -> Bool                       // replaces C/F POS
    func verbLemma(_ token: String) -> String?                 // replaces C/D lemma
}

#if canImport(NaturalLanguage)
struct AppleLinguisticProvider: LinguisticProvider { /* today's NLTokenizer/NLTagger code, verbatim */ }
#endif
struct PortableLinguisticProvider: LinguisticProvider { /* deterministic Swift, below */ }
```

**(A/B) Word tokenization → deterministic Unicode word-break, NOT ICU-guessed.** `NLTokenizer(unit: .word)` is *not* a simple whitespace splitter and its behavior is intentionally relied upon: CueMatcher.swift:52-56 documents that it must **keep possessives/contractions intact** (`"doctor's"` stays one token, so a bare `"doctor"` cannot spuriously match the single-word `"doctor"` cue). The Android replacement is a hand-written tokenizer with a *fixed, source-controlled* rule set: split on Unicode whitespace and on punctuation **except** an intra-word apostrophe (`'` / `’`) and intra-word hyphen; fold to `lowercased()` first (as today). This is fully deterministic and version-independent. It must be validated byte-identical to `NLTokenizer` over the fixture corpus (§5) and over a token-boundary differential harness (§8) — the boundary rules are the highest-risk replacement because any divergence silently changes which cues match. Do **not** reach for ICU's word-break here: ICU's dictionary/version-sensitive segmentation reintroduces exactly the model-versioned nondeterminism we are trying to eliminate.

**(E) Sentence tokenization → deterministic terminator split.** `NLTokenizer(unit: .sentence)` at NLNoteExtractor.swift:332 feeds per-sentence tense/mood aggregation; the caller already trims whitespace and drops fragments `≤ 3` chars (:336-338), with a whole-text fallback when empty (:342). Replace with a deterministic splitter on sentence terminators (`. ! ? …` and newline) with a small fixed abbreviation guard, then the same trim/length filter. Sentence-boundary divergence is *lower* risk than word boundaries because aggregation is largely order-insensitive, but it still changes tense attribution, so it is fixture-gated.

**(C/F) Verb / POS detection → deterministic morphological rules, not a POS model.** `.lexicalClass` is used only to answer one boolean per token: *is this a verb?* (CueMatcher.swift:69, TenseClassifier.swift:80). We cannot ship Apple's POS model. Two honest options:

- **Preferred — collapse the POS gate into the static table.** Because the verb question is *only* ever asked in service of the lemma bridge, and the lemma bridge is being replaced by the §4 static table anyway, the Android `isVerb`/`verbLemma` need not be a general POS tagger: they are lookups into a precomputed table keyed on the exact inflected surfaces that appear as lexicon inflections. This makes Android's lemma path *exactly* the `altForms`/table path the design already treats as the model-independent truth (CueMatcher.swift:117-124).
- For `TenseClassifier.verbTense` (F), the only model-derived signal is "did any past-tense verb appear," and it already leans on an explicit `irregularPastVerbs` set + an `-ed` suffix rule (TenseClassifier.swift:83,93-96). The Android `isVerb` can be a fixed suffix/closed-class heuristic feeding the *same* `-ed`/irregular logic. This classifier is already a *fallback* — it only runs when no explicit lexical marker matched (TenseClassifier.swift:56-57), and the present/past marker lists (:26-36) are plain `String.contains`, fully portable — so residual POS risk touches only marker-free sentences.

**(D) Cue-side lemma → precomputed offline.** `cueLemma` (CueMatcher.swift:82-98) runs *once at extractor init* over the single-word cues to find each cue's verb lemma. On Android this becomes a static `[surface: lemma]` map generated by the same offline script as §4 — no runtime tagger at all. (On iOS it can *also* be switched to the static map to remove init-time nondeterminism; see §8.)

**The real portability threat, stated plainly.** The danger is not "Android lacks NL" — that is solved by replacement. The danger is that **any Apple NL component is model-versioned and can silently change output between iOS releases**, so "byte-identical to iOS" is a moving target unless we pin the algorithm on *both* sides to something deterministic. Three concrete instances: (1) **language inference is implicit** — no `setLanguage`/`NLLanguage` call anywhere (grep-verified), so `NLTokenizer`/`NLTagger` auto-detect per input and can differ by detected language and OS version; (2) **the lemma model is environment-dependent** — documented absent on the simulator (CueMatcher.swift:28, :117-118), i.e. sim ≠ device *today*; (3) `.lexicalClass` tagging quality is model-bound. The mitigation is uniform: **make the deterministic Swift path authoritative on both platforms** where feasible, and use the fixture suite to *lock the iOS output to that deterministic definition*.

### 4. Static inflection table

`canonicalInflections` is the model-independent lemma path and it is **currently empty**: `static let canonicalInflections: [String: [String]] = [:]` (CueMatcher.swift:124), with the doc noting *"Currently empty: none of the 20 curated emotions needs a hand-bridged surface"* (:119-123). It is consumed at CueMatcher.swift:110 (`altForms = ... canonicalInflections[surface.lowercased()] ?? []`) and matched at :181-184 (`alts.contains(t.surface)`). Because it is empty, **lemma independence is today aspirational** — on Android (and on the iOS simulator) the lemma bridge simply doesn't fire, so any inflection the cue's plain surface misses is dropped. To make Option A produce *the same matches on Android that a device produces on iOS*, this table must be populated.

**Generation (offline, source-controlled, run on macOS where NL is available):**

1. Enumerate the single-word cues from the lexicon categories where the lemma bridge is enabled. `makeList(_:lemmaEnabled:)` (CueMatcher.swift:106-113) computes a lemma **only** for single-token cues with `lemmaEnabled == true`; polysemous-gerund categories pass `false` (:100-105) and stay surface-only, so they are *excluded* from the table (matching runtime semantics exactly).
2. For each such cue `c`, use Apple `NLTagger` **on device/macOS** to compute (a) `c`'s own verb lemma `L` (mirroring `cueLemma`), and (b) run a fixed English inflection generator — a small checked-in Swift script using `NLTagger` for lemmas plus a hand-authored English suffix ruleset for the inflections, committed beside its output — to produce the surface forms that lemmatize back to `L`, e.g. `panic → {panicking, panicked, panics}`. Keep only *meaning-identical* inflections; the doc is explicit that cause-describing inflections like `"exhausting"` must be excluded (CueMatcher.swift:121-123) because they cost precision.
3. Emit two Swift literals into a generated file: `canonicalInflections: [String: [String]]` (base → inflected surfaces, populating :124) and `cueLemmas: [String: String]` (surface → lemma, replacing runtime `cueLemma`). Check the generated file into source control.
4. **Validation gate:** re-run the generator; assert the emitted file is byte-identical to the committed one (generated, not hand-edited — treat drift as a build failure). The byte-identity check is only valid on the same macOS/NL version recorded in the generated file's header — `NLTagger` output is OS-versioned, so after a macOS bump, regeneration diffs are reviewed as a deliberate change, not asserted equal. Additionally assert that for every fixture, the extractor with `canonicalInflections` populated + tagger disabled produces the same output as the current on-device tagger path.

The table **must be the same bytes on both platforms** — a plain Swift constant compiled into the shared core, so this is automatic *provided* it is generated once and committed (never per-build per-platform). This turns "lemma independence" from aspiration into a compiled fact.

### 5. Golden-fixture suite — the parity gate

This suite is the contract that replaces Option B's parity rationale. It asserts: *for transcript `T`, `canonicalJSON(extract(T))` is the identical byte string on iOS and Android.*

**Fixture format.** One directory `Tests/ExtractorFixtures/`, each case a pair: `NNN-slug.txt` (raw transcript input) + `NNN-slug.json` (expected canonical `NoteExtraction` JSON). Cases are platform-agnostic: the *same* golden file is asserted on both platforms. A helper generates/updates goldens from the current iOS extractor (the reference implementation); they are reviewed and committed.

**Corpus size and diversity.** Target **40–60 real transcripts**, chosen to exercise every field of `NoteExtraction` (NoteExtraction.swift:4-34) and every risky branch:
- Each level enum's full range (`MoodLevel`/`EnergyLevel`/`FocusLevel` 5 values each).
- Medication events with dose/time/negation/quantity/change (`MedEvent`) — hits `medications` (89) + `negationTokens` (5) + `medNotTakenVerbs` (5) and the regex extractions (`extractedDose`, `onsetMinutes`, `durationHours`).
- **Tokenizer-boundary stressors:** possessives/contractions (`doctor's`, `didn't`, `I'm`), hyphenates, ellipses, emoji, numerals, multi-sentence runs — where the Android word/sentence splitter is most likely to diverge (§3).
- **Lemma-bridge stressors:** inflected verbs whose match depends on §4 (`panicking`, `frustrating`) vs. surface-only categories that must *not* over-match.
- Tense stressors: present+past in one note, marker-free sentences (forces the POS fallback, TenseClassifier.swift:56-57).
- Edge inputs: empty-ish, sub-4-char fragments (NLNoteExtractor.swift:337), whitespace-only, very long.

**Making the output canonical/stable.** `JSONEncoder` default output is *insertion-ordered and unstable*, and the persistence path today uses a bare `JSONEncoder()` with no formatting options (Recording.swift:263). For fixtures, encode through a single canonical encoder:

```swift
let enc = JSONEncoder()
enc.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]   // deterministic key order
// Deliberately NOT .prettyPrinted (indentation = platform line-ending risk)
```

Determinism checklist, each tied to a concrete field:
- **Key ordering** → `.sortedKeys` (without it, key order follows property order). The custom `init(from:)` at NoteExtraction.swift:101-130 only affects *decoding*; encoding stays synthesized, so `.sortedKeys` pins it.
- **Float formatting** → `Double` fields `sleepHours`, `durationHours`, `SleepNote.hours`, `MedEvent.quantity`/`durationHours`. `Double` → JSON uses shortest-round-trip; iOS and Android share the same `swift-foundation` encoder lineage, so this should hold — **but it is a named fixture assertion, not an assumption**. Prefer binary-exact values (`7.5`, `0.5`); add one deliberately awkward value (`durationHours = 3.7`) as a canary.
- **Optionals** → synthesized encoder emits `null`; identical on both platforms with the shared encoder + `.sortedKeys`. The fixture locks whichever behavior the reference produces.
- **Array ordering** → all the `[String]` fields must come out in a deterministic order — a pure function of input (no `Set` iteration leaking into output). Audit for `Set`-to-`Array` conversions before freezing goldens. *(Review confirms: every `Set→Array` site in `NLNoteExtractor` is already `.sorted()` at :286-306; the non-sorted output arrays are insertion-ordered from deterministic array iteration — the audit will pass, not surface work.)*
- **Case folding** → Swift's no-locale `.lowercased()` uses locale-**independent** Unicode default case mapping, so the classic Turkish-i locale bug does **not** bite (a point for the port). Residual: non-ASCII case folding and the `(?i)`/`.caseInsensitive` regex paths depend on the platform's Unicode/ICU tables — identical only when ICU versions align. Keep fixtures ASCII-dominant + add one non-ASCII canary.

**The assertion** — byte-equality (`Data == Data`), not `NoteExtraction == NoteExtraction`, to catch encoding divergence:

```swift
func assertFixture(_ name: String) throws {
    let transcript = try loadFixtureText(name)
    let got = try canonicalEncoder.encode(NLNoteExtractor(...).extract(from: transcript))
    let want = try loadFixtureJSON(name)               // raw bytes of NNN-slug.json
    #expect(got == want)                               // byte-equal
}
```

**Running the suite on both platforms:** iOS runs `assertFixture` over all cases via `swift test` (and is the *generator* of goldens). Android has **no `swift test` path and no CI in Phase 0** — host `swift test` cannot execute the Android-triple product. Instead, build a **`fixture-runner` executable target** (loads `Tests/ExtractorFixtures/`, prints per-case PASS/FAIL + byte-diff) with `swift build --swift-sdk aarch64-unknown-linux-android28`, then `adb push` the binary + fixtures to `/data/local/tmp` and execute via `adb shell` — the same run-on-device flow the swift.org getting-started doc demonstrates. Check the scripted run into the repo as `scripts/android/run-fixtures.sh`; **CI automation of this run is Phase 1 work, not a P0.4 deliverable** — the exit criterion is the scripted local device run. Because the assertion logic and fixtures are shared, "add a fixture" automatically covers both platforms. Green on both = parity proven for that corpus.

### 6. SquirlSignals packaging

`SquirlSignals` is a real SPM package ([Package.swift](../Packages/SquirlSignals/Package.swift)) holding the four level enums that `NoteExtraction` and the design system both depend on. Its body is **pure `Foundation`** — fully portable as-is. The **only** flagged blocker is the platform pin:

```swift
// swift-tools-version: 6.0            // Package.swift:1
platforms: [.iOS("26.0")],             // Package.swift:6
```

> **MAJOR — this pin very likely does NOT block the Android/Linux triple; the plan named the wrong blocker.** SPM's `platforms:` declares **minimum deployment versions for the listed *Apple* platforms only**; it does not restrict building on *unlisted* platforms — Linux/Android/Wasm take default minimums. So `.iOS("26.0")` is unlikely to be what fails Android resolution. Relaxing it is harmless hygiene, but the spike must **verify empirically what actually fails to resolve** (candidates: the app target's own pin, resource handling under swift-tools 6.0, or Skip Fuse config) rather than assume this one-liner is the fix.

**Portable vs Apple-tied:** portable = `SquirlSignals/Levels.swift`, `NoteExtraction.swift`, `LexiconData.swift`, the lexicon JSON, and (post-fence) `CueMatcher`/`TenseClassifier`/`NLNoteExtractor`/`Lexicon`. Apple/SwiftUI-tied, keep out of the shared core = `Packages/SquirlDesignSystem` (extract token values, don't import); `PersonalLexiconBuilder.swift` `import SwiftData` — SwiftData portability is a *separate* line item (the personal-overlay merge takes an already-built overlay, so the *pure* extractor runs with `personalOverlay = nil`). Keep golden fixtures overlay-free so the suite tests the deterministic core.

### 7. Exit criteria (binary)

P0.4 is **de-risked** iff all hold:

1. The extractor core (files minus `PersonalLexiconBuilder`) + `SquirlSignals` **compile** for `aarch64-unknown-linux-android28` under the Swift 6.3 Android SDK (plain SwiftPM cross-compile — Fuse-app integration is not an exit criterion, §1), with the iOS-26 pin relaxed (§6).
2. Every Apple-`NaturalLanguage` site A–F (§2) is behind the `LinguisticProvider` fence with a working `PortableLinguisticProvider`; import G deleted; imports H repointed.
3. `canonicalInflections` + `cueLemmas` populated from the committed generator, byte-identical on both platforms, and the runtime `NLTagger` lemma/POS calls dead on the Android build (§4).
4. The golden-fixture suite (40–60 cases, §5) is **GREEN on both iOS `swift test` and the scripted on-device Android `fixture-runner` run (§5, checked in as `scripts/android/run-fixtures.sh`), with byte-identical encoded output** for every case.
5. No `Set`-iteration or float-formatting nondeterminism remains in the encoded output (audited, §5).
6. **Non-NL Foundation deps handled (§2 BLOCKER):** `NSDataDetector`+`Calendar.current` (`MedEvent.time`) fenced or pinned to a fixed locale/UTC/Gregorian calendar; `NSRegularExpression` verified present on the Android SDK (or migrated to Swift `Regex`); both fixture-guarded.
7. **Lexicon source parity (Extractor-path BLOCKER):** iOS and Android resolve the *identical* lexicon bytes — no `Bundle.main` silent-fallback to the smaller `defaultX` arrays. Loader compiled-in or hard-failing, verified on the Android triple.

Miss any one → not de-risked. The sharpest single failures are (4) a tokenizer-boundary diverging fixture, (7) Android silently falling back to a different vocabulary, and (6) `NSDataDetector`/`NSRegularExpression` being absent or locale/TZ-variant on the Android SDK.

### 8. Risks & effort (budget: 3 days)

**Sharpest risk — hidden Apple-NL nondeterminism, specifically word-boundary tokenization.** `NLTokenizer(.word)` is a black box whose output the matcher *relies* on for correctness (possessive handling, CueMatcher.swift:52-56), it runs with **no pinned language** (grep-verified: no `setLanguage`), and it is model/OS-versioned. If our deterministic Android tokenizer cannot be made byte-identical to it across the corpus, the two platforms match *different cues* and diverge.

Mitigation ladder, in order:
1. **Differential harness first (½ day):** before writing any replacement, dump `NLTokenizer` boundaries for a few thousand real/synthetic strings on-device, and diff against the candidate deterministic tokenizer. Enumerates the exact boundary rules to encode.
2. If the gap is a small, enumerable rule set (expected — English, apostrophe/hyphen/punctuation) → encode those rules, done.
3. If `NLTokenizer` proves genuinely irreproducible → **make the deterministic tokenizer authoritative on iOS too** (swap iOS off `NLTokenizer` onto `PortableLinguisticProvider`). This *changes iOS output* (a behavior change requiring re-baselined goldens + device QA) but collapses the two-platform problem to one algorithm and permanently kills the versioning risk. **Back-compat cost to surface:** the same transcript re-extracted after the swap yields different JSON than any already-persisted/iCloud-synced `noteExtractionJSON` (Recording.swift:263) — historical and new notes on iOS itself diverge, so this needs a migration/re-extraction story, not just QA. **Invoking the hatch is an owner decision recorded in the G0 decision sheet, not an in-spike call:** if invoked, P0.4's verdict is "green conditional on hatch" and Phase 1 gains a named task — iOS tokenizer swap + golden re-baseline + persisted-JSON migration/re-extraction, estimate **2–4 d** — which the Phase 0 budget never includes.

Lower risks: sentence splitting (order-tolerant aggregation, fixture-gated); POS fallback (only fires on marker-free sentences, already heuristic-backed); float encoding (shared `swift-foundation`, canary-guarded); `Set`-order leaks (already `.sorted()`, §5).

**Effort (3 days):**
- Day 1 — differential tokenizer harness + `LinguisticProvider` protocol + `AppleLinguisticProvider` (lift-and-shift) + delete dead import G.
- Day 2 — `PortableLinguisticProvider` (word/sentence/POS/lemma) + offline generator populating `canonicalInflections`/`cueLemmas`; relax `SquirlSignals` pin; get the core compiling for the Android triple.
- Day 3 — author 40–60 golden fixtures from the iOS reference, wire the byte-equal suite into iOS `swift test` and the scripted on-device `fixture-runner` run (§5), run both, resolve diffs (invoking the §8 escape hatch — mitigation step 3 — only if boundaries won't converge, and only per the owner-decision rule above). Green-on-both = exit.

If Day 3 ends **red on Android for boundary reasons and the escape hatch is declined**, the honest conclusion is that byte-parity is not achievable while iOS stays on `NLTokenizer` — but the escape hatch means that outcome is a *choice*, not a wall. Option B is never resurrected by this risk, because a Kotlin rewrite would face the *same* tokenizer-parity problem with *worse* tooling (two languages to keep in lockstep instead of one).

<!-- REVIEW NOTES (P0.4) — adversarial verification 2026-07-21, all against the working tree. 2 BLOCKER (Bundle.main silent lexicon fallback; NSDataDetector/Calendar TZ) + 2 MAJOR (NSRegularExpression is ICU-backed not pure-Swift Regex; SquirlSignals platforms-pin is the wrong blocker) applied inline. MINOR folded into §5: locale-lowercasing is NOT the Turkish-i hazard (Swift no-locale .lowercased() is locale-independent) — real residual is non-ASCII/ICU case folding; Set-audit already satisfied (.sorted() at :286-306); "~718 single-word cues" overstates (718 = all-category total; cueLemma runs over a single-token lemma-enabled subset); §8.3 escape hatch adds a re-extraction migration cliff vs persisted noteExtractionJSON (surfaced inline).
VERIFIED CORRECT: 718 entries / 32 keys + per-category counts; canonicalInflections empty at :124; the "3 NL primitives" claim (no setLanguage/NLLanguage/.script/NLLanguageRecognizer/NLModel/NLEmbedding/sentiment anywhere); all spot-checked file:line citations resolve. -->

---

## Consolidated risks & sequencing

**Run order.** P0.1 (toolchain) is the hard prerequisite for anything that compiles Swift for the Android triple — P0.3's scaffold and P0.4's Android-triple compile + on-device fixture run gate on it. P0.4 Days 1–2 (fencing, generator, differential harness) have **no** toolchain dependency and may start before P0.1 completes. P0.2 (STT) is independent of the Swift-on-Android toolchain (whisper.cpp / sherpa-onnx are C/C++ with their own NDK builds) and its Day-0 critical-path work (device procurement + golden-set labeling) should start **immediately, in parallel with everything**, because it is the longest-lead and the only *terminal* gate. Practical sequence: kick off P0.2 Day-0 procurement/labeling on day one; run P0.1 → then P0.3 and P0.4 in parallel; converge P0.2's measurement days once devices arrive.

**The two plan-voiding unknowns, and where they resolve:**
1. **STT RTF/quality on mid-tier** → P0.2 (terminal — a red here parks the port).
2. **SkipFuseUI fidelity** → P0.3 (a red here doesn't kill the port but shifts surfaces to costly per-platform work).

**Highest-severity findings the review surfaced (carry into execution):**
- **P0.1:** 16 KB alignment is a *live launch blocker* (in force since 2025-11-01), NDK r27d does not auto-align, and there is no proof the Swift SDK emits the flag for you — treat the manual linker flags + per-`.so` verification as a hard sub-gate, and hold NDK r28+ as the contingency.
- **P0.2:** the med-name-recall veto must be scored over ≥30 spans with the fixed statistical + point-estimate floor, not ~10 spans; the iOS baseline must be pinned to `openai_whisper-small` (WhisperKit's A14 default is `base`) or the whole kill decision is rigged; and every gate parameter is frozen by pre-registration (P0.2.0) before any engine output exists.
- **P0.3:** the glyph fidelity risk is **narrower** than the plan implied — SF Symbols work on Android via bundled vectors; only *live morphing* is at risk. The real architectural decision is **SkipSQL vs the plan's SwiftData+Room split** (SkipSQL is Skip's supported grain).
- **P0.4:** two *invisible* parity-breakers the plan hadn't flagged — the `Bundle.main` lexicon loader silently falls back to a smaller vocabulary on resolution failure, and `NSDataDetector`/`Calendar.current`/`NSRegularExpression` are ICU/TZ-dependent. Byte-parity is achievable, but only after these are fenced; the escape hatch (deterministic tokenizer on iOS too) guarantees closure at a **priced** one-time cost — owner-invoked via the G0 decision sheet, a 2–4 d Phase 1 task (P0.4 §8), never inside the Phase 0 budget.

**CI posture for Phase 0:** there is no Android CI, and none is built in Phase 0. Every "CI gate" named above (the P0.1 §6 alignment gate, the P0.4 fixture run) is executed in Phase 0 as a **checked-in script run locally** (`scripts/android/check-alignment.sh`, `scripts/android/run-fixtures.sh`) whose output is pasted into the spike report. Standing up actual CI (runner + device/emulator) is a named Phase 1 task, estimated separately.

**G0 deliverable:** `docs/ANDROID_PHASE0_VERDICT.md`, written by the executing engineer, signed by the owner. Mandatory contents: the four spike verdicts with raw evidence links; the pre-registered P0.2 parameters (P0.2.0) and whether they were honored; and a **decision sheet** where every owner fork this document creates is answered explicitly — WER delta, NPU-only acceptability, owner-vs-market scope, RTF UX-ceiling acceptance, SkipSQL-vs-split (incl. the 038 iCloud-sync impact), Roboto-vs-Inter, P0.4 escape-hatch invocation, and any green-with-caveats adjudications. No fork may be left "discuss"; **G0 is not passed until the owner signs the sheet.**

**Total Phase 0 budget: ~12 engineer-days optimistic** (2 + 4 + 3 + 3); **14–16 days realistic** — including P0.2 Day-0 owner labor (recording, verbatim multilingual transcription, med-span labeling, baseline harness: 1–2 d, on the critical path), the expected P0.1 Day-3 slip, and one contingency draw (e.g. the r28 chase, +0.5–1 d). Assumed staffing: one engineer + owner labeling time — the P0.3∥P0.4 parallelism is a dependency statement, not a wall-clock compression, unless a second engineer exists. Gated at **G0**. Front-loaded by design so the two plan-voiding unknowns resolve first. Standing recommendation from the plan is unchanged: run Phase 0 early as cheap insurance if the team wants motion, but hold full execution for a post-1.0 Android demand signal.
