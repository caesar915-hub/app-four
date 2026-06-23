---
description: "Task list for LLM-Judge Evaluation Pipeline"
---

# Tasks: LLM-Judge Evaluation Pipeline

**Input**: Design documents from `specs/013-llm-judge-eval/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Test-first is **MANDATORY** for all harness logic (verdict parsing, confusion-matrix metrics, bias correction, gating, ensemble) per Constitution **Principle X** — write the test, run it, confirm it **FAILS (RED)**, then implement to **GREEN**, then refactor. This is **Python tooling**, so tests use **pytest** (not Swift Testing — that clause of the constitution targets app code); the test-first discipline still applies. There are no SwiftUI views here, so nothing is exempt.

**Working directory**: all source/test paths are under `spikes/extractor-eval/`.

**Organization**: grouped by user story (spec.md priorities) for independent implementation + testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: parallelizable (different file, no incomplete dependency)
- **[Story]**: US1–US4 (user-story phases only)

---

## Phase 1: Setup (Shared Infrastructure)

- [x] T001 Create `judge/` package (`judge/__init__.py`) and `tests/` dir under `spikes/extractor-eval/` per plan.md structure
- [x] T002 Add + pin deps (`pydantic`, `pytest` only — **no `anthropic`/`deepeval`**, judge is Claude Code) in `spikes/extractor-eval/requirements-judge.txt`
- [x] T003 [P] Privacy note: harness makes **no external network calls** (judging is in-session Claude Code, public corpus only); document in `spikes/extractor-eval/README.md` (Constitution VI, research R8)

---

## Phase 2: Foundational (Blocking Prerequisites)

**⚠️ CRITICAL**: No user story can begin until this phase completes — every story depends on the judge wrapper, prompt, schema, loaders, batch runner, and metric core.

### Tests (test-first · RED — MANDATORY) ⚠️

> Write FIRST and RUN — must FAIL before implementation.

- [x] T004 [P] Verdict-schema test: valid parse + malformed→retry-once-then-quarantine behavior, in `tests/test_schema.py` (contracts/judge-verdict.schema.md, research R6)
- [x] T005 [P] Metric-core test: TP/FP/FN/TN → precision/recall/F1, in `tests/test_metrics.py`
- [x] T006 [P] IO test: corpus + extractor loaders join by `id` (never position), in `tests/test_io.py` (FR-014)

### Implementation

- [x] T007 [P] pydantic verdict schemas (`SignalVerdict`, `RicherFieldVerdict`) per contracts in `judge/schema.py`
- [x] T008 [P] Judge prompt: 7 span-level exclusions + adversarial over-extraction framing + reason-before-verdict, in `judge/prompt.py` (FR-002, FR-003, FR-009)
- [x] T009 Confusion-matrix + P/R/F1 core in `judge/metrics.py` (makes T005 GREEN)
- [x] T010 [P] `JudgeBackend` seam (`judge_batch(posts) -> list[verdict]`) + a recorded-fixture backend for tests, in `judge/backend.py`; the live backend is Claude Code judging in-session (research R1, R2)
- [x] T011 Checkpointed batch runner: split posts into ~25–50-id batches, append validated verdicts to disk per batch keyed by `id`, resume from first unjudged id, retry-once-then-quarantine, in `judge/batch.py` (research R3, R6; depends T007)
- [x] T012 Corpus + extractor loaders with id-join in `judge/io.py` (makes T006 GREEN; data-model.md CorpusPost/ExtractorOutput)

**Checkpoint**: judge can be called on one post and return a schema-valid verdict; metrics + loaders proven.

---

## Phase 3: User Story 1 - Trustworthy corrected gold (Priority: P1) 🎯 MVP foundation

**Goal**: A calibration-gated re-audit that turns the draft `signals` into corrected gold, with a change log — only trusted if judge TNR ≥ 0.70.

**Independent Test**: run on the calibration set → `judge_agreement.json` reports per-signal TPR/FPR/TNR and the gate blocks the bulk run below 0.70; run the re-audit → `corrected_gold.json` + `gold_changelog.json` with a reason per flip.

### Tests (test-first · RED — MANDATORY) ⚠️

- [x] T013 [P] [US1] Calibration agreement (TPR/FPR/TNR vs human labels) compute, in `tests/test_calibration.py` (FR-005)
- [x] T014 [P] [US1] Gate test: any signal TNR < 0.70 → blocks bulk (non-zero exit), in `tests/test_calibration_gate.py` (FR-006, SC-002)
- [x] T015 [P] [US1] Re-audit changelog test: flip detection (draft vs judge) emits one entry per change with reason, in `tests/test_reaudit.py` (FR-004, SC-003)

### Implementation

- [x] T016 [US1] Calibration loader (`data/calibration_labels.jsonl`) + JudgeAgreement compute → `out/judge_agreement.json` in `judge/calibration.py` (depends T009, T012)
- [x] T017 [US1] TNR≥0.70 gate (block + actionable message) in `judge/calibration.py` (makes T014 GREEN)
- [x] T018 [US1] Re-audit all 1082 via batch → `out/corrected_gold.json` + `out/gold_changelog.json` + heavy-disagreement flag, in `judge/reaudit_gold.py` (depends T008, T010, T011; gated by T017)

**Checkpoint**: trustworthy, gated corrected gold exists with an auditable change log.

---

## Phase 4: User Story 2 - Honest extractor scorecard (Priority: P1)

**Goal**: Per-signal **and** per-richer-field precision/recall/F1, bias-corrected with confidence intervals, scored against corrected gold.

**Independent Test**: against a fixed corrected-gold fixture, `score_extractor` emits `scorecard.json` with bias-corrected P/R/F1 + CIs for 4 signals + 4 fields, reproducible from persisted verdicts.

### Tests (test-first · RED — MANDATORY) ⚠️

- [x] T019 [P] [US2] Rogan–Gladen bias correction + CI propagation, in `tests/test_biascorrect.py` (FR-007, SC-004, research R4)
- [x] T020 [P] [US2] Richer-field set scoring (correct/spurious/missed → per-field P/R/F1), in `tests/test_field_metrics.py` (FR-008, Clarification Q1)
- [x] T021 [P] [US2] Reproducible aggregation: same verdicts → identical scorecard, in `tests/test_reproducible.py` (FR-015, SC-007)

### Implementation

- [x] T022 [US2] Rogan–Gladen bias correction + interval (consumes JudgeAgreement TPR/FPR) in `judge/metrics.py` (makes T019 GREEN; depends T009)
- [x] T023 [US2] Richer-field set scoring in `judge/metrics.py` (makes T020 GREEN)
- [ ] T024 [US2] Score extractor over 1082 via batch → `out/verdicts_1082.json` + `out/verdicts_quarantine.json`, in `judge/score_extractor.py` (depends T010, T011, T018, T022, T023; requires gate passed)
- [x] T025 [US2] Emit `out/scorecard.json` (bias-corrected P/R/F1 + CIs, signals + fields, `raw` counts) in `judge/score_extractor.py` (FR-007)

**Checkpoint**: a defensible, error-barred extractor scorecard.

---

## Phase 5: User Story 3 - Browsable failure audit (Priority: P2)

**Goal**: Every FP/FN inspectable with post text + extractor output + verdict + reason; changed gold labels show before/after.

**Independent Test**: from persisted verdicts, regenerate `eval_browser.html`; filter signal × {FP, FN}; each card shows text + reason; changed-gold cards show draft→corrected + reason.

### Tests (test-first · RED — MANDATORY) ⚠️

- [x] T026 [P] [US3] Viewer-data shaping test: FP/FN filter rows + changed-gold before/after rows built from verdicts + changelog, in `tests/test_viewer_data.py` (FR-011)

### Implementation

- [~] T027 [US3] OBSOLETE — `aggregate_judge.py` not on this branch (parallel git); superseded by standalone `judge/viewer.py` (T028)
- [x] T028 [US3] Extend `make_eval_html.py`: signal×{FP,FN} filters + changed-gold before/after panel → `eval_browser.html` (FR-010, FR-011, SC-005)

**Checkpoint**: the audit loop is intact and shows the new verdicts + gold corrections.

---

## Phase 6: User Story 4 - Hardened disputed verdicts (Priority: P3)

**Goal**: Judge-vs-extractor disagreements re-judged 3× with minority veto — confirm only on unanimity, else flag for human review.

**Independent Test**: feed a set of disagreements → unanimous panels confirm, split panels set `needs_human_review`.

### Tests (test-first · RED — MANDATORY) ⚠️

- [x] T029 [P] [US4] Minority-veto test: 3 concur → confirmed; any split → `needs_human_review`, in `tests/test_ensemble.py` (FR-012, research R5)

### Implementation

- [x] T030 [US4] Ensemble 3× re-judge on disagreements + minority veto → `DisputeRecord` list, in `judge/ensemble.py` (depends T010, T024; makes T029 GREEN)

**Checkpoint**: consequential disputed verdicts are hardened.

---

## Phase 7: Polish & Cross-Cutting

- [x] T031 [P] Document the judge pipeline run steps in `spikes/extractor-eval/README.md` (mirror quickstart.md)
- [ ] T032 Run `quickstart.md` end-to-end on the real corpus (gate → re-audit → score → viewer); confirm SC-001…SC-007
- [x] T033 [P] Full `pytest` suite green (Constitution II/X) before reporting done

---

## Dependencies & Execution Order

### Phase dependencies

- **Setup (P1)** → no deps.
- **Foundational (P2)** → after Setup; **BLOCKS all stories**.
- **US1 (P3)** → after Foundational. Produces corrected gold + the calibration gate.
- **US2 (P4)** → after Foundational; **depends on US1** (needs corrected gold T018 + JudgeAgreement for bias correction T022). Not independent of US1.
- **US3 (P5)** → after US2 (needs `verdicts_1082.json`); can use US1's changelog.
- **US4 (P6)** → after US2 (needs scored verdicts T024).
- **Polish (P7)** → after all desired stories.

> Note: unlike the generic template, the stories here form a pipeline (US1→US2→US3/US4), not fully-independent slices — corrected gold is the spine. Each is still independently *testable* via fixtures.

### Within each story

- Tests written, RUN, confirmed FAILING (RED) before implementation (GREEN); refactor after (Principle X).
- Schema/loaders/metrics (Foundational) before story logic.

### Parallel opportunities

- Setup: T003 [P].
- Foundational tests T004/T005/T006 [P] together; impl T007/T008/T010 [P] together (distinct files); T009/T011/T012 follow.
- US1 tests T013/T014/T015 [P]; US2 tests T019/T020/T021 [P].

---

## Parallel Example: Foundational

```bash
# Tests first (RED), in parallel:
pytest tests/test_schema.py tests/test_metrics.py tests/test_io.py   # all must FAIL

