# Contract: Pipeline output artifacts

All written under `spikes/extractor-eval/out/`. Every artifact is keyed by post `id`.

## `corrected_gold.json`

```json
[ { "id": "uuid", "signals": ["mood", "focus"] } ]
```
Judge-confirmed present signals per post (FR-004).

## `gold_changelog.json`

```json
[ { "id": "uuid", "signal": "mood", "from": "present", "to": "absent",
    "reason": "mood=good unsupported; dry generic comparison" } ]
```
One entry per draft label the re-audit flipped (FR-004, FR-011). The run summary reports the total flip count and flags if it exceeds a configurable fraction of the corpus (Edge: heavy disagreement).

## `judge_agreement.json`

```json
[ { "signal": "focus", "tpr": 0.93, "fpr": 0.11, "tnr": 0.89, "n": 120 } ]
```
Per-signal judge-vs-human agreement on the calibration set (FR-005). **Gate**: if any `tnr` < 0.70 the bulk run is blocked (FR-006 / SC-002).

## `scorecard.json`

```json
[ { "target": "focus", "kind": "signal",
    "precision": { "point": 0.71, "ci_low": 0.63, "ci_high": 0.79 },
    "recall":    { "point": 0.66, "ci_low": 0.57, "ci_high": 0.74 },
    "f1":        { "point": 0.68, "ci_low": 0.60, "ci_high": 0.76 },
    "raw": { "tp": 80, "fp": 33, "fn": 41, "tn": 314 } } ]
```
Bias-corrected (Rogan–Gladen, R4) per-signal and per-richer-field metrics with confidence intervals (FR-007, SC-004). `kind` ∈ `signal | field`. `raw` carries the uncorrected counts for audit.

## `verdicts_1082.json`

The persisted per-post verdicts (SignalVerdict + RicherFieldVerdict shape from data-model.md), the single source `aggregate_judge.py` / `make_eval_html.py` read to regenerate `eval_browser.html` (FR-010, FR-011). Re-aggregation from this file is deterministic (FR-015 / SC-007).

## `verdicts_quarantine.json`

Records whose judgment failed the schema twice (R6) — excluded from metrics, counted in the run summary.
