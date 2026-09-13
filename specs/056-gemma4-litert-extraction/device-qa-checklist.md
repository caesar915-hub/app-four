# Device QA Checklist (owner) — iPhone 12 Pro (A14, 6 GB)

These verify the two things the simulator cannot (SC-1, SC-4) and the quality gates (SC-2/2a/3). **Load-bearing: with D2 there is no fallback**, so a failure here means the Shipaton build must not switch over.

## Pre-req
- [ ] LiteRTLM SPM package added; app builds for device (Release-like config).
- [ ] `gemma-4-E2B-it.litertlm` (2,588,147,712 B) downloaded; installed-check passes.
- [ ] CPU/XNNPACK backend (`.cpu()`); `visionBackend`/`audioBackend` nil (text-only).

## SC-1 — Memory (no jetsam)
- [ ] Instrument resident memory via `task_vm_info.phys_footprint` around a full two-pass `summarize`.
- [ ] Record peak resident (target ≲ ~607 MB CPU; must clear the device ceiling). Log the number + backend.
- [ ] Run 10 consecutive extractions; confirm no jetsam kill, no unbounded growth (KV cache is the only dirty lever).
- [ ] Background the app mid-run; confirm the engine evicts (memory drops) and re-loads cleanly on return.

## SC-4 — Throughput / thermals
- [ ] Sustained decode ≥ ~8 tok/s (CPU) across the two passes; record tok/s.
- [ ] Thermal state stays ≤ `.fair` over 10 runs (no `.serious`/`.critical`).

## SC-2 / SC-2a / SC-3 — Quality
- [ ] Run the gated eval on device: `GEMMA_EVAL=1`, `-testPlan app-four-gemma-eval`.
- [ ] Post-validator JSON/tool validity ≥ Qwen baseline (SC-2).
- [ ] Tool-call schema-conformance rate recorded (SC-2a).
- [ ] Micro-averaged signal P/R ≥ Qwen baseline; expect higher (SC-3). Compare to `MLXEvalFloors`.
- [ ] Spot-check the `tuned-*` hard-gate cases (mood/energy/focus/meds correctness).

## Thinking / output hygiene
- [ ] Confirm pass-2 emits the tool call / JSON with NO reasoning preamble (thinking budget ≈ 0).
- [ ] Confirm the free-form fallthrough triggers correctly when tool-calling is suppressed (temporarily disable the tool to test Path B).

## Go / No-Go
- [ ] All SC-1/SC-4 pass AND SC-2/SC-3 ≥ baseline ⇒ proceed to switchover.
- [ ] Any memory/thermal failure ⇒ DO NOT switch over; the Shipaton build stays on Qwen/MLX (revert plan: keep the additive code, do not flip DI). Re-open the D2/D3 decision with the owner.
