# Quickstart — build, test, and the device-day switchover

## This feature (additive, simulator — done autonomously)

Everything ships inert behind the `MLXJournalService` binding; the app builds and behaves exactly as today.

```bash
# Build + run the default test plan (no live model, no LiteRT package)
xcodebuild test -project app-four.xcodeproj -scheme app-four \
  -testPlan app-four \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```
Expected: `** TEST SUCCEEDED **`, including the new `app-fourTests/Gemma/*` suites (chat-template, tool mapping, installed-check, service lifecycle) which run entirely on a `FakeLiteRTGenerator`.

## Device day (owner — NOT run tonight)

The switchover is gated on a physical iPhone 12 Pro. Order:

1. **Add the SPM package** in Xcode: `https://github.com/google-ai-edge/LiteRT-LM`, product `LiteRTLM` (≥ 0.12.0), to the `app-four` target. This activates the `#if canImport(LiteRTLM)` code in `LiteRTTextGenerator.swift` / `GemmaSignalsTool.swift`.
2. **Fix any API delta.** The Early-Preview API may differ from the documented surface; all live calls are in `LiteRTTextGenerator.swift` — reconcile there only.
3. **Download the model.** Point a debug build's model download at `gemmaLiteRTRepoID`; confirm `gemma-4-E2B-it.litertlm` (2,588,147,712 B) lands under `Library/llm/models/…` and the installed-check passes.
4. **Run the gated eval + memory gate** on the device (see `device-qa-checklist.md`):
   ```bash
   # GEMMA_EVAL plan mirrors the MLX eval plan; runs the real model on device only
   xcodebuild test -project app-four.xcodeproj -scheme app-four \
     -testPlan app-four-gemma-eval \
     -destination 'platform=iOS,name=<your iPhone 12 Pro>'
   ```
   Record resident `phys_footprint` (SC-1), tok/s (SC-4), and P/R vs the Qwen baseline (SC-3).
5. **Switchover (single change set):** flip `AppDependencies.summarizationService` to `GemmaJournalService()`; repoint `ModelConstants.llmHubRepoID` → `gemmaLiteRTRepoID`; wire the `.litertlm` installed-check into the live download/preflight.
6. **Destructive (after green on device):** remove `mlx-swift` + `MLXJournalService` from the extraction path.
7. **QA + PR:** manual device QA (non-negotiable per constitution II/V) → merge.

## Rollback
Because the feature is additive, reverting the switchover is a one-line DI change back to `MLXJournalService()` + repoint of `llmHubRepoID`. No data migration.
