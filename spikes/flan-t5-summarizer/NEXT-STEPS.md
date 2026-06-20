# Path to a Ship Decision — Real-Data Validation Actions

**Why this exists:** the v3 evaluation ([EVALUATION.md](EVALUATION.md)) is conservative by design.
Its root-cause lesson (see EVALUATION §1 / METHODOLOGY) is that the spike ran as a **closed
self-evaluation loop** — Claude generated the data, the prompts, and was the judge. Every fix
added an *external anchor*. Shipping requires finishing that job: replacing the last synthetic /
self-referential pieces with real, externally-validated ones. **No ship decision until every box
below is checked.**

## A. Break the closed loop (each action = one external anchor)

- [ ] **A1 — Real transcripts.** Replace the synthetic 100 with real ADHD voice notes (consented
  user data or a public corpus). Transcribe with the on-device path (faster-whisper-base is cached).
  Mental-health data → handle PII/consent explicitly before anything else.
- [ ] **A2 — Powered held-out.** Hold out enough *real* entries that the safety gate has tight CIs.
  Rule of three: 0 fabrications in 150 → upper bound ≈2% at 95%; in 300 → ≈1%. Target **≥150–300**
  real held-out entries, never used for any tuning. (Current test-30 only bounds fabrication at ~11%.)
- [ ] **A3 — Multi-annotator gold + IAA.** The current gold is single-annotator (κ not computed).
  On the real held-out, ≥2 independent human annotators label gold signals on a subset; report
  Cohen's κ / Krippendorff's α. Breaks the Claude-as-gold loop.
- [ ] **A4 — Second external faithfulness instrument.** MiniCheck is external; add a second family
  (QAFactEval, or structured human review) so the verdict isn't single-instrument. Keep the cascade
  (MiniCheck recall → human precision).
- [ ] **A5 — Human-in-the-loop gate.** Run the cascade on the real held-out; every MiniCheck-flagged
  entry goes to a **human** (not Claude). Ship requires the review queue adjudicated **empty**.
- [ ] **A6 — Pre-register the gate.** Fix the thresholds *before* running, to prevent post-hoc bar-moving:
  fabrication-rate 95% CI upper bound **< X%** (propose X=2), signal-recall **≥ Y%** (propose Y=85),
  fallback ≤ 20%, on the real held-out.
- [ ] **A7 — Pin for reproducibility.** Record HF model revision hashes + exact decoding config +
  adapter checksum. (The mid-spike HF cache eviction is why this is non-optional.)

## B. Decision gate (run once A1–A7 are in place)
Ship **iff**, on the real held-out: fabrication CI upper bound < X%, signal-recall ≥ Y%, human queue empty.
Otherwise → iterate (LoRA spike below, or two-pass architecture) and re-gate.

## Dependencies
A1 blocks everything. A3/A5 need human annotators (the one thing Claude cannot be). The
[LoRA spike](LORA-SPIKE-SCOPE.md) can start in parallel on existing data, but its *gate* still waits on A1–A2.
