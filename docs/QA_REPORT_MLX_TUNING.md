<!-- Created: 2026-08-17 17:23 (WEST) · Updated: 2026-08-17 19:05 (WEST) -->
# MLX Tuning Port — Device QA Report

**Branch:** `feat/043-mlx-journal-service`
**Date:** 2026-08-17
**Device:** João’s iPhone 12 Pro (A14), iOS 26.5.2
**Model:** `mlx-community/Qwen2.5-1.5B-Instruct-4bit` (828.4 MB, seeded into the app container via `devicectl`)
**Scope:** Verify the macOS tuning (Prompts.yaml + PromptLoader + tuned ExtractionValidator) behaves correctly on-device through the real two-pass MLX pipeline.
**Tester:** Kimi Code CLI

---

## Summary

**VERIFIED — the tuning port is faithful and the full hard gate passes on device (8/8).** Two eval runs were performed:

1. **Run 1 (initial port snapshot):** 7/8 hard-gate; surfaced real tuning gaps (stop-word variants "medicines"/"none", mood synonym "positive"→nil).
2. **Run 2 (final):** after (a) re-syncing a newer macOS tuning generation that landed mid-day (15-rule validator, ASR phonetic med aliases, expanded synonym/stop-word tables, 4 supplement lexicon entries) and (b) applying the Run-1 fixes to **both** repos — **8/8 hard-gate pass**, meds P/R improved to **0.941/0.941**, mood recall **0.857**.

All deterministic, validator-backed behaviors of the macOS gold standard reproduce exactly on the iPhone 12 Pro: crash override, temporal recovery, rule ordering, skipped-med `taken:false`, jitter override, minimalist fallback, stop-word filtering, ASR-typo med normalization.

**Harness:** `app-fourTests/Eval/MLXEvalSet.swift` (48 cases) + `MLXExtractionEvalTests.swift` + `MLXMemoryGateTests.swift`; test plans `app-four-mlx-eval(.xctestplan)` / `-smoke`. Env-gated (`MLX_EVAL=1` + model presence) so normal test runs are unaffected.

## Hard Gate — deterministic tuning behaviors: 8/8 PASS (final run)

| Case | Behavior | Run 1 | Run 2 |
|---|---|---|---|
| `tuned-temporal-recovery` | positive-now lifts mood to **good**; "meds" mention stays empty | ❌ ("medicines" leaked) | ✅ |
| `tuned-crash-override` | late crash → mood **low**, energy **sluggish** | ✅ | ✅ |
| `tuned-crash-then-recovery` | exact rule ordering → **good / sluggish / lockedIn** | ✅ | ✅ |
| `tuned-med-skipped` | "didn't take my Ritalin" → **taken:false** | ✅ | ✅ |
| `tuned-jitter-charged` | overstimulated → energy **charged** | ✅ | ✅ |
| `tuned-minimalist` | "Exhausted." → energy set, mood/focus/meds per tuned tables | ✅ | ✅ |
| `tuned-generic-med-stopword` | "took my meds" → no med entity | ✅ | ✅ |
| `tuned-past-emotion-excluded` | mood **good** (emotions leak tracked metrics-only) | ✅ | ✅ |

## Category metrics (48 cases, on-device, final run)

| Category | Precision | Recall | Δ vs Run 1 | Notes |
|---|---|---|---|---|
| mood | 0.581 | **0.857** | R +0.26 | New mood fallbacks/synonyms ("positive", "proud", …) landed |
| energy | 0.143 | 0.462 | — | Over-fires "steady"/"tired" on thin/neutral notes |
| focus | 0.316 | **0.750** | +0.17 | "sharp"/"flow"/"dialed in" additions landed |
| emotions | 0.263 | **1.000** | — | All labeled emotions caught; extras emitted |
| activities | 1.000 | **0.000** | — | Structural — see Open Finding 2 |
| meds | **0.941** | **0.941** | +0.15/+0.06 | ASR aliases ("Conserta"→Concerta) + stop-word fixes verified |
| sleepHours | 0.389 | 1.000 | — | Hallucinates 7.0 h on no-sleep-mention cases |
| topics | 0.136 | 0.667 | — | Free-form phrases — see Open Finding 1 |
| sideEffectFlag | 1.000 | **0.143** | — | Rarely populated — see Open Finding 3 |

Language split (final run): EN mood R≈0.86 carries the score; PT/ES mood remains weak (tuning is EN-only); ES meds 3/3.

## Latency on A14 (48 cases, ~11.5 min total)

| Metric | Run 1 | Run 2 |
|---|---|---|
| avg | 14.4 s | 14.4 s per check-in (both passes) |
| p95 | 27.4 s | **21.4 s** |
| max | 29.3 s | 27.1 s |
| EN short notes | ~6.3 s | ~6.3 s — matches the ~6.5 s blueprint estimate |

## Fixes applied (both repos, run-2 verified)

