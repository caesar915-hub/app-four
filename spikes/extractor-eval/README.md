# LLM-Judge Evaluation Pipeline (spec 013)

Offline harness that uses **Claude Code (Opus 4.8, no API key)** as the judge to
(A) re-audit the draft `signals` gold and (B) score the extractor's dumped output —
per-signal presence (mood/energy/focus/sleep) + richer-field item sets — against it.

**No external network calls.** Judging is done in-session by Claude Code; only the
public corpus is read. No telemetry, no API key, no cloud (Constitution VI).

## Layout

- `judge/` — `schema` (verdict validation), `metrics` (confusion + P/R/F1 + Rogan–Gladen),
  `io` (loaders, `sleepHours`→sleep), `backend` (JudgeBackend seam), `prompt` (7 exclusions,
  adversarial), `batch` (resumable checkpointed store), `calibration` (agreement + TNR gate),
  `reaudit` (corrected gold + changelog), `ensemble` (minority veto), `score` / `viewer`.
- `tests/` — pytest, test-first.
- `data/addrec_1082_summaries.jsonl` — corpus (1082 posts; 1037 unique ids).
- `out/verdicts_1082.json` — checkpointed verdicts (resumes, never restarts).

## Run

```bash
.venv/bin/python -m pytest -q          # all logic tests
.venv/bin/python run_pilot.py          # calibration pilot + gate (reference vs judge)
.venv/bin/python -m judge.score        # extractor scorecard from current verdicts
.venv/bin/python run_outputs.py        # emit corrected_gold/changelog/scorecard/agreement + eval_browser.html
```

Bulk judging proceeds in checkpointed batches (Claude Code reads a worksheet of
unjudged posts, writes verdicts, `judge.batch.ingest` validates + appends).

## Caveat

The calibration "reference" labels are produced by the same model as the judge
(lenient vs strict framing), so the TNR gate reflects self-consistency, **not**
validated accuracy. Independent human labels are needed to trust the gate / bias bars.
