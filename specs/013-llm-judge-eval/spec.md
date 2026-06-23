# Feature Specification: LLM-Judge Evaluation Pipeline

**Feature Branch**: `013-llm-judge-eval`

**Created**: 2026-06-23

**Status**: Draft

**Input**: User description: "Automated LLM-as-judge evaluation pipeline for the NLP signal extractor, at full 1082-post corpus scale — re-audit the draft gold labels, validate the judge against a human calibration set, then score the extractor (presence + richer fields) against corrected gold, with results browsable in the existing audit viewer."

## Clarifications

### Session 2026-06-23

- Q: How is a richer free-form field (feelings/activities/sleep/side-effects) judged correct? → A: Per-item set comparison — each field is scored as a set, with precision/recall/F1 per field (each extracted item labeled correct or spurious, each gold item present-but-missed).
- Q: What is the bulk-run gate threshold on the judge's absent-signal agreement? → A: True-negative rate ≥ 0.70 on the calibration set; below this the bulk run is blocked pending prompt revision.
- Q: What do the scorecard's "calibration-derived error bars" represent? → A: Bias-corrected estimates — each P/R/F1 is adjusted using the judge's measured TPR/FPR (prediction-powered / Rogan–Gladen style) to remove agreeableness inflation, then reported with a confidence interval.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Trustworthy corrected gold (Priority: P1)

As the developer measuring extractor quality, I need a *trustworthy* ground-truth label set, because the draft `signals` labels on the 1082-post corpus are weak and the extractor's measured accuracy is only as honest as the labels it is scored against. The judge re-audits every draft label, but a judge that rubber-stamps cannot be trusted blindly — so its agreement with human judgment is first measured on a calibration set, and the bulk re-audit is only trusted if the judge clears a minimum ability to catch *absent* signals.

**Why this priority**: Everything downstream (extractor scoring, the audit viewer, any claim about precision/recall) is meaningless if the gold is wrong or the judge is uncalibrated. This is the foundation.

**Independent Test**: Hand-label the calibration subset, run the judge over it, and confirm the system reports per-signal judge-vs-human agreement and blocks the bulk run when agreement is below threshold. Delivers value on its own: a measured, gated judge plus a corrected gold set with an auditable change log.

**Acceptance Scenarios**:

1. **Given** a calibration set of ~100–150 human-labeled posts, **When** the judge runs over it, **Then** the system reports per-signal judge-vs-human true-positive and true-negative agreement, and surfaces every disagreement for review.
2. **Given** the judge's true-negative agreement on the calibration set is below the configured floor, **When** a bulk run is requested, **Then** the run is blocked with a clear message to revise the judge prompt first.
3. **Given** the judge clears the calibration gate, **When** it re-audits all 1082 draft labels, **Then** the system emits a corrected-gold set plus an explicit list of every label added or removed, each with a one-line reason.

---

### User Story 2 - Honest extractor scorecard (Priority: P1)

As the developer, I need per-signal precision/recall/F1 for the extractor — for both signal *presence* (mood, energy, focus, sleep) and the *richer* free-form fields (feelings, activities, sleep detail, side-effects) that the presence-only gold can't cover — reported with error bars that reflect the judge's measured imperfection, not as falsely precise point estimates.