# Then implement distinct files in parallel:
#   judge/schema.py (T007), judge/prompt.py (T008), judge/anthropic_judge.py (T010)
```

---

## Implementation Strategy

### MVP (foundation + first real value)

1. Phase 1 Setup → Phase 2 Foundational.
2. Phase 3 **US1** — gated, trustworthy corrected gold (the spine). **STOP & VALIDATE** against the calibration set.
3. Phase 4 **US2** — the honest scorecard. This is the first deliverable a stakeholder reads. Together US1+US2 = the MVP that answers "how good is the extractor, honestly."

### Incremental delivery

US1 (trust the gold) → US2 (score it) → US3 (browse failures) → US4 (harden disputes). Each adds value without breaking the prior.

---

## Notes

- [P] = different file, no incomplete dependency.
- Verify tests FAIL (RED) before implementing; never write implementation ahead of its test (Principle X).
- The bulk steps (T018, T024) judge via Claude Code in checkpointed batches (no Anthropic API key) and require the calibration gate (T017) to have passed. They may span a session reset and resume from the last checkpoint.
- This is offline dev tooling on the **public** corpus — no on-device user data, no telemetry (Constitution VI).
- Implementation MUST land on a `feat/…` branch with `/code-review` before merge (Constitution V) — flagged because git is being managed in a parallel session.
