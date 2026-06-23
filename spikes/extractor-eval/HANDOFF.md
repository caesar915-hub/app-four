# HANDOFF — Extractor evaluation & TestFlight decision

**Last updated:** 2026-06-23 · **Pick up here in a new session.**

---

## TL;DR (read this first)

We built an LLM-as-judge eval (spec 013) to score the Swift NLP signal extractor
(`app-four/Services/NoteExtraction/`). After judging 100 posts adversarially, the
conclusion is **not** "the extractor is bad" — it's:

> **The benchmark is unreliable and measured on the wrong distribution. The
> extractor's real-world performance is still UNKNOWN. Do not let the Reddit
> number gate the TestFlight decision.**

The next move is **Step 1 below**: score the extractor on ~25 real first-person
journal check-ins (the user is collecting these). That is the only number that
should drive deploy/no-deploy.

---

## What we found (evidence)

Corpus = `data/addrec_1082_summaries.jsonl` — **Reddit *comments*** about ADHD meds
(advice, 2nd-person, quoting others, abstract claims). The app's real input is a
**first-person voice journal**. Different distribution.

**1. The draft gold over-labels by ~half** (re-audit, judge vs draft, over 100 posts):

| signal | draft says present | judge confirms | draft over-labels |
|---|---|---|---|
| mood | 70 | 31 | 41 (59%) |
| energy | 27 | 9 | 20 (74%) |
| focus | 50 | 27 | 28 (56%) |

99/100 posts needed a correction (`out/gold_changelog.json`).

**2. Extractor vs judge-corrected gold** (the honest scorecard, n=100):

| signal | TP | FP | FN | TN | P |
|---|---|---|---|---|---|
| mood | 24 | 33 | 7 | 36 | 0.42 |
| energy | 3 | 8 | 6 | 83 | 0.27 |
| focus | 20 | 30 | 7 | 43 | 0.40 |
| sleep | 0 | 1 | 1 | 98 | 0.00 |

Fields (item-set): activities P=0.35 / R=1.00 (57 spurious, 0 missed); feelings
P~0.50; sideEffect noisy.

**Interpretation:** extractor AND draft gold over-fire the same way on the same hard
cases → the original ad-hoc eval was likely comparing **two over-extractors**. Root
cause of over-extraction: surface keyword matching with **no attribution / tense /
modality gating** (see `Lexicon.swift`, `CueMatcher.swift`). The trap categories that
drive the FPs (advice, 2nd-person, quotes) barely exist in a personal journal.

