# Phase 0 Research: LLM-Judge Evaluation Pipeline

All decisions below resolve either the spec's two **Deferred** items or the *how* of the spec's locked Assumptions. No `NEEDS CLARIFICATION` markers remain.

## R1. Judge backend: Claude Code (no API key) — REVISED

- **Decision**: The judge is **Claude Code itself** (Opus 4.8, this session / spawned subagents), **not** the Anthropic API. A judge step takes a batch of posts + the prompt and writes schema-conforming verdict JSON (contracts/judge-verdict.schema.md). Python defines a `JudgeBackend` seam (`judge/backend.py`) with a `judge_batch(posts) -> list[verdict]` method; the Claude Code implementation is driven by the orchestrator (assistant / Workflow), not by Python calling an API.
- **Rationale**: No `ANTHROPIC_API_KEY` is available, so DeepEval (which wraps an HTTP client) and `anthropic.Anthropic()` cannot run. Claude Code delivers the *same* Opus 4.8 judge at $0 cost. The harness reverts to a thin custom pipeline; the `JudgeBackend` seam keeps an API implementation droppable in later if a key appears.
- **Alternatives considered**: DeepEval + Anthropic API (original plan — blocked by no key); a local/Ollama judge (rejected — weaker judge defeats the agreeableness-bias purpose); OpenAI/GPT (no key, and stay in-family).
- **Constraint**: Claude Code **session limits** bound throughput (we hit the wall on `/deep-research`). Mitigation: checkpoint verdicts per batch to disk; calibration pilot (~120) before any full-corpus pass; the bulk passes may span a session reset and resume.

## R2. Verdict mechanism: structured outputs, not G-Eval scoring

