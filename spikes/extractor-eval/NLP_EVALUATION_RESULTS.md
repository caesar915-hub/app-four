# NLP Extractor — Evaluation Results (improved rule-based extractor)

**Date:** 2026-06-23 · **Branch:** `spike-nlp-performance` · **Extractor:** `NLNoteExtractor` (Apple NaturalLanguage, rule + lexicon, no ML)

This documents the overnight improvement pass (specs 010/011/012) and a large-scale
LLM-judge evaluation of the **improved** extractor over 468 real ADHD forum posts.

---

## 1. What changed tonight (shipped + measured)

| # | Change | Spec | Measured effect (harness) |
|---|---|---|---|
| 1 | Temporal weighting applied to energy & focus (present-tense-wins, like mood) | 011 | no regression; helps multi-clause "was X but now Y" |
| 2 | Negated ordinals map to adjacent/middle tier, not polar ("not great"→okay) | 011 | no regression |
| 24 | Sleep worded-numbers ("three hours", "nine hours") | 011 | **sleepHours R 0.29 → 0.57** |
| — | Lexicon: "couldn't/cannot focus" → distracted (direct match) | 012 | keeps focus at floor after the flip change |
| 7 | Energy lexicon coverage (exhausted, no energy, full of energy, energetic, worn out…) | 012 | **40-case energy P 0.67→0.80, R 0.25→0.50**; detection recall **0.35→0.39** |

**Quantitative baseline → improved**

| metric | baseline | improved |
|---|---|---|
| 40-case energy P / R | 0.67 / 0.25 | **0.80 / 0.50** |
| 40-case sleepHours R | 0.29 | **0.57** |
| addrec-1037 energy detection recall | 0.35 | **0.39** |
| addrec-1037 focus detection recall | 0.79 | 0.80 |
| addrec-1037 micro recall | 0.64 | 0.65 |
| meds (unchanged) | 1.00 / 1.00 | 1.00 / 1.00 |

Ordinal (40-case, improved): mood QWK 0.97, energy QWK 1.00, focus QWK 0.40 — i.e. **when the
extractor fires, the *level* is usually right; the failure mode is detection/coverage, not severity.**

---

## 2. LLM-judge evaluation (468 posts, 20 agents, per-record)

Each of 468 deduped ADHD forum posts was read by an LLM judge that rated the extractor's
mood / energy / focus / meds against its own reading: `correct` (matches the text),
`partial` (right direction, wrong level/incomplete), `missed` (text conveys it, extractor
returned null), `false_positive` (extractor asserted something the text doesn't support),
`na` (text genuinely doesn't express it).

| signal | correct | partial | missed | false_pos | n/a | strict acc | soft (+partial) |
|---|---|---|---|---|---|---|---|
| mood | 101 | 72 | 55 | **123** | 116 | 0.29 | 0.49 |
| energy | 30 | 21 | 45 | 50 | 321 | 0.21 | 0.35 |
| focus | 76 | 28 | 19 | **113** | 231 | 0.32 | 0.44 |
| meds | 84 | 5 | 9 | 5 | 364 | **0.82** | 0.86 |

Overall per-post rating: **good 110, ok 196, poor 161** (good+ok = 66%).

---

## 3. The dominant finding: false positives, not misses

On this register the biggest error is **the extractor asserting a mood/focus the author never expressed.**
mood false-positives (123) outnumber misses (55); focus FPs (113) outnumber misses (19). The judge
notes cluster into four causes:

1. **Affect belongs to someone else** — "energy=tired" attributed to *the kids* ("they were all tired"); advice posts where the guilt/worry is the *addressee's*, not the author's.
2. **Quoted / hypothetical affect** — "focus=present" lifted from quoting the addressee's worry; a study *tip* about forcing focus read as a sharp-focus *state*.
3. **Venting about externals scored as mood** — "Retail fucking blows" → mood=great; "teacher-bashing rant" → mood=okay.
4. **Context inversion** — "brain fog that Sandoz *cleared*" → focus=foggy (a resolved past state read as current); posts about focus *deficits* → focus=sharp.

Examples of `poor` verdicts:
- "Inverted: an overwhelmed, can't-focus, procrastinating post scored mood=great / focus=present / energy=steady."
- "'I am broken' + guilt is an unmistakable low mood, returned null."
- "Pure coffee+Adderall advice; mood=okay and focus=present both fabricated."

**Meds remain the bright spot (0.82 strict, 0.86 soft)** — the layered exact+fuzzy+context-gated
pipeline generalizes to this register far better than the single-layer mood/energy/focus matching.
(One recurring defect: occasional duplicate med names, e.g. "Adderall ×2".)

---

## 4. Critical caveat — register mismatch (read before acting on these numbers)

**These 468 posts are Reddit forum text: advice to others, quoting, third-person, venting about
external events.** The app's actual input is **first-person daily voice check-ins** ("Took my
Concerta at 8am, crashed at 3pm, couldn't focus all afternoon"). The extractor is tuned for the
latter. So section 2 is a **worst-case stress test, not the expected in-app accuracy.**

The contrast is stark and informative:
- On-register (40 hand-built check-in cases): meds 1.0, feelings P 0.94, mood P 0.75, energy P 0.80.
- Off-register (these 468 Reddit posts): mood strict 0.29, focus 0.32 — dragged down almost entirely by **false positives from non-author / quoted / venting affect.**

The gap *is* the finding: the extractor has no notion of **whose** state it's reading or whether
the affect is **quoted/hypothetical/resolved**. On clean first-person check-ins that rarely bites;
on discursive text it dominates.

---

## 5. What this says to do next (evidence-ranked)

1. **Experiencer + quote/hypothetical gating is now the #1 lever** (not coverage). The deferred 011
   items — clause-scoped negation (#3), token-anchored matching (#23), and an **experiencer filter**
   ("my mum/the kids/you" → not the author) plus a **hypothetical/quote gate** — directly target the
   123+113 false positives. This was theorized from the architecture review; the judge now *measures*
   it as the dominant error on real text.
2. **Coverage (lexicon) helps recall but is the smaller lever on real text** — tonight's energy
   additions moved detection recall +0.04; precision is where the points are.
3. **Fix the duplicate-meds defect** (cheap, visible).
4. **Keep the meds pipeline as the template** — its layered defense is why it survives register shift.

---

## 6. Honest limitations of this evaluation

- The judge is itself an LLM, not ground truth; treat verdicts as a strong second opinion, not gospel.
- The addrec gold `signals` are coarse presence labels, likely auto-generated; used only as a hint here.
- One register (Reddit), one corpus (468). On-register evaluation still rests on 40 hand-built cases —
  growing a value-labeled check-in set remains the real measurement gap (deferred by team decision).
- Tonight's changes were verified on the standalone macOS harness; the in-app Xcode test suite was not
  run headless (deferred to morning per the agreed plan).

---

### Artifacts
- Per-record verdicts: `out/judge_verdicts.json` (467) · stats: `out/judge_stats.md`
- Full extractions over the 500: `out/extractions_500.json` (468 deduped)
- Harnesses: `run.sh` (40-case value), `run_detect.sh` (1037 detection), `aggregate_judge.py`
- Resume/handoff: `STATUS.md`