1. `genericMedStopWords` += `"medicines"`, `"none"`, `"med"` — model normalizes "meds"→"medicines" and hallucinates `{"name":"none"}` otherwise.
2. `moodSynonyms` += `"positive" → great` — model's go-to word on clearly-great days was clamping to nil.
3. Re-synced from macOS HEAD (2026-08-17 17:32): 15-rule validator, ASR phonetic aliases (fixes `en-med-asr-typo`), med dedup + "generic "-prefix strip, expanded synonym tables, lexicon += Melatonin/Magnesium/Magnesium Glycinate/L-Theanine.
4. Test hygiene: `"unfocused"` moved from the unmappable-clamp test to the synonym-mapping test (new table maps it → foggy). Suites green: iOS 44/44 targeted, macOS 44/44.

## Open findings (properties of the current tuning — candidates for the next macOS tuning pass)

1. **Topics are free-form phrases** ("crashed hard", "parking ticket") — 102 FPs vs TopicCategory labels. Validator caps count but has no allowlist; prompt only demonstrates "Medications". Decide: prompt-constrain topics, validator-allowlist, or accept phrases downstream.
2. **Activities always empty** (R=0.000). Validator filters to lexicon *category names*; prompt never teaches them and few-shots use non-category words that get filtered. Teach categories in the prompt or revisit the allowlist.
3. **sideEffects recall 0.143.** Model rarely populates `sideEffects` even for explicit symptoms (dry mouth, headache, appetite loss).
4. **Hallucinated sleepHours** (7.0 h) on no-sleep transcripts; occasional phantom `sleepQuality`. Null-discipline is the weakest 1.5B instruction.
5. **Energy over-fire** (P=0.143): "steady"/"tired" assigned on neutral notes. Partly label conservatism, partly real over-extraction.
6. **PT/ES mood** weak (PT mood R=0.000); multilingual tuning out of scope for the EN-focused macOS pass.
7. **Past-emotion leak**: "Yesterday I was… anxious" → emotions `["anxious"]` despite temporal rule 5; no deterministic guard exists.

## Validator wins observed in raw pass-2 output (port-fidelity evidence)

- `tuned-temporal-recovery`: model emitted `"mood": "sad"` (past) → positive-now rule produced final mood **good**.
- `tuned-crash-then-recovery`: model emitted `"good"/"high"` → crash rule → recovery rule → final **good / sluggish / lockedIn**, the exact specified ordering.
- `en-med-day` (non-targeted): crash rule produced `low / sluggish` for a morning-high/afternoon-crash note.
- Enum clamping caught axis confusions constantly: `"mood": "jittery"`, `"energy": "sharp"`, `"focus": "pretty sharp"` — clamped to nil, then recovered by deterministic fallbacks where applicable.

## Parity note (macOS ↔ device)

Port fidelity rests on: (a) `Prompts.yaml`, `PromptLoader`, `ExtractionValidator`, and `lexicon.json` are byte-identical to the macOS repo (verified by diff; only `Bundle.module`→`Bundle.main` and `print`→`AppLogger` adaptations), (b) identical 828.4 MB weights, greedy decoding on both, (c) observed rule firings match the tuned design exactly. A direct `JournalCLI` output spot-check was attempted but is blocked by a local build issue in the macOS repo (`default.metallib` not produced by its SwiftPM build — environment issue, unrelated to the tuning).

## Reproduction

```bash
# Full 48-case gate (device, model must be installed in the app container):
xcodebuild test -project app-four.xcodeproj -scheme app-four \
  -testPlan app-four-mlx-eval \
  -destination 'platform=iOS,id=00008101-000849EE0EB9003A' \
  -only-testing:app-fourTests/MLXExtractionEvalTests

# Quick 8-case smoke (tuned-* only):   -testPlan app-four-mlx-eval-smoke
# Memory gate (T036):                  -only-testing:app-fourTests/MLXMemoryGateTests
```

Notes: suites are inert in normal test runs (env-gated `MLX_EVAL=1` + model-presence check). Device must be unlocked for the runner to launch. If the model is absent, seed it: `xcrun devicectl device copy to --device <id> --source ~/Library/llm/models/mlx-community/Qwen2.5-1.5B-Instruct-4bit --destination "Library/llm/models/mlx-community/Qwen2.5-1.5B-Instruct-4bit" --domain-type appDataContainer --domain-identifier squirl-app.app-four`.

## Artifacts

- Final run xcresult: `~/Library/Developer/Xcode/DerivedData/app-four-fgtorzrcfyngybgexxulfkuebpxb/Logs/Test/Test-app-four-2026.08.17_17-50-30-+0100.xcresult` (raw pass-1/pass-2 output per case)
- Harness: `app-fourTests/Eval/MLXEvalSet.swift`, `MLXExtractionEvalTests.swift`, `MLXMemoryGateTests.swift`
- Test plans: `app-four-mlx-eval.xctestplan`, `app-four-mlx-eval-smoke.xctestplan` (referenced in the `app-four` scheme)