- **Decision**: Do **not** use G-Eval's 1–5 token-probability scorer. Drive the judge with a **custom prompt** that returns schema-constrained JSON (Anthropic `output_config.format` / `messages.parse()` with a pydantic model), one reason+verdict per signal and per richer-field item.
- **Rationale**: The spec mandates confusion-matrix labels (TP/FP/FN/TN), not quality scores. G-Eval is built for holistic 1–5 quality scoring; its `strict_mode`/`rubric` features can binarize but don't naturally express per-signal four-way labels with per-item richer-field sets. Structured outputs guarantee the shape (FR-010, FR-014).
- **Alternatives considered**: G-Eval `rubric` + `strict_mode=True` (binary only, loses FN vs FP distinction); free-text parsed with regex (brittle — rejected by FR-014's malformed-handling requirement).

## R3. Bulk execution: checkpointed agentic batches — REVISED

- **Decision**: With no API key, the Message Batches API is unavailable. The 1082-record re-audit + scoring run as **checkpointed batches of ~25–50 posts**: the orchestrator hands each batch to the Claude Code judge, the returned verdict JSON is validated and **appended to disk before the next batch** (`out/verdicts_1082.json` written incrementally, keyed by post `id`). A run records which ids are done and **resumes from the first unjudged id** — never restarts.
- **Rationale**: Persisting per batch makes the run robust to session limits (the real constraint here). Id-keying is still mandatory (FR-014). Batch size ~25–50 balances per-call overhead against context size.
- **Alternatives considered**: Anthropic Batch API (50% off, <1h — blocked, no key); one giant fan-out (rejected — risks the session wall mid-run with nothing checkpointed, exactly the `/deep-research` failure).

## R4. Bias correction: Rogan–Gladen on judge TPR/FPR

- **Decision**: From the calibration set, estimate the judge's per-signal sensitivity (TPR) and specificity (1−FPR). Correct each extractor metric with the Rogan–Gladen adjustment (prediction-powered-inference style): `prevalence_true = (observed + spec − 1) / (sens + spec − 1)`, propagating a confidence interval that combines calibration uncertainty and corpus sampling.
- **Rationale**: Spec FR-007/SC-004 require estimates that *remove agreeableness inflation*, not raw judge agreement. Rogan–Gladen is the standard imperfect-classifier correction; it directly consumes the calibration TPR/FPR the pipeline already measures.
- **Alternatives considered**: plain Wilson CI on raw numbers (no bias removal — rejected); full PPI++ (heavier; the Rogan–Gladen point + bootstrap CI is sufficient at n≈1082).

## R5. Ensemble veto rule (resolves Deferred #1, FR-012)

- **Decision**: On judge-vs-extractor disagreements, run the judge **3×** (varied by reordering/seed framing). Apply **minority veto**: confirm the disagreement verdict only if **all 3** concur; any split → flag the record `needs_human_review` rather than auto-accepting either side.
- **Rationale**: The research corpus (arxiv 2510.11822) found minority-veto beats majority-voting for the false-negative blindspot — the exact failure mode (judge over-agrees, misses extractor errors). Confirming only on unanimity is the conservative choice for the consequential disputed cases.
- **Alternatives considered**: majority (2/3) voting (weaker on the FN blindspot); single pass (no hardening — that's the un-ensembled default for non-disputed records).

## R6. Malformed-verdict handling (resolves Deferred #2, FR-014)

- **Decision**: **Retry once** on a schema-invalid or missing judgment; if it still fails, **quarantine** the record into `out/verdicts_quarantine.json` (excluded from metrics, surfaced in the run summary count). Never coerce or silently drop.
- **Rationale**: Structured outputs make malformed responses rare; a single retry absorbs transients, quarantine keeps the scorecard honest (a dropped record would bias metrics; a coerced one would fabricate a verdict).
- **Alternatives considered**: infinite retry (cost/latency risk); silent skip (rejected by FR-014).

## R7. Calibration set construction

- **Decision**: ~120 posts, stratified ≈ 40 pure-signal / 40 noise (exclusion-trap) / 40 ambiguous, seeded from the existing `eval_browser.html` FP/FN cards plus a random draw across the 1082. Human labels stored in `data/calibration_labels.jsonl` (per-post per-signal presence + richer-field items).
- **Rationale**: Spec Assumptions specify developer-labeled ~100–150 stratified posts; trap/ambiguous strata are where the judge's TNR (the gated metric) is actually stressed. n≈120 gives usable interval widths at corpus scale.
- **Alternatives considered**: pure random sample (under-samples the hard absent-signal cases the gate depends on).

## R8. Privacy posture for DeepEval (Constitution VI)

- **Decision**: Set `DEEPEVAL_TELEMETRY_OPT_OUT=YES` (and `ERROR_REPORTING=NO`); do **not** `deepeval login` / use the Confident-AI hosted platform. All judge traffic goes only to the Anthropic API.
- **Rationale**: Principle VI bars cloud-by-default for user data. The corpus is public, but disabling telemetry and avoiding the hosted platform keeps the tool's network surface to Anthropic alone and avoids any incidental upload of eval content.
- **Alternatives considered**: default DeepEval (sends anonymous telemetry; hosted platform optional) — tightened off for hygiene.

## R9. Verdict vocabulary reconciliation

- **Decision**: Canonical presence labels are **TP / FP / FN / TN** (spec). Map the existing `judge_verdicts.json` vocabulary: `correct→TP`, `false_positive→FP`, `missed→FN`, `na→TN`. Keep `partial` as a **secondary quality flag** on a TP (the value is right-ish but imprecise, e.g. `focus="foggy"` for a genuine but mischaracterized signal) — it does not change the confusion-matrix cell.
- **Rationale**: Preserves comparability with the prior run and the existing `make_eval_html.py` color coding while giving the spec's clean four-way matrix. `partial` carried real signal in the old data and shouldn't be lost.
- **Alternatives considered**: drop `partial` (loses nuance the viewer already shows); make `partial` a 5th matrix cell (breaks standard P/R/F1).
