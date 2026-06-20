# The Big Picture — FLAN-T5 Summarizer Spike, explained simply

*A plain-language tour of what this spike does, what we found, and the one finding that matters most. For the rigorous version with full numbers, see [EVALUATION.md](EVALUATION.md) and [METHODOLOGY.md](METHODOLOGY.md).*

---

## 1. What we're building

Someone records a voice note about their ADHD day. We want a **tiny AI model** (small enough to run on a phone, offline) to shrink it into a short summary — **without messing up the facts that matter**.

```
 🎙️  voice note: "took my Concerta at 8, focus held till 1pm,
                  crashed early around 2:30, mood went flat..."
        │  (1) transcribe to text
        ▼
 📄  transcript  (long, rambling)
        │  (2) small on-device model   →   flan-t5   OR   t5gemma
        ▼
 📝  short summary
        │
        ▼  it has to survive into a HEALTH RECORD, so it must keep:
            meds • doses • times • sleep • mood • side-effects
```

Because it's a health record, the stakes are high: a wrong medical detail can mislead a doctor.

---

## 2. The two ways a summary goes wrong

```
  original fact:  "Concerta at 8, crash at 2:30 (afternoon)"

  ┌─ OMISSION ───────────────┐      ┌─ FABRICATION ────────────────┐
  │ leaves a fact OUT         │      │ INVENTS or CORRUPTS a fact   │
  │                           │      │                              │
  │ "Took Concerta."          │      │ "Crash at 2:30 AM"           │
  │ (lost the crash + time)   │      │ (afternoon → 2:30 at NIGHT   │
  │                           │      │  = a false detail)           │
  │                           │      │                              │
  │ 🟡 recoverable —          │      │ 🔴 dangerous —               │
  │    you can re-listen      │      │    a reader trusts a lie     │
  └───────────────────────────┘      └──────────────────────────────┘
```

**Leaving something out is annoying but safe. Making something up is dangerous.** For a medical log, fabrication is the worse sin.

---

## 3. The two models = a real tradeoff

```
   flan-t5-large  ("the cautious one")     t5gemma  ("the eager one")
   ───────────────────────────────────     ──────────────────────────────
   ✅ rarely makes things up                ✅ copies lots of detail
   ❌ but drops ~1/3 of the facts           ❌ but corrupts / invents details
   = FAITHFUL but LOSSY                     = COMPLETE but UNFAITHFUL
```

The report's conclusion: **pick the cautious one (flan-large)** — for a health record you'd rather lose a detail than trust a fake one. That's a reasonable call.

---

## 4. How we grade "did it make things up?"

We use **MiniCheck** — think of it as a robot fact-checker:

```
   ORIGINAL transcript ──┐
                         ├──►  🤖 MiniCheck  ──►  score 0.0 → 1.0
   a SUMMARY sentence ───┘                        0.0 = made up
                                                  1.0 = fully backed by source
                                                  (we "flag" anything < 0.5)
```

It reads the original and each summary sentence and asks: *"is this sentence supported by the original?"* — like a teacher checking whether your essay's claims actually appear in the textbook.

---

## 5. Can we trust the report's numbers?

A **"receipt"** = a script anyone can re-run and get the *same* number. Checking every headline claim:

```
   CLAIM                                  RECEIPT?
   ────────────────────────────────────  ───────────────────────────────
   ✅ faithfulness: 0.79 vs 0.46          re-ran the scorer → identical
   ✅ "decoding tricks don't help"        re-ran → identical
   ✅ the statistical confidence ranges   re-computed → identical
   ⚠️ completeness: 68% vs 93%            NO script exists — a human estimate
   ⚠️ "dangerous fabrications: 0 vs 3"    NO script exists — a human judgment
```

So **half the report is real, reproducible measurement; the other half is eyeball judgment written up as if it were measured.** Not fake — but not checkable, which matters for a health decision.

---

## 6. ⭐ The finding that matters most: a blind spot

Gemma turns afternoon **"2:30"** into **"2:30 am"**. That looks trivial to fix — so we built a deterministic fixer, removed the fake "am", and re-graded. Here's the surprise:

```
   STEP 1   source says:  "...crash came in early, maybe 2:30..."  (afternoon)
                                    │
   STEP 2   gemma writes:  "Crash at 2:30 AM"   🔴 wrong — that's the dead of night
                                    │
   STEP 3   MiniCheck grades it:  0.92  →  "supported ✅"   😱  it shrugs!
                                    │
   STEP 4   we strip the fake "am"...  the score barely moves (0.460 → 0.459)
```

**Why didn't fixing the error improve the grade?** Because the robot reads for *meaning*, and "2:30" vs "2:30 am" mean almost the same thing to it — so it never marked the error wrong in the first place. Removing an error the grader can't see doesn't change the grade.

```
   ┌────────────────────────────────────────────────────────────┐
   │  THE BLIND SPOT                                            │
   │                                                           │
   │  the MOST dangerous error for a health record             │
   │  (wrong time / wrong dose) is exactly the kind MiniCheck   │
   │  is WORST at catching.                                    │
   │                                                           │
   │  it scored fabricated times at 0.57–0.92 — all sail past   │
   │  the 0.5 flag line, so none get caught.                   │
   └────────────────────────────────────────────────────────────┘
```

*(Measured directly: the fixer stripped 30 fake meridiems across 11 gemma rows, yet the faithfulness score moved by 0.001. The fabrication was always invisible to the metric.)*

---

## 7. The actual fix: two gates, not one

The fix isn't on the model side — it's on the **grading side**. You need two checkers, because they catch different things:

```
   APPROVING A SUMMARY = two gates

   ┌──────────────────────┐      ┌──────────────────────────────┐
   │  MiniCheck            │  +   │  deterministic time/number   │
   │  (judges MEANING)     │      │  check (exact match to source)│
   │                       │      │                              │
   │  catches invented     │      │  catches "2:30am when the    │
   │  stories & vibes      │      │  source said 2:30"           │
   │                       │      │                              │
   │  ❌ misses am/pm flips │      │  ✅ catches exactly those     │
   └──────────────────────┘      └──────────────────────────────┘
            └──────────── both needed ─────────────┘
```

A meaning-checker is fuzzy — good at "did it invent a whole story." A structured-field checker is strict — good at "is this exact time/dose real." Times and doses follow rules, so you can check them with plain code, no AI needed. The deterministic fixer lives in [playground/ground_times.py](playground/ground_times.py).

---

## The one-sentence takeaway

> The am/pm error *is* trivial to fix — but the valuable discovery is **why nobody had: the project's main quality metric literally cannot see that error.** A health-record system needs a second, strict checker bolted on before any "which model wins" conclusion can be trusted.

---

### Background concepts (for the curious)
- This failure type is an **extrinsic hallucination** — adding specificity the source never gave. Research finds >90% of these are wrong: [Maynez et al. 2020](https://aclanthology.org/2020.acl-main.173.pdf).
- The standard remedy is **post-hoc faithfulness correction** — fix/strip the parts not grounded in the source: [Chen et al. 2021](https://arxiv.org/pdf/2104.09061).
