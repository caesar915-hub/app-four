# Gate-0 report — `NLContextualEmbedding` anisotropy/separation spike

Spec: [docs/next-ml.md](../../next-ml.md) §4 (Phase D) / §6 (escalation).
Diagnostic: [Gate0DiagnosticTests.swift](../../../app-twoTests/Eval/Gate0DiagnosticTests.swift).
Run: 2026-06-13, scheme `app-two`, sim iPhone 17 Pro (UDID 667B75F8…), iOS 26.5.

## Outcome: INCONCLUSIVE on simulator — no numbers obtained

The spike **compiles and runs** (it is correct Swift, exercises the real
`NLContextualEmbedding` API), but the model could not be loaded on the
simulator, so no anisotropy/separation numbers were produced.

Exact error (from the xcresult), thrown at the asset-request step
(`Gate0DiagnosticTests.swift:32`, `try await embedding.requestAssets()`):

```
Error Domain=NLNaturalLanguageErrorDomain Code=7
"E5 model compilation failed"
UserInfo={NSLocalizedDescription=E5 model compilation failed}
```

`NLContextualEmbedding(script: .latin)` instantiates and
`hasAvailableAssets` is reachable, but **requesting/compiling the underlying
E5 multilingual model fails on the iOS Simulator** (Core ML model compilation
for the embedding asset does not complete in the sim environment). The test
threw before reaching the `Issue.record` report block, so there is no
`GATE0 REPORT` line in the result bundle.

This is the expected-and-valid simulator outcome flagged in the task brief
(caveat 1): the embedding model is a device-class asset. The spike is **not**
broken; it is parked until it can run on a physical device.

The four numbers Gate-0 needs are therefore still **unmeasured**:
- anisotropy raw mean cosine — n/a
- anisotropy centered mean cosine — n/a
- min synonym (centered) — n/a
- max unrelated (centered) — n/a
- SEPARATION verdict — n/a
- cross-lingual EN↔PT / EN↔ES synonym pairs (`synonymPairs` indices 4, 5) — n/a

## API symbol corrections (vs. the original spike draft)

The Latin-script header (`NLContextualEmbedding.h`, iOS 26.5 SDK) refines two
ObjC symbols differently than the draft assumed:

- Asset request: ObjC `requestEmbeddingAssetsWithCompletionHandler:` is
  `NS_REFINED_FOR_SWIFT` → Swift **`func requestAssets() async throws ->
  NLContextualEmbedding.AssetsResult`**. The draft's
  `requestEmbeddingAssets(completionHandler:)` does not exist in Swift; replaced
  with the async form and an `assets == .available` check.
- `load()` is the refined Swift name of ObjC `loadWithError:` — correct as
  drafted. `dimension`, `hasAvailableAssets`, `embeddingResult(for:language:)`,
  and `enumerateTokenVectors(in:using:)` all compiled as drafted.

## Go / No-Go

**DEFERRED — cannot call Gate-0 from simulator data.** No go/no-go is possible
without the numbers. The decision criterion is unchanged and recorded here so
the device run is a pure measurement:

- **GO** (build the Option-1 `NLContextualEmbedding` + CreateML-head classifier,
  spec §4) iff, after mean-centering:
  - max-unrelated cosine sits well below the synonym band (a usable separating
    threshold exists, i.e. SEPARATION = CLEAN with margin), AND
  - the two cross-lingual synonym pairs (EN↔PT, EN↔ES; `synonymPairs[4]`,
    `synonymPairs[5]`) land **in** the synonym band — the multilingual
    viability signal. If only the monolingual pairs separate but the
    cross-lingual ones collapse toward the unrelated band, Option 1's
    multilingual claim does not hold for our use.
- **NO-GO → MiniLM escalation** (spec §6, Option 2: fine-tuned multilingual
  MiniLM/DistilBERT or GLiNER) otherwise.

## Next step

Run the spike on a physical iOS 17+ device:

```bash
# ungate temporarily OR pass the env on a device run:
env -u GIT_CONFIG_COUNT -u GIT_CONFIG_KEY_0 -u GIT_CONFIG_VALUE_0 GATE0=1 \
  xcodebuild test -project app-two.xcodeproj -scheme app-two \
  -destination 'platform=iOS,name=<device>' \
  -only-testing 'app-twoTests/Gate0DiagnosticTests/anisotropyAndSeparation()' \
  -resultBundlePath /tmp/gate0.xcresult
xcrun xcresulttool get test-results tests --path /tmp/gate0.xcresult | grep -A12 'GATE0 REPORT'
```

(Note: env vars do not propagate to the **simulator** runner, but a device run
or a temporary ungate both work. Restore the gate before committing.)
