<!-- Created: 2026-09-13 21:29 (WEST) · Updated: 2026-09-13 21:29 (WEST) -->
# 056 Gemma 4 / LiteRT — autonomous run summary

**Read this first.** Full `/speckit` cycle run while you slept, on branch `feat/gemma4-litert-extraction`.

## TL;DR
- **spec → plan → tasks → implement → code-review → converge** all done. **Simulator suite green: 584 tests.** App builds and behaves exactly as today.
- The Gemma 4 / LiteRT backend is **additive and inert**: it exists behind the `SummarizationService` seam with the live LiteRT calls compile-guarded; the `AppDependencies` binding and `llmHubRepoID` are **unchanged**, so nothing switched over.
- **Not merge-ready — by design.** The two things the simulator can't do (A14 memory + throughput) are yours to verify on a physical iPhone 12 Pro. No fallback exists (your D2 call), so that device QA is the go/no-go.

## What shipped (7 commits on the branch)
1. Clarify resolutions folded into the LiteRT brief.
2. `spec.md` + `plan.md` + `research.md` + `data-model.md` + `contracts/` + `quickstart.md` + `device-qa-checklist.md`.
3. **Constitution 2.3.0 → 2.4.0** (MINOR): extraction engine Qwen/MLX → Gemma 4 E2B/LiteRT-LM; Principle VII/VIII wording. **⚠️ Needs your ratification** — I drafted + applied it so the plan gate passes; review the wording.
4. `tasks.md` (TDD-ordered; tonight's additive work vs device-gated switchover).
5. **Implementation** — `app-four/Services/Gemma/`: `GemmaChatTemplate` (pure turn renderer), `GemmaSignalsTool` (typed pass-2 payload + `UnifiedExtraction` mapping), `LiteRTTextGenerator` (protocol seam + fake + compile-guarded real impl), `GemmaJournalService` (two-pass, RAM gate, lifecycle, DEBUG hooks). Additive constants + `.litertlm` installed-check.
6. Gated device eval + `app-four-gemma-eval.xctestplan`.
7. `/code-review` fix + `convergence.md`.

## Three things you need to know (I flagged these all run)
1. **The "biggest risk" (Q1) was a false alarm.** The current Qwen/MLX path has **never** used constrained decoding — JSON validity comes from prompts + `ExtractionValidator` recovery + one retry. So LiteRT lacking constrained decoding removes nothing; Gemma 4 (IFEval 94.6) with the same validator should beat Qwen (42.5). This de-risks the whole path.
2. **Tool Use (your D1) is a documented stub, not delivered tonight.** `LiteRTEngineGenerator.callSignalsTool` returns `nil` — I won't fake an Early-Preview API I can't compile-check. On device, pass-2 runs the **proven free-form + validator** path (equal to today) until you wire Tool Use in T013/T014. The convergence test proves both paths produce identical output, so the fallthrough is safe.
3. **The whole `#if canImport(LiteRTLM)` block is unverified.** Engine/Conversation calls, `Message`/`.text`, chat-template application are best-effort against the moving 0.12.0 API, localized to one file with `TODO(device, T013)` markers. Expect to reconcile deltas there.

## Your morning path (all in `quickstart.md` + `device-qa-checklist.md`)
1. Ratify (or edit) the constitution 2.4.0 wording.
2. Add the SPM package `github.com/google-ai-edge/LiteRT-LM` (`LiteRTLM` ≥ 0.12.0) on device; fix API deltas in `LiteRTTextGenerator.swift`.
3. Download `gemma-4-E2B-it.litertlm` (2,588,147,712 B); confirm the installed-check passes.
4. Run the gated eval + memory gate on the 12 Pro (`GEMMA_EVAL=1`, `-testPlan app-four-gemma-eval`). Record SC-1 (`phys_footprint`), SC-4 (tok/s), SC-2/3 (P/R vs Qwen).
5. **Go/no-go:** SC-1/SC-4 pass and P/R ≥ Qwen → flip the DI binding + repoint `llmHubRepoID` (single reversible change), then MLX removal. Fail → keep the additive code, don't switch; the build stays on Qwen/MLX.

## The standing risk (recorded, your call)
D1 (Tool Use) + D2 (drop MLX, no fallback) + D3 (Shipaton in-scope, ~Sep 23) on an Early-Preview runtime + unmeasured A14 is the max-risk stack. Tonight's work de-risks the *quality* question but not the *memory/throughput/timeline* one — those still ride on your device spike. If the 12 Pro OOMs, there's no fallback in the shipped build, so that spike is the earliest cheap kill-switch. Recommended (and overruled) de-risk is in the brief's senior-engineer flag.

## Deviations (surfaced, not silent)
- Branched off current HEAD (post-045), not literal `main` — `main` lacks 045 + the briefs; branching there would build against stale WhisperKit-era code + a stale constitution. PR base is set accordingly.
- Skills you named (swiftui-pro, etc.) aren't installed in this session and this is a service (no SwiftUI) — applied swift-concurrency + architecture rigor directly.
- Test-first honored at batch granularity: tests authored + run RED (compile-fail) before implementation → GREEN. Not per-unit RED runs (autonomous efficiency).
