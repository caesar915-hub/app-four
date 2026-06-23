# Quickstart: LLM-Judge Evaluation Pipeline

End-to-end validation guide. All paths relative to `spikes/extractor-eval/`. This is an **offline developer tool** — it runs on the public corpus and calls only the Anthropic API.

## Prerequisites

- `spikes/extractor-eval/.venv` (Python 3.11) with `anthropic`, `deepeval`, `pydantic`, `pytest`.
- `ANTHROPIC_API_KEY` exported in the environment.
- Telemetry off (Constitution VI): `export DEEPEVAL_TELEMETRY_OPT_OUT=YES ERROR_REPORTING=NO`. Do **not** `deepeval login`.
- Inputs present: `data/addrec_1082_summaries.jsonl` (corpus), `out/extractions_500.json` (extractor dump).

## Step 0 — Tests first (Constitution X)

```
.venv/bin/pytest tests/
```
Expected: harness-logic tests (metrics, schema parse, calibration gate, changelog) pass. These are written **before** their implementations (RED→GREEN).

## Step 1 — Build the calibration set

Hand-label ~120 stratified posts → `data/calibration_labels.jsonl` (pure / noise / ambiguous; seed from `eval_browser.html` FP/FN cards). See data-model.md → CalibrationRecord.

## Step 2 — Validate the judge (gate)

```
.venv/bin/python -m judge.calibration
```
Expected: writes `out/judge_agreement.json` with per-signal TPR/FPR/TNR. **Gate** — if any signal's `tnr < 0.70`, the command exits non-zero with a message to revise `judge/prompt.py`; bulk steps refuse to run (FR-006 / SC-002). Iterate the prompt until the gate clears.

## Step 3 — Re-audit the gold (bulk, Batch API)

```
.venv/bin/python -m judge.reaudit_gold
```
Expected: `out/corrected_gold.json` + `out/gold_changelog.json`. The summary prints the flip count and flags if it exceeds the configured fraction (Edge: heavy disagreement). Completes in under ~1h (SC-006).

## Step 4 — Score the extractor (bulk, bias-corrected)

```
.venv/bin/python -m judge.score_extractor
```
Expected: `out/verdicts_1082.json` (per-signal + per-field verdicts) and `out/scorecard.json` — Rogan–Gladen bias-corrected P/R/F1 with CIs for the 4 signals and 4 richer fields (FR-007, FR-008, SC-004). Quarantined records (if any) land in `out/verdicts_quarantine.json` and are counted.

## Step 5 — Harden disputed cases (optional, P3)

```
.venv/bin/python -m judge.ensemble
```
Expected: judge-vs-extractor disagreements re-judged 3× with minority veto; unanimous confirmations stick, splits set `needs_human_review` (FR-012 / R5).

## Step 6 — Regenerate the audit viewer

```
.venv/bin/python make_eval_html.py
```
Expected: `eval_browser.html` rebuilt from `out/verdicts_1082.json` — filter by signal × {FP, FN}, inspect each post's text + extractor output + verdict + reason; changed gold labels show before/after + reason (FR-010, FR-011, SC-005). Re-running on the same verdicts yields an identical scorecard (SC-007).

## Acceptance checks (map to Success Criteria)

| Check | Criterion |
|-------|-----------|
| All 1082 posts have 4 signal verdicts | SC-001 |
| Gate blocks below TNR 0.70; agreement reported | SC-002 |
| Every flipped gold label listed with reason | SC-003 |
| Scorecard shows corrected P/R/F1 + CIs, not bare points | SC-004 |
| Every FP/FN inspectable in viewer with reason | SC-005 |
| Bulk run < ~1h, low cost | SC-006 |
| Re-aggregation reproducible | SC-007 |
