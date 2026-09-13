<!-- Created: 2026-09-13 21:30 (WEST) · Updated: 2026-09-13 21:30 (WEST) -->
# Convergence — 056 Gemma 4 / LiteRT extraction

Autonomous `/code-review` + build/test convergence for `feat/gemma4-litert-extraction`.

## Code Review: Gemma 4 E2B / LiteRT-LM backend

### Summary
Additive/inert extraction backend behind the existing `SummarizationService` seam. The full simulator suite is green (582 tests) and behaviour is unchanged (DI binding + `llmHubRepoID` untouched). **No critical or blocking bugs.** The dominant caveat is transparency, not correctness: the live LiteRT runtime is compile-guarded and unverified, and the Tool-Use (D1) path is a documented stub that returns nil until device-day wiring — so on-device pass-2 runs the proven free-form path until T013/T014. Ready to merge only after owner device QA (SC-1/SC-4), per constitution II/V.

### Findings

#### Critical
- None.

#### Major
- **[MAJ-1] Tool Use (D1) is not functional yet** — `LiteRTTextGenerator.swift` `LiteRTEngineGenerator.callSignalsTool` returns `nil` (documented stub). The owner chose D1 (Tool Use) as the pass-2 strategy, but it activates only at device-day (T013/T014); until then pass-2 uses the free-form + validator fallthrough (proven Qwen-equivalent). Not a bug — intentional and documented — but the owner must know D1 is a device-day activation, not delivered tonight. *Action:* elevated in RUN_SUMMARY; the free-form path fully carries pass-2 in the meantime.
- **[MAJ-2] Live LiteRT wiring is unverified** — the entire `#if canImport(LiteRTLM)` block (Engine/Conversation calls, `Message`/`.text`, chat-template application) is best-effort against an Early-Preview API and cannot compile-check here. *Action:* localized to one file with explicit `TODO(device, T013)` markers; reconcile on device. Accepted risk (D3).

#### Minor
- **[MIN-1] Installed-check is exact-size** — `AIModelServiceImpl.gemmaLiteRTModelInstalled` requires `size == gemmaLiteRTExpectedBytes`. Brittle if the HF repo re-publishes at a different size; matches the download service's exact-size completeness convention, so acceptable. Revisit if the repo updates.
- **[MIN-2] Possible double chat-templating** — `LiteRTEngineGenerator.generate` applies `GemmaChatTemplate.singleTurn` then calls `Conversation.sendMessage`; if Conversation re-applies a template from `.litertlm` metadata, output degrades. Flagged `TODO(device)`.
- **[MIN-3] Memory floor recalibration** — fixed this pass (1.5 GB → 1 GB, Gemma-appropriate); still a placeholder until the A14 `phys_footprint` is measured.
- **[MIN-4] `FakeLiteRTGenerator`/`SignalsToolArguments` are `public`** — slightly wider than needed (`@testable` sees internal); harmless, DEBUG-gated for the fake.

#### Positive
- **[POS-1] Clean runtime seam** — `LiteRTTextGenerator` protocol makes the whole two-pass pipeline hermetically testable with `FakeLiteRTGenerator`; no test touches the runtime.
- **[POS-2] Maximal reuse** — `ExtractionValidator`, prompts, lexicon, `SummaryResult`, `UnifiedExtraction`, and the download pipeline are reused verbatim; the convergence invariant test proves the tool and free-form paths produce identical `UnifiedExtraction`.
- **[POS-3] Additive/inert + compile guard** — keeps `main` releasable and the simulator green without the Early-Preview dependency; switchover is a single reversible change.
- **[POS-4] Lifecycle parity** — RAM gate + background/memory-warning/idle eviction mirror the proven `MLXJournalService` design, with the same DEBUG hooks for hermetic lifecycle tests.

### Suggested tests (device day)
- Real tool-call decode → `SignalsToolArguments` once D1 is wired (T014).
- Double-templating guard: assert the on-device prompt isn't wrapped twice.
- Recalibrated P/R vs `MLXEvalFloors` on device (SC-2/SC-3).

## FR / SC coverage

| Requirement | State |
|---|---|
| FR-001 SummarizationService conformance | ✅ `GemmaJournalService` + tests |
| FR-002 load by file path | ✅ (guarded impl) |
| FR-003 text-only | ✅ vision/audio backends nil |
| FR-004 app renders chat template | ✅ `GemmaChatTemplate` + tests |
| FR-005 Tool Use → free-form fallthrough | ⚠️ free-form ✅; Tool Use stub (device-day) |
| FR-006 reuse ExtractionValidator + lexicon | ✅ verbatim |
| FR-007 bound thinking | ⚠️ TODO in guarded impl (device-day) |
| FR-008 single-file download + installed-check | ✅ installed-check + constants; download repoint = switchover |
| FR-009 RAM gate + sequential residency | ✅ `checkMemoryHeadroom` + load gate |
| FR-010 unload on background/warning/idle | ✅ LifecycleCoordinator + tests |
| FR-011 typed errors, never lose transcript | ✅ tests (unparseable → transcript retained) |
| FR-012 no fallback on gate-fail (D2) | ✅ throws `.insufficientMemory`, no fallback |
| FR-013 additive/inert; switchover gated | ✅ DI + repoint untouched |
| FR-014 privacy-safe diagnostics | ✅ counts/states only |
| FR-015 DEBUG test hooks parity | ✅ |
| SC-1 device memory | ⏳ device-gated (eval + checklist) |
| SC-2/2a/3 quality | ⏳ device-gated (gated eval) |
| SC-4 throughput | ⏳ device-gated |
| SC-5 suite green, no VM/View edits | ✅ 582 tests green |
| SC-6 builds/behaves as today (inert) | ✅ |

## Build / test state
- Baseline (pre-change) green; post-implementation green (582 tests); post-review-fix re-run green.
- Simulator: iPhone 17 Pro (iOS 26). Device gates (SC-1/SC-4) NOT verifiable here.