**Methodology note — do NOT "evaluate only the 53."** Precision needs the
gold-absent slots (that's where FPs live). Scoring only confirmed-positive posts
inflates precision and measures recall only. Keep the full set.

---

## Constraints (locked)

- **On-device only** (Constitution VI, privacy). No cloud judge in production.
- **Must run on iPhone 12 = A14 / 4 GB RAM.**
  - ❌ **Apple Foundation Models / Apple Intelligence is OUT** — requires A17 Pro / M-series.
  - ❌ CoreML classifier path already concluded **non-viable** (memory: ml-spike-session-state).
  - ✅ Realistic ceiling right now = **rules + pre-filter** (Step 3). Defer any model swap
    until real data proves rules insufficient AND a model is shown to fit A14.

---

## NEXT STEPS

### Step 1 — Real-distribution eval (CRITICAL PATH, do first)

**Goal:** measure the extractor on the actual app modality, not Reddit comments.

1. **Input:** ~25 first-person journal check-ins the user is collecting. Store as
   `data/journal_checkins.jsonl`, one object per line:
   ```json
   {"id": "j01", "text": "Took my Vyvanse at 8, focused all morning, crashed by 3, couldn't sleep till 1.",
    "human_signals": ["focus","energy","sleep"], "human_feelings": [], "human_activities": ["Work"]}
   ```
   `human_*` = hand-labeled gold (only first-person PRESENT signals). This is the clean
   gold the Reddit set never had.
2. **Run the REAL Swift extractor** on each `text` — do NOT re-implement in Python.
   Adapt the existing harness `EvalHarness.swift` / `EvalSetCopy.swift` (already in this
   dir) to read `journal_checkins.jsonl` and dump `out/journal_extractions.json` with the
   same shape as `out/extractions_500.json` (mood/energy/focus/sleepHours/feelings/
   activities/sideEffect). Use `ios-debugger-agent` (XcodeBuildMCP) per CLAUDE.md.
3. **Score** extractor output vs `human_signals` (presence) + fields (item-set). Reuse
   `judge/metrics.py` (`derive_label`, `prf`, `field_prf`). Write a tiny
   `score_journal.py` mirroring `judge/score.py` but using `human_*` as gold directly
   (no LLM judge needed — the human labels ARE the gold here).
4. **Decision rule:** if real-distribution precision is acceptable (hypothesis: it jumps
   a lot because the traps vanish) → ship (Step 2). If still poor on clean first-person
   input → the lexicon has genuine semantic gaps; do Step 3, re-measure.

### Step 2 — Ship to TestFlight with a correction affordance

- TestFlight **is** the data-collection mechanism — it harvests the real input
  distribution we're missing.
- Make every extracted tag **dismissible / editable** in the UI. Two wins: protects UX
  from residual errors, and each correction = a labeled real-distribution example.
- Tag the TestFlight commit (`git tag vX.Y.Z`) per CLAUDE.md Git Workflow.

### Step 3 — Cheap precision hardening: exclusion pre-filter (primary lever)

Port the judge's 7 exclusion criteria into a **sentence-level pre-filter that runs
BEFORE lexicon matching** in `NLNoteExtractor`. Drop / skip sentences that are:
1. 2nd-person / advice (`you should/could/try`, imperative)
2. quoted or reported speech
3. past-tense / resolved (`used to`, `haven't … in years`)
4. hypothetical / conditional (`if I…`)
5. venting about externals (pharmacy/insurance/shortage)
6. general claims about ADHD/meds in the abstract
7. quoting another commenter then replying

Pure rules, **runs on A14**, attacks the contextual-FP channel that `lemmaEnabled:false`
cannot. Add unit tests (Constitution X test-first). Re-run Step 1 to quantify the lift.

**Out of scope for now:** model swap (see Constraints). Don't grind the Reddit eval to
465 — it's out-of-distribution and won't change the decision.

---

## Current state / file map

- **Eval harness (spec 013):** `judge/` package — schema, metrics, io, prompt, batch,
  calibration, reaudit, ensemble, score, viewer. 33 tests green (`./.venv/bin/python -m pytest -q`).
- **Verdict store:** `out/verdicts_1082.json` — **100 verdicts** checkpointed (resumable;
  judged adversarially in-session by Claude Code, no API key). Eligible pool = 465 posts
  with both corpus text + extractor output.
- **Detail artifacts (regenerate via `./.venv/bin/python run_outputs.py`):**
  - `out/eval_browser.html` — browsable: 400 verdict rows, 93 FP/FN, filter by signal×verdict
  - `out/scorecard.json`, `out/gold_changelog.json`, `out/corrected_gold.json`, `out/judge_agreement.json`
- **Extractor source:** `app-four/Services/NoteExtraction/{Lexicon,CueMatcher,NLNoteExtractor}.swift`
- **Existing Swift eval harness to adapt for Step 1:** `EvalHarness.swift`, `EvalSetCopy.swift`
- **Spec/plan/tasks:** `specs/013-llm-judge-eval/` (T024 bulk-judge + T032 full-run still open;
  result is robust at n=100, further judging optional).

### Resume commands
```bash
cd spikes/extractor-eval
.venv/bin/python -m pytest -q          # logic tests
.venv/bin/python -m judge.score        # current scorecard from 100 verdicts
.venv/bin/python run_outputs.py        # regenerate all detail artifacts + viewer
```

### Judging more Reddit posts (optional, low priority)
Build a worksheet of pending ids (text + extractor output), judge adversarially
(first-person PRESENT only; 7 exclusions), ingest via `judge.batch.ingest`. NOTE:
every `reason` field must be **non-empty** or the schema rejects the verdict.