**Why this priority**: This is the actual deliverable — a defensible answer to "how good is the extractor, and where does it fail." Without honest error bars it would overstate quality (the judge's agreeableness bias inflates apparent accuracy).

**Independent Test**: Run scoring against a fixed corrected-gold fixture and confirm the per-signal precision/recall/F1 numbers, the error bars, and the richer-field judgments are produced and reproducible from persisted verdicts.

**Acceptance Scenarios**:

1. **Given** a corrected-gold set and the extractor's outputs, **When** scoring runs, **Then** the system reports per-signal precision, recall, and F1 for all four presence signals, each annotated with a calibration-derived error bar.
2. **Given** the extractor emitted richer fields (feelings/activities/sleep/side-effects), **When** scoring runs, **Then** each richer-field claim receives a semantic correctness verdict, since presence-only gold cannot judge it.
3. **Given** a completed run, **When** the same persisted verdicts are re-aggregated, **Then** the scorecard is identical (aggregation is deterministic).

---

### User Story 3 - Browsable failure audit (Priority: P2)

As the developer, I need every false-positive and miss inspectable with its original post text, the extractor's output, the judge's verdict, and the judge's reason — so I can see *why* the extractor failed and feed fixes back into it.

**Why this priority**: A scorecard tells you *how much* is wrong; the audit viewer tells you *what* and *why*, which is what drives the next extractor improvement. High value, but depends on verdicts existing (US1/US2).

**Independent Test**: From a set of verdicts, regenerate the audit viewer and confirm it filters to false-positives and misses per signal and shows post text + reason for each.

**Acceptance Scenarios**:

1. **Given** a completed verdict set, **When** the audit viewer is regenerated, **Then** it lets the developer filter by signal and verdict type (false-positive, missed) and shows each post's text, extractor output, verdict, and reason.
2. **Given** a gold label the re-audit changed, **When** the developer inspects it, **Then** the viewer shows the original draft label, the corrected label, and the reason for the change.

---

### User Story 4 - Hardened disputed verdicts (Priority: P3)

As the developer, for the records where the judge disagrees with the extractor — the consequential cases — I want a higher-confidence re-judgment that refuses to confirm a verdict unless an independent panel agrees, so a single over-agreeable pass cannot quietly let an extractor error through.

**Why this priority**: A refinement that raises confidence on the cases that matter most, at modest extra cost. Valuable but not required for a first honest scorecard.

**Independent Test**: Take a set of judge-vs-extractor disagreements, run the ensemble re-judgment, and confirm a verdict is only confirmed when the panel concurs; otherwise it is flagged for review.

**Acceptance Scenarios**:

1. **Given** a record where the judge and extractor disagree, **When** the ensemble re-judgment runs, **Then** the disputed verdict is confirmed only if the panel agrees; a split panel flags the record for human review rather than silently accepting either side.

---

### Edge Cases

- **Trap-text-plus-valid-signal**: a post may contain excluded trap text (advice to others, quoted affect) *and* a genuine first-person signal. Exclusions are span-level disqualifiers, not post-level rejections — the post must still receive a correct per-signal verdict.
- **Truncated posts** (`flagged_truncated = true`): the judge must still return a verdict; truncation status is recorded so a reviewer can discount affected records.
- **Neutral / no-signal posts**: must produce correct-absent verdicts, not be silently skipped — these are exactly where over-flagging shows up.
- **Malformed judge output**: a judgment that does not conform to the required structured shape must be detected and retried or quarantined, never silently dropped or miscounted.
- **Bulk-run result reordering**: when results arrive out of order, every verdict must be matched back to its post by id, never by position.
- **Heavy draft-gold disagreement**: when the re-audit changes a large fraction of labels, this must be surfaced prominently (it implies either bad draft gold or a misbehaving judge) rather than accepted quietly.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST produce, for every post in the 1082-record corpus, a per-signal verdict for each of the four presence signals (mood, energy, focus, sleep), classifying it as correct-present, false-positive, missed, or correct-absent.
- **FR-002**: The system MUST count a signal as present only when it is attributable to the author's own, first-person, present-tense experience, applying these span-level exclusion criteria: (1) advice or second-person directives; (2) quoted or reported affect; (3) past-tense or resolved states; (4) hypothetical or conditional statements; (5) venting about externals (pharmacy/insurance/shortage/generics); (6) general claims about ADHD/medication in the abstract; (7) text quoting another commenter.
- **FR-003**: The judge MUST emit a one-line justification *before* each verdict (reasoning precedes label).
- **FR-004**: The system MUST re-audit the draft `signals` label of all 1082 records and emit (a) a corrected-gold set and (b) an explicit change log listing every label added or removed with a reason.
- **FR-005**: The system MUST validate the judge against a human-labeled calibration set of ~100–150 stratified posts (pure-signal / noise / ambiguous) and report per-signal judge-vs-human agreement, including the judge's ability to correctly identify *absent* signals.
- **FR-006**: The system MUST gate the bulk run on the calibration result: if the judge's true-negative rate on absent signals falls below **0.70**, the bulk run MUST be blocked with guidance to revise the judge prompt.
- **FR-007**: The system MUST score the extractor against corrected gold and report per-signal precision, recall, and F1 as **bias-corrected estimates** — each adjusted using the judge's calibration-measured true-positive and false-positive rates to remove agreeableness inflation — annotated with a confidence interval.
- **FR-008**: The system MUST additionally judge the extractor's richer free-form fields (feelings, activities, sleep detail, side-effects) separately from the four presence signals, scoring each field as a **set**: every extracted item is labeled correct or spurious and every gold item present-but-missed, yielding per-field precision, recall, and F1.
- **FR-009**: The judge MUST frame its task adversarially — assuming the extractor over-extracts and confirming a signal only when it is clearly first-person and present.
- **FR-010**: Verdicts MUST be persisted in a structured form keyed by post id and signal, sufficient to drive both the scorecard and the browsable audit viewer without re-querying the judge.
- **FR-011**: The system MUST regenerate the browsable audit viewer from persisted verdicts so every false-positive and miss is inspectable with its post text, extractor output, verdict, and reason, and so every changed gold label shows its before/after and reason.
- **FR-012**: For records where the judge and the extractor disagree, the system MUST support an ensemble re-judgment that confirms a verdict only on panel agreement and flags split decisions for human review.
- **FR-013**: The pipeline MUST be an offline developer tool operating only on the public corpus; it MUST NOT be part of the shipped app and MUST NOT process on-device user data.
- **FR-014**: The system MUST match bulk-run results to posts by id (never by position), and MUST detect and handle malformed or missing judgments rather than miscounting them.
- **FR-015**: Aggregation of a scorecard from persisted verdicts MUST be deterministic and reproducible.

### Key Entities *(include if feature involves data)*

- **Corpus post**: one Reddit post — id, original text, draft gold signals, truncation flag, summary.
- **Extractor output**: the extractor's result for a post — detected presence signals plus richer fields (feelings, activities, sleep detail, side-effects).
- **Judge verdict**: a single per-signal judgment — post id, signal, label (correct-present / false-positive / missed / correct-absent), one-line reason.
- **Corrected gold**: per-post corrected presence-signal set, plus a change log of every draft label added or removed with reason.
- **Calibration set**: a human-labeled stratified subset and the resulting per-signal judge-vs-human agreement metrics (including absent-signal agreement).
- **Scorecard**: per-signal precision/recall/F1 with calibration-derived error bars, plus the richer-field correctness summary.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of the 1082 posts receive a per-signal verdict for all four presence signals — no post is silently skipped.
- **SC-002**: The judge's per-signal agreement with human labels on the calibration set is measured and reported, and the bulk run is demonstrably blocked whenever the judge's true-negative rate on absent signals is below 0.70.
- **SC-003**: Every gold label the re-audit changes is listed with a reason, so a reviewer can audit all corrections without re-reading the whole corpus.
- **SC-004**: The extractor scorecard reports per-signal precision, recall, and F1 as bias-corrected estimates with confidence intervals, never bare uncorrected point estimates.
- **SC-005**: 100% of false-positive and missed verdicts are inspectable in the audit viewer with their post text and judge reason.
- **SC-006**: A full bulk run over the 1082 posts completes within one developer sitting (target: under ~1 hour) at negligible cost.
- **SC-007**: Re-aggregating a scorecard from the same persisted verdicts yields identical numbers.

## Assumptions

- **Locked technical decisions** (carried into `/speckit-plan`, not re-opened here): the judge model is Claude Opus 4.8 via the Anthropic API; the harness is built on the DeepEval framework with Claude wrapped as a custom judge model and async/batch execution; the bulk run may use the Anthropic Message Batches API for cost; verdicts use confusion-matrix labels (not 1–5 scores) with structured/schema-guaranteed output. These are constraints, not open questions.
- **Calibration floor**: the bulk-run gate requires true-negative rate ≥ 0.70 on the calibration set (chosen over a laxer 0.60 to keep rubber-stamped misses out, accepting more prompt iteration before the run unlocks).
- **Human calibration labels** are produced by the developer, seeded from the existing audit viewer's false-positive/miss cards plus a stratified sample; ~100–150 posts is sufficient for usable error bars at this corpus size.
- **Corpus is public data**: the 1082 posts are already-scraped public Reddit content used as a fixed evaluation corpus; sending them to an external judge is acceptable because they are not on-device user data.
- **Extractor is fixed**: this feature evaluates the existing Swift extractor's dumped outputs; changing the extractor itself is out of scope.
- **Existing harness is reused**: verdict aggregation and the browsable viewer extend the current `aggregate_judge.py` / `make_eval_html.py` / `eval_browser.html` tooling rather than replacing it.
- **Determinism caveat**: individual LLM judgments are not bit-reproducible; reproducibility (SC-007, FR-015) applies to *aggregation from persisted verdicts*, and verdicts are cached so a scorecard need not re-query the judge.

### Constitution Alignment

- **Principle VII (Deterministic, Measured Extraction)**: this feature strengthens the eval harness that Principle VII depends on — it sharpens the precision/recall floors the extraction pipeline must not regress. It does not touch `NLNoteExtractor` or the lexicon.
- **Principle VI (On-Device Privacy)**: respected — the judge runs offline on the public corpus only and is never part of the shipped app; no on-device user data is sent anywhere.
- **Principle X (Test-First)**: the Python harness logic (verdict parsing, metric computation, gating) is testable and MUST be built test-first (extends the existing `test_evalmetrics.py`). This is enforced at `/speckit-tasks`.

## Out of Scope

- Modifying the Swift `NLNoteExtractor`, the lexicon, or any app code — this is evaluation infrastructure only.
- Shipping the judge or any LLM call inside the app.
- Expanding the corpus beyond the existing 1082 records.
