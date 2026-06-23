# Phase 1 Data Model: LLM-Judge Evaluation Pipeline

Entities are grounded in the real files: corpus `data/addrec_1082_summaries.jsonl`, extractor dump `out/extractions_500.json`, prior verdicts `out/judge_verdicts.json`.

## Entity: CorpusPost (input, existing)

Source: `addrec_1082_summaries.jsonl` (1082 records).

| Field | Type | Notes |
|-------|------|-------|
| `id` | string (uuid) | join key across all artifacts |
| `clean_text` | string | the post body the judge reads |
| `signals` | list[string] | **draft** gold presence signals ⊆ {mood, energy, focus, sleep} |
| `flagged_truncated` | bool | recorded on verdicts so a reviewer can discount |
| `summary` | string | not used by the judge |

## Entity: ExtractorOutput (input, existing)

Source: `out/extractions_500.json` (extractor dump, keyed by `id`).

| Field | Type | Notes |
|-------|------|-------|
| `id` | string | join key |
| `mood` / `energy` / `focus` / `sleep` | string \| null | the detected **value**; presence = non-empty/non-null |
| `feelings` | list[string] | richer field — scored as a set |
| `activities` | list[string] | richer field — scored as a set |
| `sideEffect` | bool \| string | richer field |
| `meds` | list[string] | medication detection (carried through, not the focus) |
| `goldSignals` | list[string] | the draft gold echoed into the dump |

> Presence reconciliation: an extractor "detects" signal *S* when its `S` value is non-empty. Gold "has" *S* when *S* ∈ corrected gold. The four-way label is the cross of those two booleans.

## Entity: SignalVerdict (new)

One per (post, signal). Produced by the judge.

| Field | Type | Rule |
|-------|------|------|
| `id` | string | post id |
| `signal` | enum | mood \| energy \| focus \| sleep |
| `reason` | string | one line, emitted **before** `label` (FR-003) |
| `label` | enum | TP \| FP \| FN \| TN |
| `partial` | bool | secondary quality flag on a TP (R9); does not move the matrix cell |

Validation: `label` required; `reason` non-empty; a signal counts present only under first-person-present attribution with the 7 exclusions applied (FR-002).

## Entity: RicherFieldVerdict (new)

One per (post, field), scored as a **set** (FR-008, Clarification Q1).

| Field | Type | Rule |
|-------|------|------|
| `id` | string | post id |
| `field` | enum | feelings \| activities \| sleep \| sideEffect |
| `correct_items` | list[string] | extracted items the judge confirms (→ TP) |
| `spurious_items` | list[string] | extracted items the judge rejects (→ FP) |
| `missed_items` | list[string] | gold items the extractor omitted (→ FN) |
| `reason` | string | one line |

Per-field precision = |correct| / (|correct|+|spurious|); recall = |correct| / (|correct|+|missed|).

## Entity: CorrectedGold + GoldChange (new)

Outputs of the re-audit (FR-004).

CorrectedGold: `{id, signals: list[enum]}` — the judge-confirmed present signals.

GoldChange (change log entry): `{id, signal, from: present|absent, to: present|absent, reason}` — one per label the re-audit flipped. Surfaced in the viewer (FR-011) and counted (Edge: heavy disagreement).

## Entity: CalibrationRecord (new)

Source: `data/calibration_labels.jsonl` (~120 human-labeled posts).

| Field | Type | Notes |
|-------|------|-------|
| `id` | string | post id |
| `stratum` | enum | pure \| noise \| ambiguous |
| `human_signals` | list[enum] | ground-truth presence per signal |
| `human_fields` | object | ground-truth richer-field item sets |

## Entity: JudgeAgreement (new)

Per-signal judge-vs-human metrics from the calibration run (FR-005).

`{signal, tpr, fpr, tnr, n}` — `tnr` is the **gated** metric: bulk run blocks if any signal's `tnr` < 0.70 (FR-006).

## Entity: Scorecard (new, output)

Per-signal and per-field, bias-corrected (FR-007, SC-004).

| Field | Type | Notes |
|-------|------|-------|
| `signal_or_field` | string | one of the 4 signals or 4 richer fields |
| `precision` / `recall` / `f1` | object `{point, ci_low, ci_high}` | **Rogan–Gladen** bias-corrected point + interval |
| `raw` | object | uncorrected counts, for audit |

## Entity: DisputeRecord (new)

For judge-vs-extractor disagreements run through the ensemble (FR-012).

`{id, signal, panel: [label, label, label], confirmed: bool, needs_human_review: bool}` — `confirmed` only when the 3-vote panel is unanimous; otherwise `needs_human_review = true` (R5).

## Relationships

```
CorpusPost 1──1 ExtractorOutput            (by id)
CorpusPost 1──4 SignalVerdict              (one per signal)
CorpusPost 1──4 RicherFieldVerdict         (one per richer field)
CorpusPost 1──1 CorrectedGold  0..4 GoldChange
CalibrationRecord ──▶ JudgeAgreement ──gate──▶ (bulk run)
SignalVerdict + CorrectedGold ──▶ Scorecard (bias-corrected via JudgeAgreement)
SignalVerdict(disagreement) ──▶ DisputeRecord
all verdicts ──▶ aggregate_judge.py ──▶ eval_browser.html
```
