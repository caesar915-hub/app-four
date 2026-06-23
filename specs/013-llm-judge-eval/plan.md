# Implementation Plan: LLM-Judge Evaluation Pipeline

**Branch**: `013-llm-judge-eval` | **Date**: 2026-06-23 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/013-llm-judge-eval/spec.md`

## Summary

Build an offline, reproducible evaluation harness (Python, under `spikes/extractor-eval/`) that uses **Claude Opus 4.8** as an LLM judge to: (A) re-audit the draft `goldSignals` labels on the 1082-post corpus into a trustworthy corrected-gold set, gated by validation against a ~100–150-post human calibration set (judge TNR ≥ 0.70 required); and (B) score the existing Swift extractor's dumped outputs against corrected gold — per-signal precision/recall/F1 for presence (mood/energy/focus/sleep) **and** per-item P/R/F1 for the richer fields (feelings/activities/sleep/side-effects) — reported as **bias-corrected** estimates with confidence intervals. Verdicts feed the existing browsable audit viewer.

**Judge backend (revised — no Anthropic API key available):** the judge is **Claude Code itself** (Opus 4.8 in-session / spawned subagents), not the Anthropic API. DeepEval and the Message Batches API are therefore **out** (both require an API key and an HTTP client DeepEval can wrap). The harness is a **thin custom Python pipeline**: it loads corpus + extractor dumps, builds per-post judge prompts, validates schema-conforming verdict JSON the judge writes back, and computes all metrics/gating/aggregation. The judging step itself is orchestrated by Claude Code over **checkpointed batches** (verdicts persisted per batch so a run resumes rather than restarts). Same model, $0 cost, but no 50%-batch-discount and subject to session limits — so the calibration pilot (~120 posts) runs before any full-corpus pass.

## Technical Context

**Language/Version**: Python 3.11 (existing `spikes/extractor-eval/.venv`)

**Primary Dependencies**: `pydantic` (verdict schema validation), `pytest` (tests). **No `anthropic` / `deepeval`** — the judge is Claude Code (in-session / subagents), not an API client. Reuse existing `make_eval_html.py` / `aggregate_judge.py`.

**Storage**: JSON / JSONL files under `spikes/extractor-eval/` (corpus, extractor dumps, verdicts, corrected gold, scorecard). No database.

**Testing**: `pytest`, test-first per Constitution X; extends existing `test_evalmetrics.py`.

**Target Platform**: local developer machine (macOS), offline tool. Not shipped in the app.

**Project Type**: single-project evaluation CLI + library (Python).

**Performance Goals**: calibration pilot (~120 posts) completes within one session; the full 1082-record passes run in checkpointed batches and **may span a session reset** (SC-006's <~1h target is best-effort, not guaranteed, without the Batch API). Cost: $0 (in-session judging).

**Constraints**: offline dev tool; operates only on the public Reddit corpus (never on-device user data); judging is bounded by Claude Code **session limits**, so verdicts are checkpointed to disk per batch and runs resume rather than restart.

**Scale/Scope**: 1082 posts × (4 presence signals + 4 richer fields) for re-audit + scoring; ~100–150-post human calibration set.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.* Constitution v1.2.0. This feature is **Python evaluation tooling**, not app/SwiftUI code, so the iOS-specific principles are N-A.

- [x] **I. SwiftUI-First** — **N-A**: no UI; command-line eval tooling.
- [x] **II. Test-Build-Ship** — **PASS** (adapted): the deliverable is verified by a green `pytest` suite for all harness logic; nothing is reported done unverified.
- [x] **III. Correctness Over Speed** — **PASS**: no stubs/dead code; the entire feature exists to make the extractor's measured quality *more* correct; tradeoffs (judge imperfection) surfaced as error bars.
- [x] **IV. Minimal Surface** — **PASS**: extends the existing `spikes/extractor-eval` harness and viewer. One new dependency (DeepEval) — a user-locked decision, justified in Complexity Tracking.
- [x] **V. Solo Git Discipline** — **N-A this command**: planning artifacts only; user is managing git in a separate session. Implementation MUST land on a `feat/…` branch with `/code-review` before merge (flagged for `/speckit-implement`).
- [x] **VI. On-Device Privacy** — **PASS**: judge runs offline on the **public** corpus only; no on-device user health/mood/medication data is sent anywhere; the judge is never part of the shipped app; DeepEval telemetry disabled.
- [x] **VII. Deterministic, Measured Extraction** — **PASS**: strengthens the eval harness that Principle VII relies on (sharper precision/recall floors); does **not** touch `NLNoteExtractor` or `lexicon.json`.
- [x] **VIII. Service-Oriented Architecture** — **N-A**: no app `Services/`; Python modules.
- [x] **IX. Pre-Release Data Posture** — **N-A**: no SwiftData schema change.
- [x] **X. Test-First Development** — **PASS**: harness logic (verdict parsing, confusion-matrix metrics, bias correction, gating) is built test-first (RED→GREEN→refactor), extending `test_evalmetrics.py`. Note: LLM-calling code is integration-tested against recorded fixtures, not live-mocked per call.

**Gate result: PASS** — no unjustified violations. One justified addition (DeepEval) tracked below.

## Project Structure

### Documentation (this feature)

```text
specs/013-llm-judge-eval/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (verdict + scorecard + changelog schemas)
└── tasks.md             # Phase 2 output (/speckit-tasks — NOT created here)
```

### Source Code (repository root)

```text
spikes/extractor-eval/
├── judge/                      # NEW — judge harness package
│   ├── __init__.py
│   ├── anthropic_judge.py      # DeepEvalBaseLLM wrapper around Opus 4.8 (sync + async + logprobs)
│   ├── prompt.py               # judge prompt + 7 span-level exclusion criteria + adversarial framing
│   ├── schema.py               # pydantic structured-output schemas (per-signal + richer-field verdicts)
│   ├── reaudit_gold.py         # re-audit 1082 draft goldSignals → corrected_gold + changelog
│   ├── calibration.py          # judge-vs-human agreement + TNR≥0.70 gate
│   ├── score_extractor.py      # bias-corrected P/R/F1 + confidence intervals
│   ├── metrics.py              # confusion-matrix, Rogan–Gladen bias correction, intervals
│   ├── ensemble.py             # disputed-case minority-veto re-judgment
│   └── batch.py                # Anthropic Message Batches submit/poll/collect (key by id)
├── tests/                      # NEW/extended — pytest, test-first
│   ├── test_metrics.py         # confusion matrix, bias correction, intervals
│   ├── test_schema.py          # verdict parse/validate, malformed handling
│   ├── test_calibration_gate.py# gate blocks below TNR 0.70
│   └── test_reaudit.py         # changelog correctness on fixtures
├── data/
│   ├── addrec_1082_summaries.jsonl   # corpus (existing)
│   └── calibration_labels.jsonl       # NEW — human gold for ~100–150 posts
├── out/
│   ├── verdicts_1082.json             # NEW — persisted per-signal+field verdicts
│   ├── corrected_gold.json            # NEW
│   ├── gold_changelog.json            # NEW
│   └── scorecard.json                 # NEW — bias-corrected P/R/F1 + CIs
├── aggregate_judge.py          # REUSE/extend — aggregate verdicts
└── make_eval_html.py           # REUSE/extend — regenerate eval_browser.html
```

**Structure Decision**: single Python package `judge/` inside the existing `spikes/extractor-eval/` spike, reusing the corpus, extractor dumps, aggregation, and HTML viewer already there. No app code touched.

## Complexity Tracking

| Addition | Why Needed | Simpler Alternative Rejected Because |
|----------|------------|--------------------------------------|
| DeepEval dependency | User-locked harness decision (#3 in the design dialogue); provides the judge-model abstraction, async execution, and metric scaffolding | A thin hand-rolled Batch-API script is simpler but the user explicitly chose the framework for its metric library and structure; rejected per their decision. DeepEval is confined to the `judge/` package, telemetry off, hosted platform unused — blast radius limited. |
| Bias-correction layer (Rogan–Gladen) | Spec FR-007/SC-004 require honest, judge-imperfection-adjusted metrics | Raw judge-vs-gold point estimates rejected: they inherit the judge's agreeableness bias and overstate extractor quality. |

## Phase Notes

- **Phase 0 (research.md)**: resolves the open *how* questions left by the spec's two Deferred items (ensemble veto rule, malformed-verdict handling) plus the implementation specifics of the locked decisions (DeepEval+Anthropic wrapper, structured outputs vs. G-Eval, Batch API, bias-correction math, telemetry posture).
- **Phase 1 (data-model.md, contracts/, quickstart.md)**: formalizes the verdict / corrected-gold / scorecard schemas (grounded in the real `extractions_500.json` and `judge_verdicts.json` shapes) and the end-to-end run guide.
- **Agent context (CLAUDE.md `<!-- SPECKIT -->` pointer)**: intentionally **not** modified here — the parallel session is on `008-mockup-parity` and relies on that pointer; flagged in the completion report instead of clobbered.
